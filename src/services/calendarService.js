import { requireSupabase } from '../lib/supabase.js'

export const calendarCategories = [
  { value: 'class_activity', label: '班級活動' },
  { value: 'school_activity', label: '學校活動' },
  { value: 'exam', label: '考試' },
  { value: 'holiday', label: '放假' },
  { value: 'other', label: '其他' },
]

export const calendarCategoryLabels = Object.fromEntries(
  calendarCategories.map((category) => [category.value, category.label]),
)

function normalizeText(value) {
  return String(value || '').trim().replace(/\s+/g, ' ')
}

function dateParts(value) {
  const match = /^(\d{4})-(\d{2})(?:-(\d{2}))?$/.exec(String(value || ''))
  if (!match) return null
  return { year: Number(match[1]), month: Number(match[2]), day: Number(match[3] || 1) }
}

export function localDateKey(date = new Date()) {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

export function currentMonthKey(date = new Date()) {
  return localDateKey(date).slice(0, 7)
}

export function shiftMonth(monthKey, offset) {
  const parts = dateParts(monthKey)
  if (!parts) return currentMonthKey()
  const date = new Date(parts.year, parts.month - 1 + offset, 1)
  return localDateKey(date).slice(0, 7)
}

export function monthBounds(monthKey) {
  const parts = dateParts(monthKey)
  if (!parts || parts.month < 1 || parts.month > 12) throw new Error('行事曆月份格式不正確。')
  const first = new Date(parts.year, parts.month - 1, 1)
  const last = new Date(parts.year, parts.month, 0)
  return { startsOn: localDateKey(first), endsOn: localDateKey(last) }
}

export function buildMonthCells(monthKey) {
  const { startsOn } = monthBounds(monthKey)
  const parts = dateParts(startsOn)
  const first = new Date(parts.year, parts.month - 1, 1)
  const gridStart = new Date(parts.year, parts.month - 1, 1 - first.getDay())
  return Array.from({ length: 42 }, (_, index) => {
    const date = new Date(gridStart.getFullYear(), gridStart.getMonth(), gridStart.getDate() + index)
    const dateKey = localDateKey(date)
    return {
      dateKey,
      day: date.getDate(),
      isCurrentMonth: dateKey.slice(0, 7) === monthKey,
      isToday: dateKey === localDateKey(),
    }
  })
}

export function eventsOnDate(events, dateKey) {
  return (events || []).filter((event) => event.startsOn <= dateKey && event.endsOn >= dateKey)
}

export function mapCalendarEventRow(row) {
  return {
    id: row.id,
    classId: row.class_id,
    title: row.title,
    description: row.description || '',
    location: row.location || '',
    category: row.category,
    startsOn: row.starts_on,
    endsOn: row.ends_on,
    isAllDay: row.is_all_day,
    startTime: row.start_time ? String(row.start_time).slice(0, 5) : '',
    endTime: row.end_time ? String(row.end_time).slice(0, 5) : '',
    isActive: row.is_active,
    sourceOffice: row.source_office || '',
    sourceAudience: row.source_audience || '',
    sourceFileName: row.source_file_name || '',
    sourceSheet: row.source_sheet || '',
    sourceRow: row.source_row || null,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  }
}

export function validateCalendarEventInput(input) {
  const title = normalizeText(input.title)
  const description = String(input.description || '').trim()
  const location = normalizeText(input.location)
  const startsOn = String(input.startsOn || '')
  const endsOn = String(input.endsOn || '')
  const isAllDay = Boolean(input.isAllDay)
  const startTime = String(input.startTime || '')
  const endTime = String(input.endTime || '')

  if (!title || title.length > 80) throw new Error('行程標題必須為 1 至 80 個字。')
  if (description.length > 2000) throw new Error('詳細說明不可超過 2000 個字。')
  if (location.length > 100) throw new Error('地點不可超過 100 個字。')
  if (!calendarCategoryLabels[input.category]) throw new Error('請選擇行程分類。')
  if (!/^\d{4}-\d{2}-\d{2}$/.test(startsOn) || !/^\d{4}-\d{2}-\d{2}$/.test(endsOn)) {
    throw new Error('請設定開始與結束日期。')
  }
  if (endsOn < startsOn) throw new Error('結束日期不得早於開始日期。')
  if (!isAllDay) {
    if (!/^\d{2}:\d{2}$/.test(startTime) || !/^\d{2}:\d{2}$/.test(endTime)) {
      throw new Error('非全天行程必須設定開始與結束時間。')
    }
    if (startsOn === endsOn && endTime <= startTime) throw new Error('結束時間必須晚於開始時間。')
  }
  return {
    title, description, location, category: input.category, startsOn, endsOn,
    isAllDay, startTime: isAllDay ? '' : startTime, endTime: isAllDay ? '' : endTime,
  }
}

export async function loadCalendarEvents({ classId, month, includeInactive = false }) {
  const { startsOn, endsOn } = monthBounds(month)
  const client = requireSupabase()
  let query = client
    .from('calendar_events')
    .select('id,class_id,title,description,location,category,starts_on,ends_on,is_all_day,start_time,end_time,is_active,source_office,source_audience,source_file_name,source_sheet,source_row,created_at,updated_at')
    .eq('class_id', classId)
    .lte('starts_on', endsOn)
    .gte('ends_on', startsOn)
    .order('starts_on')
    .order('start_time')
  if (!includeInactive) query = query.eq('is_active', true)
  const { data, error } = await query
  if (error) throw new Error('無法讀取班級行事曆。')
  return (data || []).map(mapCalendarEventRow)
}

export async function saveCalendarEvent({ eventId = null, classId, ...input }) {
  const validated = validateCalendarEventInput(input)
  const client = requireSupabase()
  const { data, error } = await client.rpc('admin_save_calendar_event', {
    p_event_id: eventId,
    p_class_id: classId,
    p_title: validated.title,
    p_description: validated.description,
    p_location: validated.location,
    p_category: validated.category,
    p_starts_on: validated.startsOn,
    p_ends_on: validated.endsOn,
    p_is_all_day: validated.isAllDay,
    p_start_time: validated.isAllDay ? null : validated.startTime,
    p_end_time: validated.isAllDay ? null : validated.endTime,
  })
  if (error) {
    const message = error.message || ''
    if (message.includes('permission_denied')) throw new Error('目前帳號沒有管理行事曆的權限。')
    if (message.includes('invalid_calendar_event_id')) throw new Error('找不到這筆行程，請重新整理。')
    if (message.includes('invalid_calendar_event')) throw new Error('行程內容格式不正確，請檢查日期與時間。')
    throw new Error('行程儲存失敗，請稍後再試。')
  }
  return data
}

export async function setCalendarEventActive({ eventId, isActive }) {
  const client = requireSupabase()
  const { data, error } = await client.rpc('admin_set_calendar_event_active', {
    p_event_id: eventId,
    p_is_active: isActive,
  })
  if (error) {
    const message = error.message || ''
    if (message.includes('permission_denied')) throw new Error('目前帳號沒有管理行事曆的權限。')
    if (message.includes('invalid_calendar_event_id')) throw new Error('找不到這筆行程，請重新整理。')
    throw new Error(isActive ? '行程恢復失敗，請稍後再試。' : '行程下架失敗，請稍後再試。')
  }
  return data
}
