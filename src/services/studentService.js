import { requireSupabase } from '../lib/supabase.js'
import { loadStudentAnnouncements } from './announcementService.js'
import { loadStudentHonors } from './honorService.js'

function relation(row) {
  return Array.isArray(row) ? row[0] : row
}

function requireData(data, error, message) {
  if (error) throw new Error(message)
  return data
}

function localDateString(date = new Date()) {
  const local = new Date(date.getTime() - date.getTimezoneOffset() * 60_000)
  return local.toISOString().slice(0, 10)
}

function shiftLocalDate(dateString, days) {
  const value = new Date(`${dateString}T12:00:00`)
  value.setDate(value.getDate() + days)
  return localDateString(value)
}

function endOfLocalMonth(dateString) {
  const value = new Date(`${dateString.slice(0, 7)}-01T12:00:00`)
  value.setMonth(value.getMonth() + 1, 0)
  return localDateString(value)
}

function dueDateString(value) {
  return localDateString(new Date(value))
}

export function pickDefaultTermId(terms, today = localDateString()) {
  const current = terms.find((term) => today >= term.starts_on && today <= term.ends_on)
  if (current) return current.id
  const upcoming = terms.find((term) => term.starts_on > today)
  return upcoming?.id || terms.at(-1)?.id || ''
}

export function mapStudentAssignmentRow(row) {
  const classSubject = relation(row.class_subjects)
  const subject = relation(classSubject?.subjects)
  return {
    id: row.id,
    academicTermId: row.academic_term_id,
    assignmentDate: row.assignment_date,
    content: row.content,
    dueAt: row.due_at,
    targetType: row.target_type,
    targetGroupCode: row.target_group_code,
    publisher: row.published_by_display_name,
    subject: {
      code: subject?.code,
      name: subject?.name,
    },
  }
}

export function filterVisibleStudentAssignments(assignments, academicTermId) {
  return (assignments || []).filter((item) => (
    item.academicTermId === academicTermId && !item.submittedAt
  ))
}

export function groupStudentAssignments(assignments) {
  const groups = new Map()
  for (const assignment of assignments || []) {
    const key = assignment.targetType === 'common'
      ? 'common'
      : String(assignment.targetGroupCode || '').toUpperCase()
    const label = key === 'common' ? '共同' : `${key} 組`
    const current = groups.get(key) || { key, label, assignments: [] }
    current.assignments.push(assignment)
    groups.set(key, current)
  }
  const order = { common: 0, A: 1, B: 2 }
  return [...groups.values()].sort((left, right) => (
    (order[left.key] ?? 99) - (order[right.key] ?? 99)
  ))
}

export function buildExceptionSummary(exceptions) {
  const now = Date.now()
  return {
    openCount: exceptions.filter((item) => item.workflowState === 'open').length,
    incompleteCount: exceptions.filter((item) => (item.currentReason || item.initialReason) === 'incomplete').length,
    notBroughtCount: exceptions.filter((item) => (item.currentReason || item.initialReason) === 'not_brought').length,
    lateCount: exceptions.filter((item) => item.countsAsLate).length,
    visible: exceptions.filter((item) => (
      item.workflowState === 'open'
      || (item.hideAfter && new Date(item.hideAfter).getTime() > now)
    )),
  }
}

export function buildPeriodExceptionSummaries({
  assignments,
  exceptions,
  terms,
  selectedTermId,
  today = localDateString(),
}) {
  const assignmentById = new Map(assignments.map((assignment) => [assignment.id, assignment]))
  const todayValue = new Date(`${today}T12:00:00`)
  const weekday = todayValue.getDay()
  const weekStartsOn = shiftLocalDate(today, weekday === 0 ? -6 : 1 - weekday)
  const weekEndsOn = shiftLocalDate(weekStartsOn, 6)
  const selectedTerm = terms.find((term) => term.id === selectedTermId)
  const sortedTerms = [...terms].sort((a, b) => a.starts_on.localeCompare(b.starts_on))
  const ranges = [
    { key: 'week', label: '本週', startsOn: weekStartsOn, endsOn: weekEndsOn },
    { key: 'month', label: '本月', startsOn: `${today.slice(0, 7)}-01`, endsOn: endOfLocalMonth(today) },
    { key: 'term', label: selectedTerm ? `第 ${selectedTerm.semester} 學期` : '本學期', startsOn: selectedTerm?.starts_on, endsOn: selectedTerm?.ends_on },
    { key: 'year', label: '本學年', startsOn: sortedTerms[0]?.starts_on, endsOn: sortedTerms.at(-1)?.ends_on },
  ]

  return ranges.map((range) => {
    const periodExceptions = range.startsOn && range.endsOn
      ? exceptions.filter((exception) => {
        const assignment = assignmentById.get(exception.assignmentId)
        if (!assignment?.dueAt) return false
        const dueDate = dueDateString(assignment.dueAt)
        return dueDate >= range.startsOn && dueDate <= range.endsOn
      })
      : []
    return { ...range, ...buildExceptionSummary(periodExceptions) }
  })
}

export function getHelperSubjectIds(helperAssignments, classSubjects, academicTermId) {
  const assignments = helperAssignments.filter((item) => item.academicTermId === academicTermId)
  if (assignments.some((item) => item.helperRole === 'homework_leader')) {
    return classSubjects.map((subject) => subject.id)
  }
  return [...new Set(assignments
    .filter((item) => item.helperRole === 'subject_helper' && item.classSubjectId)
    .map((item) => item.classSubjectId))]
}

export function getHelperSubjectPermissions(helperAssignments, classSubjects, academicTermId) {
  const assignments = helperAssignments.filter((item) => item.academicTermId === academicTermId)
  if (assignments.some((item) => item.helperRole === 'homework_leader')) {
    return classSubjects.map((subject) => ({
      ...subject,
      allowedTargetGroups: ['math', 'english'].includes(subject.code)
        ? ['common', 'A', 'B']
        : ['common'],
    }))
  }
  return assignments
    .filter((item) => item.helperRole === 'subject_helper' && item.classSubjectId)
    .map((assignment) => {
      const subject = classSubjects.find((item) => item.id === assignment.classSubjectId)
      if (!subject) return null
      return {
        ...subject,
        allowedTargetGroups: assignment.targetGroupCode
          ? [assignment.targetGroupCode]
          : ['common'],
      }
    })
    .filter(Boolean)
}

export function getEligibleHelperTermIds(helperAssignments, terms, today = localDateString()) {
  const currentTerm = terms.find((term) => today >= term.starts_on && today <= term.ends_on)
  const nextTerm = currentTerm || terms.find((term) => term.starts_on > today)
  if (!nextTerm) return []
  return [nextTerm].filter((term) => {
    const referenceDate = today < term.starts_on ? term.starts_on : today
    return helperAssignments.some((assignment) => (
      assignment.academicTermId === term.id
      && assignment.startsOn <= referenceDate
      && (!assignment.endsOn || assignment.endsOn >= referenceDate)
    ))
  }).map((term) => term.id)
}

export async function loadStudentDashboard() {
  const client = requireSupabase()
  const { data: userData, error: userError } = await client.auth.getUser()
  if (userError || !userData.user) throw new Error('登入狀態已失效，請重新登入。')

  const { data: studentData, error: studentError } = await client
    .from('students')
    .select('id,student_id_code,seat_number,full_name,class_id,classes!inner(id,name,grade_level,class_number,academic_year_id)')
    .eq('profile_id', userData.user.id)
    .eq('is_active', true)
    .single()
  const student = requireData(studentData, studentError, '無法讀取學生資料，請重新登入。')
  const classInfo = relation(student.classes)

  const [
    termsResult,
    groupsResult,
    assignmentsResult,
    recipientsResult,
    exceptionsResult,
    helpersResult,
    classSubjectsResult,
    announcements,
    honors,
  ] = await Promise.all([
    client
      .from('academic_terms')
      .select('id,semester,starts_on,ends_on')
      .eq('academic_year_id', classInfo.academic_year_id)
      .order('semester'),
    client
      .from('student_subject_groups')
      .select('academic_term_id,group_code,effective_from,effective_to,class_subjects!inner(subjects!inner(code,name))')
      .eq('student_id', student.id)
      .order('effective_from', { ascending: false }),
    client
      .from('assignments')
      .select('id,academic_term_id,assignment_date,content,due_at,target_type,target_group_code,published_by_display_name,class_subjects!inner(subjects!inner(code,name))')
      .eq('is_active', true)
      .order('due_at'),
    client
      .from('assignment_recipients')
      .select('assignment_id,submitted_at')
      .eq('student_id', student.id),
    client
      .from('submission_exceptions')
      .select('id,assignment_id,initial_reason,current_reason,workflow_state,follow_up_due_at,counts_as_missing,counts_as_late,resolved_at,hide_after,created_at')
      .eq('student_id', student.id)
      .order('created_at', { ascending: false }),
    client
      .from('student_helper_assignments')
      .select('academic_term_id,class_subject_id,helper_role,target_group_code,starts_on,ends_on')
      .eq('student_id', student.id),
    client
      .from('class_subjects')
      .select('id,sort_order,is_active,subjects!inner(id,code,name)')
      .eq('class_id', classInfo.id)
      .eq('is_active', true)
      .order('sort_order'),
    loadStudentAnnouncements({ classId: classInfo.id, studentId: student.id }),
    loadStudentHonors({ classId: classInfo.id }),
  ])

  const terms = requireData(termsResult.data, termsResult.error, '無法讀取學期資料。')
  const groups = requireData(groupsResult.data, groupsResult.error, '無法讀取分組資料。').map((row) => {
    const classSubject = relation(row.class_subjects)
    const subject = relation(classSubject?.subjects)
    return {
      academicTermId: row.academic_term_id,
      groupCode: row.group_code,
      effectiveFrom: row.effective_from,
      effectiveTo: row.effective_to,
      subjectCode: subject?.code,
      subjectName: subject?.name,
    }
  })
  const recipientRows = requireData(
    recipientsResult.data,
    recipientsResult.error,
    '無法讀取個人作業繳交狀態，請重新整理後再試。',
  )
  const submittedAtByAssignmentId = new Map(
    recipientRows.map((row) => [row.assignment_id, row.submitted_at]),
  )
  const assignments = requireData(
    assignmentsResult.data,
    assignmentsResult.error,
    '無法讀取個人作業，請重新整理。',
  ).map((row) => ({
    ...mapStudentAssignmentRow(row),
    submittedAt: submittedAtByAssignmentId.get(row.id) || null,
  }))
  const exceptions = requireData(
    exceptionsResult.data,
    exceptionsResult.error,
    '無法讀取繳交紀錄，請重新整理。',
  ).map((row) => ({
    id: row.id,
    assignmentId: row.assignment_id,
    initialReason: row.initial_reason,
    currentReason: row.current_reason,
    workflowState: row.workflow_state,
    followUpDueAt: row.follow_up_due_at,
    countsAsMissing: row.counts_as_missing,
    countsAsLate: row.counts_as_late,
    resolvedAt: row.resolved_at,
    hideAfter: row.hide_after,
    createdAt: row.created_at,
  }))
  const helperAssignments = requireData(
    helpersResult.data,
    helpersResult.error,
    '無法讀取學生幹部權限。',
  ).map((row) => ({
    academicTermId: row.academic_term_id,
    classSubjectId: row.class_subject_id,
    helperRole: row.helper_role,
    targetGroupCode: row.target_group_code,
    startsOn: row.starts_on,
    endsOn: row.ends_on,
  }))
  const classSubjects = requireData(
    classSubjectsResult.data,
    classSubjectsResult.error,
    '無法讀取班級科目。',
  ).map((row) => {
    const subject = relation(row.subjects)
    return {
      id: row.id,
      subjectId: subject?.id,
      code: subject?.code,
      name: subject?.name,
      sortOrder: row.sort_order,
    }
  })

  return {
    student: {
      id: student.id,
      studentId: student.student_id_code,
      seatNumber: student.seat_number,
      fullName: student.full_name,
    },
    classInfo: {
      id: classInfo.id,
      name: classInfo.name,
      gradeLevel: classInfo.grade_level,
      classNumber: classInfo.class_number,
    },
    terms,
    groups,
    assignments,
    exceptions,
    helperAssignments,
    classSubjects,
    announcements,
    honors,
    defaultTermId: pickDefaultTermId(terms),
  }
}
