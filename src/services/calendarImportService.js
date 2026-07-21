import { requireSupabase } from '../lib/supabase.js'

const semesterSheetPattern = /^第[一二三123]學期$/

const gradeTerms = {
  7: ['七年級', '國一'],
  8: ['八年級', '國二'],
  9: ['九年級', '國三'],
}

const officeStyles = [
  { match: (office) => office.includes('教務') && office.includes('學務'), code: '教／學', style: 'joint' },
  { match: (office) => office.includes('教務'), code: '教', style: 'academic' },
  { match: (office) => office.includes('學務'), code: '學', style: 'student-affairs' },
  { match: (office) => office.includes('輔導'), code: '輔', style: 'counseling' },
  { match: (office) => office.includes('總務'), code: '總', style: 'general-affairs' },
  { match: (office) => office.includes('人事'), code: '人', style: 'personnel' },
  { match: (office) => office.includes('會計'), code: '會', style: 'accounting' },
  { match: (office) => office.includes('校長'), code: '校', style: 'principal' },
  { match: (office) => office.includes('國定假日'), code: '休', style: 'holiday' },
  { match: (office) => office.includes('全校活動'), code: '全', style: 'school' },
]

function normalizeText(value) {
  if (value === null || value === undefined) return ''
  return String(value).trim().replace(/\s+/g, ' ')
}

function compactAudience(value) {
  return normalizeText(value)
    .replace(/[，,、。．・／/\\\-－—–~～至及與和]/g, '')
    .replace(/\s+/g, '')
}

function validDateKey(year, month, day) {
  const date = new Date(year, month - 1, day)
  if (date.getFullYear() !== year || date.getMonth() + 1 !== month || date.getDate() !== day) return ''
  return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`
}

function parseMonthDay(value) {
  if (typeof value === 'number' && Number.isInteger(value)) return value
  const match = /\d{1,2}/.exec(normalizeText(value))
  return match ? Number(match[0]) : null
}

function dateFromAcademicYear(academicYear, month, day, sheetName = '') {
  const startYear = Number(academicYear) + 1911
  const isThirdSemester = /^第[三3]學期$/.test(normalizeText(sheetName))
  const year = isThirdSemester || month < 7 ? startYear + 1 : startYear
  return validDateKey(year, month, day)
}

function rangeEndFromTitle(title, startsOn, academicYear, sheetName) {
  const match = /[（(]\s*(\d{1,2})\s*[／/]\s*(\d{1,2})\s*[-－~～]\s*(\d{1,2})\s*[／/]\s*(\d{1,2})\s*[)）]/.exec(title)
  if (!match) return startsOn
  const [, startMonth, startDay, endMonth, endDay] = match.map(Number)
  const expectedStart = dateFromAcademicYear(academicYear, startMonth, startDay, sheetName)
  const expectedEnd = dateFromAcademicYear(academicYear, endMonth, endDay, sheetName)
  return expectedStart === startsOn && expectedEnd >= startsOn ? expectedEnd : startsOn
}

function normalizeTime(value) {
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return `${String(value.getHours()).padStart(2, '0')}:${String(value.getMinutes()).padStart(2, '0')}`
  }
  return normalizeText(value)
    .replace(/：/g, ':')
    .replace(/[－—–~～]/g, '-')
}

export function parseTimeRange(value) {
  const raw = normalizeTime(value)
  const match = /(?:^|\D)(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})(?:$|\D)/.exec(raw)
  if (!match) return null
  const [, startHour, startMinute, endHour, endMinute] = match.map(Number)
  if (startHour > 23 || endHour > 23 || startMinute > 59 || endMinute > 59) return null
  const startTime = `${String(startHour).padStart(2, '0')}:${String(startMinute).padStart(2, '0')}`
  const endTime = `${String(endHour).padStart(2, '0')}:${String(endMinute).padStart(2, '0')}`
  if (endTime <= startTime) return null
  return { startTime, endTime }
}

export function inferAcademicYear(fileName, fallback = 114) {
  const match = /(\d{3})\s*學年/.exec(normalizeText(fileName))
  return match ? Number(match[1]) : fallback
}

export function decideAudience(audience, grade = 8) {
  const text = normalizeText(audience)
  const compact = compactAudience(text)
  if (!text) return { decision: 'review', reason: '對象空白，請確認' }

  if (text === '各班' || /全校學生|全校師生|全校教職員工生|全校教職員生/.test(compact)) {
    return { decision: 'include', reason: '全校學生相關活動' }
  }

  if (/全校教師|全校教職員工|全校教職同仁|教師|導師|行政|主任|家長|承辦|領隊|閱推同仁/.test(compact)
    && !/學生|師生|員工生|員生/.test(compact)) {
    return { decision: 'exclude', reason: '僅教師、家長或行政人員' }
  }

  if (/新生/.test(compact) && grade !== 7) return { decision: 'exclude', reason: '新生活動不屬於目前年級' }
  if (/\d{3}班同學|^\d{3}$/.test(compact)) return { decision: 'exclude', reason: '僅特定班級' }

  const selectedTerms = gradeTerms[grade] || []
  if (selectedTerms.some((term) => compact.includes(term))) {
    return { decision: 'include', reason: `包含${grade}年級學生` }
  }

  if (grade === 7 && /七八年級|國一國二|七九年級/.test(compact)) return { decision: 'include', reason: '跨年級活動包含 7 年級' }
  if (grade === 8 && /七八年級|八九年級|國一國二|國二國三|七九年級/.test(compact)) return { decision: 'include', reason: '跨年級活動包含 8 年級' }
  if (grade === 9 && /八九年級|國二國三|七九年級/.test(compact)) return { decision: 'include', reason: '跨年級活動包含 9 年級' }

  const otherGradeTerms = Object.entries(gradeTerms)
    .filter(([number]) => Number(number) !== Number(grade))
    .flatMap(([, terms]) => terms)
  if (otherGradeTerms.some((term) => compact.includes(term))) {
    return { decision: 'exclude', reason: '僅屬其他年級' }
  }

  if (/參與學生|參加學生|參賽學生|參賽選手|選手|表演者|受評相關師生|全年級/.test(compact)) {
    return { decision: 'review', reason: '對象範圍不明確，請確認' }
  }

  return { decision: 'review', reason: '無法自動判斷對象' }
}

export function calendarOfficeMeta(office) {
  const normalized = normalizeText(office)
  if (!normalized) return { code: '', prefix: '', style: '' }
  const matched = officeStyles.find((entry) => entry.match(normalized))
  if (matched) return { ...matched, prefix: `【${matched.code}】` }
  return { code: '他', prefix: '【他】', style: 'other-office' }
}

export function calendarEventDisplayTitle(event) {
  return `${calendarOfficeMeta(event?.sourceOffice).prefix}${event?.title || ''}`
}

export function calendarEventOfficeClass(event) {
  const style = calendarOfficeMeta(event?.sourceOffice).style
  return style ? ` office-${style}` : ''
}

function inferCategory(office, title) {
  const combined = `${office} ${title}`
  if (/國定假日|放假|冬假|暑假|春節|端午|中秋|清明|國慶|元旦|停課/.test(combined)) return 'holiday'
  if (/段考|會考|考試|測驗/.test(title)) return 'exam'
  return 'school_activity'
}

export function parseSemesterRows(rows, { sheetName, academicYear, grade }) {
  let currentMonth = null
  let currentDay = null
  const events = []

  rows.forEach((row, index) => {
    const rowNumber = index + 1
    if (rowNumber <= 2) return
    const month = parseMonthDay(row?.[1])
    const day = parseMonthDay(row?.[2])
    if (month) currentMonth = month
    if (day) currentDay = day

    const office = normalizeText(row?.[4])
    const title = normalizeText(row?.[5])
    const audience = normalizeText(row?.[6])
    const rawTime = normalizeTime(row?.[7])
    const location = normalizeText(row?.[8])
    if (!title || !currentMonth || !currentDay) return

    const startsOn = dateFromAcademicYear(academicYear, currentMonth, currentDay, sheetName)
    if (!startsOn) return
    const endsOn = rangeEndFromTitle(title, startsOn, academicYear, sheetName)
    const timeRange = parseTimeRange(rawTime)
    const audienceDecision = decideAudience(audience, grade)

    events.push({
      importId: `${sheetName}-${rowNumber}`,
      sourceSheet: sheetName,
      sourceRow: rowNumber,
      sourceOffice: office,
      sourceAudience: audience,
      title,
      description: rawTime && !timeRange ? `原行事曆時間：${rawTime}` : '',
      location,
      category: inferCategory(office, title),
      startsOn,
      endsOn,
      isAllDay: !timeRange,
      startTime: timeRange?.startTime || '',
      endTime: timeRange?.endTime || '',
      decision: audienceDecision.decision,
      decisionReason: audienceDecision.reason,
      selected: audienceDecision.decision === 'include',
    })
  })

  return events
}

export async function parseCalendarWorkbook(file, { academicYear, grade = 8 }) {
  if (!file || !/\.xlsx$/i.test(file.name || '')) throw new Error('請選擇 .xlsx 格式的 Excel 檔案。')
  if (!Number.isInteger(Number(academicYear)) || Number(academicYear) < 100 || Number(academicYear) > 999) {
    throw new Error('請輸入正確的民國學年度，例如 114。')
  }
  const { default: readXlsxFile, readSheetNames } = await import('read-excel-file/browser')
  const sheetNames = await readSheetNames(file)
  const semesterSheets = sheetNames.filter((name) => semesterSheetPattern.test(normalizeText(name)))
  if (!semesterSheets.length) throw new Error('Excel 中找不到「第一學期、第二學期、第三學期」工作表。')

  const parsed = []
  for (const sheetName of semesterSheets) {
    const rows = await readXlsxFile(file, { sheet: sheetName })
    parsed.push(...parseSemesterRows(rows, { sheetName, academicYear: Number(academicYear), grade: Number(grade) }))
  }
  if (!parsed.length) throw new Error('三個學期工作表中找不到可讀取的活動資料。')
  return parsed
}

export async function importCalendarEvents({ classId, sourceFileName, events }) {
  if (!classId || !events?.length) throw new Error('請至少勾選一筆要匯入的行程。')
  if (events.length > 500) throw new Error('單次最多匯入 500 筆行程。')
  const client = requireSupabase()
  const payload = events.map((event) => ({
    title: event.title,
    description: event.description,
    location: event.location,
    category: event.category,
    startsOn: event.startsOn,
    endsOn: event.endsOn,
    isAllDay: event.isAllDay,
    startTime: event.startTime || null,
    endTime: event.endTime || null,
    sourceOffice: event.sourceOffice,
    sourceAudience: event.sourceAudience,
    sourceSheet: event.sourceSheet,
    sourceRow: event.sourceRow,
  }))
  const { data, error } = await client.rpc('admin_import_calendar_events', {
    p_class_id: classId,
    p_source_file_name: normalizeText(sourceFileName).slice(0, 255),
    p_events: payload,
  })
  if (error) {
    const message = error.message || ''
    if (message.includes('permission_denied')) throw new Error('目前帳號沒有匯入行事曆的權限。')
    if (message.includes('invalid_import')) throw new Error('匯入資料格式不正確，請重新分析 Excel。')
    throw new Error('行事曆匯入失敗，請稍後再試。')
  }
  return data
}
