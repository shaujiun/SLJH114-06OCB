import { requireSupabase } from '../lib/supabase.js'

const adminFunctionNames = {
  createStudent: import.meta.env.VITE_ADMIN_CREATE_STUDENT_FUNCTION || 'admin-create-student',
  regenerateActivation: import.meta.env.VITE_ADMIN_REGENERATE_ACTIVATION_FUNCTION
    || 'admin-regenerate-activation',
  createPasswordReset: import.meta.env.VITE_ADMIN_CREATE_PASSWORD_RESET_FUNCTION
    || 'admin-create-password-reset',
}

function relation(row) {
  return Array.isArray(row) ? row[0] : row
}

function requireData(data, error, message) {
  if (error) throw new Error(message)
  return data
}

export function mapClassSubjectRow(item) {
  const subject = relation(item.subjects)
  return {
    id: item.id,
    subjectId: subject?.id,
    code: subject?.code,
    name: subject?.name,
    sortOrder: item.sort_order,
    isActive: item.is_active !== false,
  }
}

export async function loadAdminDashboard() {
  const client = requireSupabase()

  const { data: classes, error: classError } = await client
    .from('classes')
    .select(`
      id,
      name,
      grade_level,
      class_number,
      is_active,
      academic_years!inner(id,school_year,starts_on,ends_on,school_id)
    `)
    .eq('academic_years.school_year', 115)
    .eq('is_active', true)
    .order('class_number')
    .limit(1)

  requireData(classes, classError, '無法讀取班級資料，請重新整理。')
  const classRow = classes?.[0]
  if (!classRow) throw new Error('尚未找到八年六班資料。')

  const academicYear = relation(classRow.academic_years)
  const [termsResult, subjectsResult, teachersResult] = await Promise.all([
    client
      .from('academic_terms')
      .select('id,semester,starts_on,ends_on')
      .eq('academic_year_id', academicYear.id)
      .order('semester'),
    client
      .from('class_subjects')
      .select('id,sort_order,is_active,subjects!inner(id,code,name)')
      .eq('class_id', classRow.id)
      .order('sort_order'),
    client
      .from('contact_book_profiles')
      .select('id,username,display_name,created_at')
      .eq('user_type', 'teacher')
      .eq('approval_status', 'pending')
      .eq('is_active', true)
      .order('created_at'),
  ])

  const terms = requireData(
    termsResult.data,
    termsResult.error,
    '無法讀取學期資料，請重新整理。',
  )
  const allClassSubjects = requireData(
    subjectsResult.data,
    subjectsResult.error,
    '無法讀取科目資料，請重新整理。',
  ).map(mapClassSubjectRow)
  const classSubjects = allClassSubjects.filter((subject) => subject.isActive)
  const pendingTeachers = requireData(
    teachersResult.data,
    teachersResult.error,
    '無法讀取待核准教師，請重新整理。',
  ).map((teacher) => ({
    id: teacher.id,
    username: teacher.username,
    displayName: teacher.display_name,
    createdAt: teacher.created_at,
  }))

  return {
    academicYear: {
      id: academicYear.id,
      schoolYear: academicYear.school_year,
      startsOn: academicYear.starts_on,
      endsOn: academicYear.ends_on,
    },
    classInfo: {
      id: classRow.id,
      name: classRow.name,
      gradeLevel: classRow.grade_level,
      classNumber: classRow.class_number,
    },
    terms,
    classSubjects,
    allClassSubjects,
    pendingTeachers,
  }
}

export async function approveTeacher({ profileId, classId, classSubjectIds }) {
  const client = requireSupabase()
  const { data, error } = await client.rpc('approve_pending_teacher', {
    p_profile_id: profileId,
    p_class_id: classId,
    p_class_subject_ids: classSubjectIds,
  })

  if (error) {
    const knownMessage = error.message?.includes('subject_required')
      ? '請至少選擇一個任教科目。'
      : error.message?.includes('invalid_pending_teacher')
        ? '這個教師帳號已處理，請重新整理。'
        : '教師核准失敗，請稍後再試。'
    throw new Error(knownMessage)
  }

  return data
}

export async function addClassSubject({ classId, name }) {
  const subjectName = String(name || '').trim().replace(/\s+/g, ' ')
  if (!subjectName || subjectName.length > 20) {
    throw new Error('科目名稱必須為 1 至 20 個字。')
  }

  const client = requireSupabase()
  const { data, error } = await client.rpc('admin_add_class_subject', {
    p_class_id: classId,
    p_name: subjectName,
  })

  if (error) {
    const message = error.message || ''
    if (message.includes('subject_exists')) {
      throw new Error('這個科目已經在班級科目中。')
    }
    if (message.includes('invalid_subject_name')) {
      throw new Error('科目名稱必須為 1 至 20 個字。')
    }
    if (message.includes('permission_denied')) {
      throw new Error('目前帳號沒有新增科目的權限。')
    }
    throw new Error('科目新增失敗，請稍後再試。')
  }

  return data
}

export async function updateClassSubjects({ classId, subjects }) {
  const normalized = (subjects || []).map((subject, index) => ({
    classSubjectId: subject.id,
    isActive: Boolean(subject.isActive),
    sortOrder: (index + 1) * 10,
  }))
  if (!normalized.length || !normalized.some((subject) => subject.isActive)) {
    throw new Error('班級至少需要保留一個啟用科目。')
  }

  const client = requireSupabase()
  const { data, error } = await client.rpc('admin_update_class_subjects', {
    p_class_id: classId,
    p_subjects: normalized.map((subject) => ({
      class_subject_id: subject.classSubjectId,
      is_active: subject.isActive,
      sort_order: subject.sortOrder,
    })),
  })
  if (error) {
    const message = error.message || ''
    if (message.includes('invalid_subject_settings')) throw new Error('科目設定內容有誤，請重新整理後再試。')
    if (message.includes('permission_denied')) throw new Error('目前帳號沒有管理班級科目的權限。')
    throw new Error('班級科目設定儲存失敗，請稍後再試。')
  }
  return data
}

export async function loadStudents({ classId, academicTermId }) {
  const client = requireSupabase()
  const [studentsResult, groupsResult, helpersResult] = await Promise.all([
    client
      .from('students')
      .select('id,student_id_code,seat_number,full_name,profile_id,is_active')
      .eq('class_id', classId)
      .eq('is_active', true)
      .order('seat_number'),
    client
      .from('student_subject_groups')
      .select('student_id,group_code,class_subjects!inner(subjects!inner(code))')
      .eq('academic_term_id', academicTermId),
    client
      .from('student_helper_assignments')
      .select('student_id,helper_role,class_subject_id,target_group_code')
      .eq('academic_term_id', academicTermId),
  ])

  const students = requireData(
    studentsResult.data,
    studentsResult.error,
    '無法讀取學生名單，請重新整理。',
  )
  const groups = requireData(
    groupsResult.data,
    groupsResult.error,
    '無法讀取學生分組，請重新整理。',
  )
  const helpers = requireData(
    helpersResult.data,
    helpersResult.error,
    '無法讀取學生幹部設定，請重新整理。',
  )

  const groupsByStudent = new Map()
  for (const group of groups) {
    const classSubject = relation(group.class_subjects)
    const subject = relation(classSubject?.subjects)
    if (!subject?.code) continue
    const current = groupsByStudent.get(group.student_id) || {}
    current[subject.code] = group.group_code
    groupsByStudent.set(group.student_id, current)
  }

  return students.map((student) => ({
    id: student.id,
    studentId: student.student_id_code,
    seatNumber: student.seat_number,
    fullName: student.full_name,
    activated: Boolean(student.profile_id),
    mathGroup: groupsByStudent.get(student.id)?.math || '未設定',
    englishGroup: groupsByStudent.get(student.id)?.english || '未設定',
    isHomeworkLeader: helpers.some((helper) => (
      helper.student_id === student.id && helper.helper_role === 'homework_leader'
    )),
    helperAssignments: helpers
      .filter((helper) => helper.student_id === student.id && helper.helper_role === 'subject_helper')
      .map((helper) => ({
        classSubjectId: helper.class_subject_id,
        targetGroupCode: helper.target_group_code,
      })),
  }))
}

export async function createStudent({
  classId,
  academicTermId,
  studentId,
  seatNumber,
  fullName,
  mathGroup,
  englishGroup,
}) {
  const client = requireSupabase()
  const { data, error } = await client.functions.invoke(adminFunctionNames.createStudent, {
    body: {
      classId,
      academicTermId,
      studentId: studentId.trim(),
      seatNumber: Number(seatNumber),
      fullName: fullName.trim(),
      mathGroup,
      englishGroup,
    },
  })

  if (error || data?.error) {
    throw new Error(data?.error || '學生建立失敗，請確認學號與座號是否重複。')
  }

  return data
}

export async function updateStudentSettings({
  studentId,
  academicTermId,
  mathGroup,
  englishGroup,
  isHomeworkLeader,
  helperAssignments,
}) {
  const client = requireSupabase()
  const { data, error } = await client.rpc('admin_update_student_settings_v2', {
    p_student_id: studentId,
    p_academic_term_id: academicTermId,
    p_math_group: mathGroup,
    p_english_group: englishGroup,
    p_is_homework_leader: isHomeworkLeader,
    p_helper_assignments: (helperAssignments || []).map((assignment) => ({
      class_subject_id: assignment.classSubjectId,
      target_group_code: assignment.targetGroupCode || null,
    })),
  })
  if (error) throw new Error('學生分組與幹部設定儲存失敗，請稍後再試。')
  return data
}

export async function regenerateStudentActivation({ studentId, studentIdCode }) {
  const client = requireSupabase()
  const { data, error } = await client.functions.invoke(
    adminFunctionNames.regenerateActivation,
    { body: { studentId, studentIdCode } },
  )
  if (error || data?.error) {
    throw new Error(data?.error || '無法重新產生啟用碼，請稍後再試。')
  }
  return data
}

export async function createStudentPasswordReset({ studentId, studentIdCode }) {
  const client = requireSupabase()
  const { data, error } = await client.functions.invoke(
    adminFunctionNames.createPasswordReset,
    { body: { studentId, studentIdCode } },
  )
  if (error || data?.error) {
    throw new Error(data?.error || '無法產生密碼重設碼，請稍後再試。')
  }
  return data
}

const ASSIGNMENT_RECIPIENT_PAGE_SIZE = 1000
const ASSIGNMENT_RECIPIENT_ID_BATCH_SIZE = 40

export async function loadAssignmentRecipientRows(client, assignmentIds) {
  const ids = [...new Set((assignmentIds || []).filter(Boolean))]
  if (!ids.length) return []

  const recipients = []
  for (let batchStart = 0; batchStart < ids.length; batchStart += ASSIGNMENT_RECIPIENT_ID_BATCH_SIZE) {
    const idBatch = ids.slice(batchStart, batchStart + ASSIGNMENT_RECIPIENT_ID_BATCH_SIZE)
    for (let pageStart = 0; ; pageStart += ASSIGNMENT_RECIPIENT_PAGE_SIZE) {
      const { data, error } = await client
        .from('assignment_recipients')
        .select('assignment_id,student_id,submitted_at,students(id,student_id_code,seat_number,full_name)')
        .in('assignment_id', idBatch)
        .order('assignment_id')
        .order('student_id')
        .range(pageStart, pageStart + ASSIGNMENT_RECIPIENT_PAGE_SIZE - 1)
      const page = requireData(data, error, '無法讀取作業對象。')
      recipients.push(...page)
      if (page.length < ASSIGNMENT_RECIPIENT_PAGE_SIZE) break
    }
  }
  return recipients
}

export async function loadAssignmentExceptionRows(client, assignmentIds) {
  const ids = [...new Set((assignmentIds || []).filter(Boolean))]
  if (!ids.length) return []

  const exceptions = []
  for (let batchStart = 0; batchStart < ids.length; batchStart += ASSIGNMENT_RECIPIENT_ID_BATCH_SIZE) {
    const idBatch = ids.slice(batchStart, batchStart + ASSIGNMENT_RECIPIENT_ID_BATCH_SIZE)
    for (let pageStart = 0; ; pageStart += ASSIGNMENT_RECIPIENT_PAGE_SIZE) {
      const { data, error } = await client
        .from('submission_exceptions')
        .select('assignment_id,student_id,current_reason,workflow_state')
        .in('assignment_id', idBatch)
        .order('assignment_id')
        .order('student_id')
        .range(pageStart, pageStart + ASSIGNMENT_RECIPIENT_PAGE_SIZE - 1)
      const page = requireData(data, error, '無法讀取作業免繳紀錄。')
      exceptions.push(...page)
      if (page.length < ASSIGNMENT_RECIPIENT_PAGE_SIZE) break
    }
  }
  return exceptions
}

export function mapAssignmentRecipientSummaries(recipients = [], exceptions = []) {
  const exemptRecipients = new Set(
    exceptions
      .filter((item) => item.workflow_state === 'open' && item.current_reason === 'exempt')
      .map((item) => `${item.assignment_id}:${item.student_id}`),
  )
  const summaries = recipients.reduce((result, recipient) => {
    const summary = result[recipient.assignment_id] || {
      recipientCount: 0,
      pendingRecipientCount: 0,
      pendingStudents: [],
      recipientStudents: [],
    }
    summary.recipientCount += 1
    const student = relation(recipient.students)
    const seatNumber = Number(student?.seat_number)
    if (Number.isFinite(seatNumber)) {
      summary.recipientStudents.push({
        id: recipient.student_id,
        studentId: student?.student_id_code,
        seatNumber,
        fullName: student?.full_name,
      })
    }

    if (!recipient.submitted_at && !exemptRecipients.has(`${recipient.assignment_id}:${recipient.student_id}`)) {
      summary.pendingRecipientCount += 1
      if (Number.isFinite(seatNumber)) {
        summary.pendingStudents.push({
          id: recipient.student_id,
          seatNumber,
        })
      }
    }

    result[recipient.assignment_id] = summary
    return result
  }, {})

  Object.values(summaries).forEach((summary) => {
    summary.pendingStudents.sort((left, right) => left.seatNumber - right.seatNumber)
    summary.recipientStudents.sort((left, right) => left.seatNumber - right.seatNumber)
  })

  return summaries
}

export async function loadAssignments({ academicTermId, classSubjectIds, isActive = true }) {
  if (Array.isArray(classSubjectIds) && !classSubjectIds.length) return []
  const client = requireSupabase()
  let assignmentQuery = client
    .from('assignments')
    .select('id,class_subject_id,assignment_date,content,due_at,target_type,target_group_code,published_by_display_name,published_at,is_active,cancelled_at,class_subjects!inner(subjects!inner(code,name))')
    .eq('academic_term_id', academicTermId)
    .eq('is_active', isActive)
    .order('due_at', { ascending: false })
  if (classSubjectIds?.length) assignmentQuery = assignmentQuery.in('class_subject_id', classSubjectIds)
  const assignmentsResult = await assignmentQuery
  const rows = requireData(assignmentsResult.data, assignmentsResult.error, '無法讀取作業清單。')
  const assignmentIds = rows.map((row) => row.id)
  const [recipients, exceptions] = await Promise.all([
    loadAssignmentRecipientRows(client, assignmentIds),
    loadAssignmentExceptionRows(client, assignmentIds),
  ])
  const recipientSummaries = mapAssignmentRecipientSummaries(recipients, exceptions)
  return rows.map((row) => {
    const classSubject = relation(row.class_subjects)
    const subject = relation(classSubject?.subjects)
    const recipientSummary = recipientSummaries[row.id] || {
      recipientCount: 0,
      pendingRecipientCount: 0,
      pendingStudents: [],
      recipientStudents: [],
    }
    return {
      id: row.id,
      classSubjectId: row.class_subject_id,
      assignmentDate: row.assignment_date,
      content: row.content,
      dueAt: row.due_at,
      targetType: row.target_type,
      targetGroupCode: row.target_group_code,
      publisher: row.published_by_display_name,
      publishedAt: row.published_at,
      isActive: row.is_active,
      cancelledAt: row.cancelled_at,
      subject,
      ...recipientSummary,
      isFullySubmitted: recipientSummary.recipientCount > 0
        && recipientSummary.pendingRecipientCount === 0,
    }
  })
}

export function mapOutstandingAssignmentSeats({ recipients = [], exceptions = [] }) {
  const exemptRecipients = new Set(
    exceptions
      .filter((item) => item.workflow_state === 'open' && item.current_reason === 'exempt')
      .map((item) => `${item.assignment_id}:${item.student_id}`),
  )
  const assignmentsWithIndividualTracking = new Set(
    exceptions.map((item) => item.assignment_id),
  )

  const grouped = recipients.reduce((result, recipient) => {
    const summary = result[recipient.assignment_id] || { submittedCount: 0, pendingSeats: [] }
    const key = `${recipient.assignment_id}:${recipient.student_id}`
    if (exemptRecipients.has(key)) {
      result[recipient.assignment_id] = summary
      return result
    }
    if (recipient.submitted_at) {
      summary.submittedCount += 1
    } else {
      const student = relation(recipient.students)
      const seatNumber = Number(student?.seat_number)
      if (Number.isFinite(seatNumber)) summary.pendingSeats.push(seatNumber)
    }
    result[recipient.assignment_id] = summary
    return result
  }, {})

  return Object.fromEntries(Object.entries(grouped).flatMap(([assignmentId, summary]) => {
    const hasRecordedStudentStatus = summary.submittedCount > 0
      || assignmentsWithIndividualTracking.has(assignmentId)
    if (!summary.pendingSeats.length || !hasRecordedStudentStatus) return []
    return [[assignmentId, [...new Set(summary.pendingSeats)].sort((left, right) => left - right)]]
  }))
}

export async function loadAssignmentAudienceStudents({ classId }) {
  const client = requireSupabase()
  const { data, error } = await client
    .from('students')
    .select('id,student_id_code,seat_number,full_name')
    .eq('class_id', classId)
    .eq('is_active', true)
    .order('seat_number')
  return requireData(data, error, '無法讀取個別作業學生名單。').map((student) => ({
    id: student.id,
    studentId: student.student_id_code,
    seatNumber: student.seat_number,
    fullName: student.full_name,
  }))
}

export async function loadOutstandingAssignmentSeats({ assignmentIds = [] }) {
  const ids = [...new Set((assignmentIds || []).filter(Boolean))]
  if (!ids.length) return {}

  const client = requireSupabase()
  const [recipientsResult, exceptionsResult] = await Promise.all([
    client
      .from('assignment_recipients')
      .select('assignment_id,student_id,submitted_at,students!inner(seat_number)')
      .in('assignment_id', ids),
    client
      .from('submission_exceptions')
      .select('assignment_id,student_id,current_reason,workflow_state')
      .in('assignment_id', ids),
  ])

  const recipients = requireData(
    recipientsResult.data,
    recipientsResult.error,
    '無法讀取作業的學生名單。',
  )
  const exceptions = requireData(
    exceptionsResult.data,
    exceptionsResult.error,
    '無法讀取作業的缺交紀錄。',
  )
  return mapOutstandingAssignmentSeats({ recipients, exceptions })
}

export function getAssignmentDate(assignment) {
  return assignment?.assignmentDate || ''
}

export function getOutstandingAssignmentDates(assignments) {
  const dates = new Set(
    (assignments || [])
      .filter((assignment) => !assignment.isFullySubmitted && getAssignmentDate(assignment))
      .map(getAssignmentDate),
  )
  return [...dates].sort((left, right) => right.localeCompare(left))
}

export function filterAssignmentsByDate(assignments, assignmentDate) {
  if (!assignmentDate) return []
  return (assignments || []).filter((assignment) => getAssignmentDate(assignment) === assignmentDate)
}

export function sortAssignmentsByTarget(assignments) {
  const targetOrder = { common: 0, individual: 1, A: 2, B: 3 }
  return [...(assignments || [])].sort((left, right) => {
    const leftKey = left.targetType === 'common' ? 'common' : left.targetType === 'individual' ? 'individual' : left.targetGroupCode
    const rightKey = right.targetType === 'common' ? 'common' : right.targetType === 'individual' ? 'individual' : right.targetGroupCode
    const targetDifference = (targetOrder[leftKey] ?? 99) - (targetOrder[rightKey] ?? 99)
    if (targetDifference) return targetDifference
    return new Date(right.dueAt).getTime() - new Date(left.dueAt).getTime()
  })
}

export async function publishAssignment({
  classSubjectId,
  academicTermId,
  assignmentDate,
  content,
  dueAt,
  targetType,
  targetGroupCode,
  studentIds = [],
}) {
  const client = requireSupabase()
  const { data, error } = await client.rpc('publish_contact_book_assignment', {
    p_class_subject_id: classSubjectId,
    p_academic_term_id: academicTermId,
    p_assignment_date: assignmentDate,
    p_content: content.trim(),
    p_due_at: new Date(dueAt).toISOString(),
    p_target_type: targetType,
    p_target_group_code: targetType === 'group' ? targetGroupCode : null,
    p_student_ids: targetType === 'individual' ? [...new Set(studentIds)] : null,
  })
  if (error) {
    const databaseMessage = error.message || ''
    let message = '作業發布失敗，請重新整理後再試一次。'
    if (databaseMessage.includes('invalid_assignment_recipients')) {
      message = '個別作業名單包含無效或重複的學生，請重新選擇。'
    } else if (databaseMessage.includes('empty_assignment_audience')) {
      message = '這個分組目前沒有學生，作業未發布。'
    } else if (databaseMessage.includes('invalid_class_subject_term')) {
      message = '所選科目與歸類學期不屬於同一班級，請重新整理後再試。'
    } else if (databaseMessage.includes('invalid_assignment_data')) {
      message = '請確認作業內容、作業日期與繳交期限。'
    } else if (databaseMessage.includes('publish_permission_required')) {
      message = '目前帳號沒有發布這個科目作業的權限。'
    } else if (error.code === 'PGRST202') {
      message = '作業功能正在更新，請重新整理網頁後再試一次。'
    }
    throw new Error(message)
  }
  return data
}

export async function updateAssignment({
  assignmentId,
  assignmentDate,
  content,
  dueAt,
  targetType,
  targetGroupCode,
  studentIds = [],
}) {
  const client = requireSupabase()
  const { data, error } = await client.rpc('update_contact_book_assignment', {
    p_assignment_id: assignmentId,
    p_assignment_date: assignmentDate,
    p_content: content.trim(),
    p_due_at: new Date(dueAt).toISOString(),
    p_target_type: targetType,
    p_target_group_code: targetType === 'group' ? targetGroupCode : null,
    p_student_ids: targetType === 'individual' ? [...new Set(studentIds)] : null,
  })
  if (error) {
    const databaseMessage = error.message || ''
    let message = '作業修改失敗，請重新整理後再試一次。'
    if (databaseMessage.includes('invalid_assignment_recipients')) {
      message = '個別作業名單包含無效或重複的學生，請重新選擇。'
    } else if (databaseMessage.includes('assignment_target_locked')) {
      message = '這項作業已有繳交或例外紀錄，只能修改內容、日期與期限，不能再更換組別。'
    } else if (databaseMessage.includes('empty_assignment_audience')) {
      message = '所選分組目前沒有學生，組別未變更。'
    } else if (databaseMessage.includes('update_target_permission_required')) {
      message = '目前帳號沒有把作業改成這個組別的權限。'
    } else if (databaseMessage.includes('update_permission_required')) {
      message = '目前帳號沒有編輯這項作業的權限。'
    } else if (databaseMessage.includes('invalid_assignment_data')) {
      message = '請確認作業內容、作業日期與繳交期限。'
    } else if (databaseMessage.includes('invalid_assignment')) {
      message = '找不到這項作業，可能已被取消，請重新整理。'
    } else if (error.code === 'PGRST202') {
      message = '作業編輯功能尚未完成資料庫更新，請稍後再試。'
    }
    throw new Error(message)
  }
  return data
}

export async function cancelAssignment({ assignmentId }) {
  const client = requireSupabase()
  const { data, error } = await client.rpc('cancel_contact_book_assignment', {
    p_assignment_id: assignmentId,
  })
  if (error) {
    const databaseMessage = error.message || ''
    if (databaseMessage.includes('assignment_already_cancelled')) {
      throw new Error('這份作業已經取消，請重新整理。')
    }
    if (databaseMessage.includes('invalid_assignment')) {
      throw new Error('找不到這份作業，請重新整理。')
    }
    if (databaseMessage.includes('cancel_permission_required')) {
      throw new Error('目前帳號沒有取消這份作業的權限。')
    }
    throw new Error('作業取消失敗，請稍後再試。')
  }
  return data
}

export async function restoreAssignment({ assignmentId }) {
  const client = requireSupabase()
  const { data, error } = await client.rpc('restore_contact_book_assignment', {
    p_assignment_id: assignmentId,
  })
  if (error) {
    const databaseMessage = error.message || ''
    if (databaseMessage.includes('assignment_already_active')) {
      throw new Error('這項作業已經恢復，請重新整理。')
    }
    if (databaseMessage.includes('invalid_assignment')) {
      throw new Error('找不到這項已取消作業，請重新整理。')
    }
    if (databaseMessage.includes('restore_permission_required')) {
      throw new Error('目前帳號沒有恢復這項作業的權限。')
    }
    throw new Error('作業恢復失敗，請稍後再試。')
  }
  return data
}

export function isFollowUpOverdue(exception, now = Date.now()) {
  return Boolean(
    exception?.workflowState === 'open'
    && ['leave', 'official_leave'].includes(exception.reason)
    && exception.followUpDueAt
    && new Date(exception.followUpDueAt).getTime() <= now,
  )
}

export function mapSubmissionTrackingData({ recipients, checks, exceptions, events }) {
  const eventsByException = (events || []).reduce((map, event) => {
    const current = map.get(event.submission_exception_id) || []
    current.push({
      id: event.id,
      fromReason: event.from_reason,
      toReason: event.to_reason,
      fromState: event.from_state,
      toState: event.to_state,
      countsAsMissing: event.counts_as_missing,
      countsAsLate: event.counts_as_late,
      changedBy: event.changed_by,
      note: event.note,
      createdAt: event.created_at,
    })
    map.set(event.submission_exception_id, current)
    return map
  }, new Map())
  const exceptionByStudent = new Map(exceptions.map((item) => [item.student_id, item]))

  return {
    students: recipients.map((recipient) => {
      const student = relation(recipient.students)
      const exception = exceptionByStudent.get(recipient.student_id)
      return {
        id: student.id,
        studentId: student.student_id_code,
        seatNumber: student.seat_number,
        fullName: student.full_name,
        submittedAt: recipient.submitted_at,
        exception: exception ? {
          id: exception.id,
          initialReason: exception.initial_reason,
          reason: exception.current_reason,
          workflowState: exception.workflow_state,
          followUpDueAt: exception.follow_up_due_at,
          countsAsMissing: exception.counts_as_missing,
          countsAsLate: exception.counts_as_late,
          resolvedAt: exception.resolved_at,
          hideAfter: exception.hide_after,
          updatedAt: exception.updated_at,
          events: (eventsByException.get(exception.id) || [])
            .sort((left, right) => new Date(left.createdAt) - new Date(right.createdAt)),
        } : null,
      }
    }).sort((a, b) => a.seatNumber - b.seatNumber),
    checks,
  }
}

export async function loadSubmissionTracking({ assignmentId }) {
  const client = requireSupabase()
  const [recipientsResult, checksResult, exceptionsResult] = await Promise.all([
    client
      .from('assignment_recipients')
      .select('student_id,submitted_at,students!inner(id,student_id_code,seat_number,full_name)')
      .eq('assignment_id', assignmentId),
    client
      .from('submission_checks')
      .select('check_stage,result,checked_at')
      .eq('assignment_id', assignmentId),
    client
      .from('submission_exceptions')
      .select('id,student_id,initial_reason,current_reason,workflow_state,follow_up_due_at,counts_as_missing,counts_as_late,resolved_at,hide_after,updated_at')
      .eq('assignment_id', assignmentId),
  ])
  const recipients = requireData(recipientsResult.data, recipientsResult.error, '無法讀取作業學生名單。')
  const checks = requireData(checksResult.data, checksResult.error, '無法讀取繳交確認紀錄。')
  const exceptions = requireData(exceptionsResult.data, exceptionsResult.error, '無法讀取未繳交紀錄。')
  let events = []
  if (exceptions.length) {
    const { data, error } = await client
      .from('submission_status_events')
      .select('id,submission_exception_id,from_reason,to_reason,from_state,to_state,counts_as_missing,counts_as_late,changed_by,note,created_at')
      .in('submission_exception_id', exceptions.map((item) => item.id))
      .order('created_at')
    events = requireData(data, error, '無法讀取繳交修正歷程。')
  }

  return mapSubmissionTrackingData({ recipients, checks, exceptions, events })
}

export async function recordSubmissionCheck({ assignmentId, stage = 'teacher', exceptions = [] }) {
  const client = requireSupabase()
  const { data, error } = await client.rpc('record_assignment_submission_check_v2', {
    p_assignment_id: assignmentId,
    p_stage: stage,
    p_result: exceptions.length ? 'exceptions_recorded' : 'all_submitted',
    p_exceptions: exceptions.map((item) => ({
      student_id: item.studentId,
      reason: item.reason,
      follow_up_due_at: item.followUpDueAt
        ? new Date(item.followUpDueAt).toISOString()
        : null,
    })),
  })
  if (error) {
    const databaseMessage = error.message || ''
    if (databaseMessage.includes('submission_permission_required')) {
      throw new Error('目前帳號沒有確認這份作業繳交狀況的權限。')
    }
    if (databaseMessage.includes('invalid_submission_exceptions')) {
      throw new Error('請確認例外學生、原因及請假補交期限。')
    }
    if (databaseMessage.includes('helper_cannot_modify_existing_exception')) {
      throw new Error('既有的繳交紀錄只能由任課老師或導師修正。')
    }
    throw new Error('繳交狀況儲存失敗，請重新整理後再試。')
  }
  return data
}

export async function recordIndividualSubmission({ assignmentId, studentId, stage = 'teacher' }) {
  return recordIndividualAssignmentStatus({ assignmentId, studentId, stage, status: 'submitted' })
}

export async function recordIndividualAssignmentStatus({
  assignmentId,
  studentId,
  stage = 'teacher',
  status,
  followUpDueAt = '',
}) {
  const client = requireSupabase()
  const { data, error } = await client.rpc('record_individual_assignment_status', {
    p_assignment_id: assignmentId,
    p_student_id: studentId,
    p_stage: stage,
    p_status: status,
    p_follow_up_due_at: followUpDueAt ? new Date(followUpDueAt).toISOString() : null,
  })
  if (error) {
    const databaseMessage = error.message || ''
    if (databaseMessage.includes('submission_permission_required')) {
      throw new Error('目前帳號沒有修改這位學生繳交狀態的權限。')
    }
    if (databaseMessage.includes('helper_cannot_resolve_existing_exception')) {
      throw new Error('已有紀錄的學生，需由任課老師或導師修改狀態。')
    }
    if (databaseMessage.includes('invalid_assignment_recipient')) {
      throw new Error('找不到這份作業的指定學生。')
    }
    if (databaseMessage.includes('invalid_individual_status')) {
      throw new Error('請確認個別繳交狀態及補交期限。')
    }
    throw new Error('個別繳交狀態儲存失敗，請重新整理後再試。')
  }
  return data
}
