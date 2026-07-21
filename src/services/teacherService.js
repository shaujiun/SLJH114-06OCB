import { requireSupabase } from '../lib/supabase.js'

function relation(row) {
  return Array.isArray(row) ? row[0] : row
}

export function mapTeacherDashboardRows(rows, terms) {
  const firstRow = rows[0]
  const classInfo = relation(firstRow?.classes)
  const academicYear = relation(classInfo?.academic_years)
  if (!classInfo?.id || !academicYear?.id) return null

  const subjectMap = new Map()
  rows.forEach((row) => {
    const classSubject = relation(row.class_subjects)
    const subject = relation(classSubject?.subjects)
    if (!classSubject?.id || !subject?.id) return
    subjectMap.set(classSubject.id, {
      id: classSubject.id,
      subjectId: subject.id,
      code: subject.code,
      name: subject.name,
      sortOrder: classSubject.sort_order,
    })
  })

  return {
    academicYear: {
      id: academicYear.id,
      schoolYear: academicYear.school_year,
      startsOn: academicYear.starts_on,
      endsOn: academicYear.ends_on,
    },
    classInfo: {
      id: classInfo.id,
      name: classInfo.name,
      gradeLevel: classInfo.grade_level,
      classNumber: classInfo.class_number,
    },
    terms,
    classSubjects: [...subjectMap.values()].sort((a, b) => a.sortOrder - b.sortOrder),
  }
}

export function groupTeacherAssignments(rows) {
  const teachers = new Map()
  rows.forEach((row) => {
    const profile = relation(row.contact_book_profiles)
    if (!profile?.id) return
    const current = teachers.get(profile.id) || {
      id: profile.id,
      username: profile.username,
      displayName: profile.display_name,
      approvalStatus: profile.approval_status,
      isActive: profile.is_active,
      classSubjectIds: [],
    }
    if (row.class_subject_id && !current.classSubjectIds.includes(row.class_subject_id)) {
      current.classSubjectIds.push(row.class_subject_id)
    }
    teachers.set(profile.id, current)
  })
  return [...teachers.values()]
}

export async function loadApprovedTeachers({ classId }) {
  const client = requireSupabase()
  const { data, error } = await client
    .from('class_staff_assignments')
    .select('profile_id,class_subject_id,contact_book_profiles!class_staff_assignments_profile_id_fkey!inner(id,username,display_name,approval_status,is_active)')
    .eq('class_id', classId)
    .eq('role', 'subject_teacher')
    .is('ends_on', null)
    .eq('contact_book_profiles.approval_status', 'approved')
  if (error) throw new Error('無法讀取已核准教師與科目權限。')
  return groupTeacherAssignments(data || []).sort((a, b) => a.displayName.localeCompare(b.displayName, 'zh-TW'))
}

export async function setTeacherActive({ profileId, classId, isActive }) {
  const client = requireSupabase()
  const { data, error } = await client.rpc('admin_set_teacher_active', {
    p_profile_id: profileId,
    p_class_id: classId,
    p_is_active: isActive,
  })
  if (error) {
    const message = error.message || ''
    if (message.includes('invalid_approved_teacher')) throw new Error('找不到這位已核准教師，請重新整理。')
    if (message.includes('teacher_not_assigned_to_class')) throw new Error('這位教師已不在目前班級任教。')
    if (message.includes('admin_required') || message.includes('class_permission_required')) {
      throw new Error('目前帳號沒有停用或啟用教師的權限。')
    }
    throw new Error('教師帳號狀態更新失敗，請稍後再試。')
  }
  return data
}

export async function updateTeacherSubjects({ profileId, classId, classSubjectIds }) {
  const uniqueSubjectIds = [...new Set(classSubjectIds || [])]
  if (!uniqueSubjectIds.length) throw new Error('請至少保留一個任教科目。')
  const client = requireSupabase()
  const { data, error } = await client.rpc('admin_update_teacher_subjects', {
    p_profile_id: profileId,
    p_class_id: classId,
    p_class_subject_ids: uniqueSubjectIds,
  })
  if (error) {
    const message = error.message || ''
    if (message.includes('subject_required')) throw new Error('請至少保留一個任教科目。')
    if (message.includes('invalid_approved_teacher')) throw new Error('找不到這位已核准教師，請重新整理。')
    if (message.includes('invalid_class_subjects')) throw new Error('選擇的科目已變更，請重新整理後再試。')
    if (message.includes('admin_required')) throw new Error('目前帳號沒有調整教師權限的權限。')
    throw new Error('教師科目權限更新失敗，請稍後再試。')
  }
  return data
}

export async function loadTeacherDashboard() {
  const client = requireSupabase()
  const { data: userData, error: userError } = await client.auth.getUser()
  const userId = userData?.user?.id
  if (userError || !userId) throw new Error('教師登入狀態已失效，請重新登入。')

  const { data: profile, error: profileError } = await client
    .from('contact_book_profiles')
    .select('approval_status,is_active')
    .eq('id', userId)
    .single()
  if (profileError || profile?.approval_status !== 'approved' || !profile.is_active) {
    throw new Error('教師帳號已停用或尚未核准，請洽導師確認。')
  }

  const { data: assignments, error: assignmentError } = await client
    .from('class_staff_assignments')
    .select(`
      class_id,
      class_subject_id,
      starts_on,
      ends_on,
      classes!inner(
        id,
        name,
        grade_level,
        class_number,
        academic_years!inner(id,school_year,starts_on,ends_on)
      ),
      class_subjects!inner(
        id,
        sort_order,
        is_active,
        subjects!inner(id,code,name)
      )
    `)
    .eq('profile_id', userId)
    .eq('role', 'subject_teacher')
    .is('ends_on', null)
    .eq('class_subjects.is_active', true)

  if (assignmentError) throw new Error('無法讀取您的任教科目，請重新整理。')
  if (!assignments?.length) throw new Error('目前沒有可使用的任教科目，請洽導師確認權限。')

  const selectedClassId = assignments[0].class_id
  const selectedAssignments = assignments.filter((item) => item.class_id === selectedClassId)
  const classInfo = relation(selectedAssignments[0].classes)
  const academicYear = relation(classInfo?.academic_years)
  if (!academicYear?.id) throw new Error('任教班級的學年度尚未設定完成，請洽導師確認。')
  const { data: terms, error: termError } = await client
    .from('academic_terms')
    .select('id,semester,starts_on,ends_on')
    .eq('academic_year_id', academicYear.id)
    .order('semester')

  if (termError) throw new Error('無法讀取學期資料，請重新整理。')
  const dashboard = mapTeacherDashboardRows(selectedAssignments, terms || [])
  if (!dashboard?.terms.length || !dashboard.classSubjects.length) {
    throw new Error('教師工作台資料尚未設定完成，請洽導師確認。')
  }
  return dashboard
}
