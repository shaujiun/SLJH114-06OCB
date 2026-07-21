import { requireSupabase } from '../lib/supabase.js'

function normalizeTitle(value) {
  return String(value || '').trim().replace(/\s+/g, ' ')
}

export function validateHonorInput({ studentIds, title, description, awardedOn }) {
  const normalizedTitle = normalizeTitle(title)
  const normalizedDescription = String(description || '').trim()
  const uniqueStudentIds = [...new Set(studentIds || [])]
  if (!uniqueStudentIds.length) throw new Error('請至少選擇一位獲獎學生。')
  if (uniqueStudentIds.length > 50) throw new Error('單次最多可選擇 50 位學生。')
  if (!normalizedTitle || normalizedTitle.length > 80) throw new Error('榮譽名稱必須為 1 至 80 個字。')
  if (normalizedDescription.length > 1000) throw new Error('榮譽事蹟不可超過 1000 個字。')
  if (!/^\d{4}-\d{2}-\d{2}$/.test(awardedOn || '')) throw new Error('請設定榮譽日期。')
  return { studentIds: uniqueStudentIds, title: normalizedTitle, description: normalizedDescription }
}

export function mapHonorRow(row) {
  return {
    id: row.id,
    honorGroupId: row.honor_group_id || row.id,
    classId: row.class_id,
    studentId: row.student_id,
    studentDisplayName: row.student_display_name,
    title: row.title,
    description: row.description || '',
    awardedOn: row.awarded_on,
    isVisible: row.is_visible,
    createdAt: row.created_at,
  }
}

export function groupHonorRows(rows) {
  const groups = new Map()
  rows.map(mapHonorRow).forEach((item) => {
    const current = groups.get(item.honorGroupId)
    if (current) {
      current.entryIds.push(item.id)
      current.studentIds.push(item.studentId)
      current.studentDisplayNames.push(item.studentDisplayName)
      return
    }
    groups.set(item.honorGroupId, {
      ...item,
      id: item.honorGroupId,
      entryIds: [item.id],
      studentIds: [item.studentId],
      studentDisplayNames: [item.studentDisplayName],
    })
  })
  return [...groups.values()]
}

export async function createHonorEntries({ classId, studentIds, title, description, awardedOn }) {
  const validated = validateHonorInput({ studentIds, title, description, awardedOn })
  const client = requireSupabase()
  const { data, error } = await client.rpc('admin_create_honor_entries', {
    p_class_id: classId,
    p_student_ids: validated.studentIds,
    p_title: validated.title,
    p_description: validated.description,
    p_awarded_on: awardedOn,
  })

  if (error) {
    const message = error.message || ''
    if (message.includes('invalid_class_student')) throw new Error('找不到這位班級學生，請重新整理後再試。')
    if (message.includes('permission_denied')) throw new Error('目前帳號沒有建立榮譽榜的權限。')
    if (message.includes('invalid_honor')) throw new Error('榮譽內容格式不正確，請檢查後再試。')
    throw new Error('榮譽榜建立失敗，請稍後再試。')
  }
  return data
}

export async function updateHonorGroup({ honorGroupId, studentIds, title, description, awardedOn }) {
  const validated = validateHonorInput({ studentIds, title, description, awardedOn })
  const client = requireSupabase()
  const { data, error } = await client.rpc('admin_update_honor_group', {
    p_honor_group_id: honorGroupId,
    p_student_ids: validated.studentIds,
    p_title: validated.title,
    p_description: validated.description,
    p_awarded_on: awardedOn,
  })
  if (error) {
    const message = error.message || ''
    if (message.includes('invalid_class_student')) throw new Error('獲獎學生名單已變更，請重新整理後再試。')
    if (message.includes('invalid_honor_entry')) throw new Error('找不到這筆榮譽紀錄，請重新整理。')
    if (message.includes('permission_denied')) throw new Error('目前帳號沒有編輯榮譽榜的權限。')
    if (message.includes('invalid_honor')) throw new Error('榮譽內容格式不正確，請檢查後再試。')
    throw new Error('榮譽紀錄更新失敗，請稍後再試。')
  }
  return data
}

export async function loadAdminHonors({ classId }) {
  const client = requireSupabase()
  const [honorsResult, studentsResult] = await Promise.all([
    client
      .from('honor_entries')
      .select('id,honor_group_id,class_id,student_id,student_display_name,title,description,awarded_on,is_visible,created_at')
      .eq('class_id', classId)
      .order('awarded_on', { ascending: false })
      .order('created_at', { ascending: false }),
    client
      .from('students')
      .select('id,seat_number,full_name')
      .eq('class_id', classId)
      .eq('is_active', true)
      .order('seat_number'),
  ])
  if (honorsResult.error) throw new Error('無法讀取榮譽榜。')
  if (studentsResult.error) throw new Error('無法讀取班級學生名單。')
  return {
    honors: groupHonorRows(honorsResult.data || []),
    students: (studentsResult.data || []).map((student) => ({
      id: student.id,
      seatNumber: student.seat_number,
      fullName: student.full_name,
    })),
  }
}

export async function setHonorVisibility({ honorGroupId, isVisible }) {
  const client = requireSupabase()
  const { error } = await client.rpc('admin_set_honor_group_visibility', {
    p_honor_group_id: honorGroupId,
    p_is_visible: isVisible,
  })
  if (error) throw new Error(isVisible ? '榮譽榜重新顯示失敗。' : '榮譽榜隱藏失敗。')
}

export async function deleteHonorGroup({ honorGroupId }) {
  const client = requireSupabase()
  const { data, error } = await client.rpc('admin_delete_honor_group', {
    p_honor_group_id: honorGroupId,
  })
  if (error) {
    const message = error.message || ''
    if (message.includes('invalid_honor_entry')) throw new Error('找不到這筆榮譽紀錄，請重新整理。')
    if (message.includes('permission_denied')) throw new Error('目前帳號沒有刪除榮譽榜的權限。')
    throw new Error('榮譽紀錄刪除失敗，請稍後再試。')
  }
  return data
}

export async function loadStudentHonors({ classId }) {
  const client = requireSupabase()
  const { data, error } = await client
    .from('honor_entries')
    .select('id,honor_group_id,class_id,student_id,student_display_name,title,description,awarded_on,is_visible,created_at')
    .eq('class_id', classId)
    .eq('is_visible', true)
    .order('awarded_on', { ascending: false })
    .order('created_at', { ascending: false })
  if (error) throw new Error('無法讀取班級榮譽榜。')
  return groupHonorRows(data || [])
}
