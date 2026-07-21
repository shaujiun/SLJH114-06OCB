import { createClient } from '@supabase/supabase-js'
import process from 'node:process'

const vocabularyTables = [
  'profiles',
  'vocabulary',
  'student_progress',
  'mastered_words',
]

const contactBookTables = [
  'schools',
  'academic_years',
  'academic_terms',
  'classes',
  'contact_book_profiles',
  'students',
  'student_activation_codes',
  'auth_rate_limits',
  'subjects',
  'class_subjects',
  'class_staff_assignments',
  'student_helper_assignments',
  'student_subject_groups',
  'assignments',
  'assignment_recipients',
  'submission_checks',
  'submission_exceptions',
  'submission_status_events',
  'announcements',
  'announcement_reads',
  'honor_entries',
  'calendar_events',
  'assessment_periods',
  'assessments',
  'student_scores',
]

const contactBookRpcs = [
  'admin_create_student',
  'admin_replace_student_activation',
  'admin_update_student_settings',
  'approve_pending_teacher',
  'complete_student_activation',
  'register_pending_teacher',
  'consume_auth_rate_limit',
  'publish_contact_book_assignment',
  'record_assignment_submission_check',
  'admin_save_calendar_event',
  'admin_set_calendar_event_active',
]

function requiredEnvironment(name) {
  const value = process.env[name]?.trim()
  if (!value) throw new Error(`Missing required environment value: ${name}`)
  return value
}

async function countRows(client, tableName) {
  const { count, error } = await client
    .from(tableName)
    .select('*', { count: 'exact', head: true })

  if (error) throw new Error(`Unable to verify ${tableName}: ${error.message}`)
  return count
}

async function countAuthUsers(client) {
  let total = 0
  const perPage = 1000

  for (let page = 1; ; page += 1) {
    const { data, error } = await client.auth.admin.listUsers({ page, perPage })
    if (error) throw new Error(`Unable to verify Auth users: ${error.message}`)
    total += data.users.length
    if (data.users.length < perPage) return total
  }
}

async function main() {
  const supabaseUrl = requiredEnvironment('SUPABASE_URL')
  const serviceRoleKey = requiredEnvironment('SUPABASE_SERVICE_ROLE_KEY')
  const client = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  })

  const vocabularyCounts = Object.fromEntries(
    await Promise.all(
      vocabularyTables.map(async (tableName) => [tableName, await countRows(client, tableName)]),
    ),
  )
  const contactBookCounts = Object.fromEntries(
    await Promise.all(
      contactBookTables.map(async (tableName) => [tableName, await countRows(client, tableName)]),
    ),
  )

  const openApiResponse = await fetch(`${supabaseUrl}/rest/v1/`, {
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      Accept: 'application/openapi+json',
    },
  })
  if (!openApiResponse.ok) {
    throw new Error(`Unable to verify REST schema: HTTP ${openApiResponse.status}`)
  }

  const openApiSchema = await openApiResponse.json()
  const missingRpcs = contactBookRpcs.filter(
    (functionName) => !openApiSchema.paths?.[`/rpc/${functionName}`],
  )
  if (missingRpcs.length > 0) {
    throw new Error(`Missing contact book RPCs: ${missingRpcs.join(', ')}`)
  }

  const { count: approvedAdmins, error: adminError } = await client
    .from('contact_book_profiles')
    .select('id', { count: 'exact', head: true })
    .eq('user_type', 'admin')
    .eq('approval_status', 'approved')
    .eq('is_active', true)
  if (adminError) throw new Error(`Unable to verify administrators: ${adminError.message}`)

  const { count: pendingTeachers, error: teacherError } = await client
    .from('contact_book_profiles')
    .select('id', { count: 'exact', head: true })
    .eq('user_type', 'teacher')
    .eq('approval_status', 'pending')
  if (teacherError) throw new Error(`Unable to verify pending teachers: ${teacherError.message}`)

  const { data: termSchedule, error: termError } = await client
    .from('academic_terms')
    .select('semester,starts_on,ends_on,academic_years!inner(school_year)')
    .eq('academic_years.school_year', 115)
    .order('semester')
  if (termError) throw new Error(`Unable to verify academic terms: ${termError.message}`)

  console.log(JSON.stringify({
    vocabularyCounts,
    authUsers: await countAuthUsers(client),
    contactBookTables: Object.keys(contactBookCounts).length,
    contactBookRows: Object.values(contactBookCounts).reduce((sum, count) => sum + count, 0),
    contactBookRpcs: contactBookRpcs.length,
    referenceData: {
      schools: contactBookCounts.schools,
      academicYears: contactBookCounts.academic_years,
      academicTerms: contactBookCounts.academic_terms,
      classes: contactBookCounts.classes,
      subjects: contactBookCounts.subjects,
      classSubjects: contactBookCounts.class_subjects,
      staffAssignments: contactBookCounts.class_staff_assignments,
      students: contactBookCounts.students,
      activationCodes: contactBookCounts.student_activation_codes,
      subjectGroups: contactBookCounts.student_subject_groups,
      helperAssignments: contactBookCounts.student_helper_assignments,
      assignments: contactBookCounts.assignments,
      assignmentRecipients: contactBookCounts.assignment_recipients,
      submissionChecks: contactBookCounts.submission_checks,
      submissionExceptions: contactBookCounts.submission_exceptions,
      submissionStatusEvents: contactBookCounts.submission_status_events,
      calendarEvents: contactBookCounts.calendar_events,
    },
    approvedAdmins,
    pendingTeachers,
    termSchedule: termSchedule.map((term) => ({
      semester: term.semester,
      startsOn: term.starts_on,
      endsOn: term.ends_on,
    })),
  }))
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : 'Verification failed.')
  process.exitCode = 1
})
