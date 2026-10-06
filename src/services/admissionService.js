import { requireSupabase } from '../lib/supabase.js'
import { emptyAdmissionCheck } from '../lib/admissionScoring.js'

function requireData(data, error, message) {
  if (error) throw new Error(message)
  return data
}

export function mapAdmissionCheckRow(row) {
  if (!row) return emptyAdmissionCheck()
  return {
    id: row.id,
    studentId: row.student_id,
    classId: row.class_id,
    ruleVersion: row.rule_version,
    preferenceOrder: row.preference_order ?? '',
    economicWeakness: row.economic_weakness,
    nearbyEnrollment: row.nearby_enrollment,
    noTruancySemesters: row.no_truancy_semesters ?? 0,
    disciplineStatus: row.discipline_status || '',
    balancedDomains: Array.isArray(row.balanced_domains) ? row.balanced_domains : [],
    remoteSchoolBand: row.remote_school_band || '',
    majorMerits: row.major_merits ?? 0,
    minorMerits: row.minor_merits ?? 0,
    commendations: row.commendations ?? 0,
    fitnessQualifiedItems: row.fitness_qualified_items ?? 0,
    reviewStatus: row.review_status || 'self_reported',
    adminNote: row.admin_note || '',
    reviewedAt: row.reviewed_at,
    updatedAt: row.updated_at,
  }
}

export function mapAdmissionCompetitionRow(row) {
  return {
    id: row.id,
    selfCheckId: row.self_check_id,
    studentId: row.student_id,
    classId: row.class_id,
    catalogId: row.catalog_id,
    catalogCode: row.catalog_code,
    competitionName: row.competition_name,
    competitionDetail: row.competition_detail || '',
    schoolYear: row.school_year,
    tier: row.tier,
    awardLevel: row.award_level,
    teamScale: row.team_scale,
    reviewStatus: row.review_status,
    adminNote: row.admin_note || '',
    reviewedAt: row.reviewed_at,
    updatedAt: row.updated_at,
  }
}

export function mapAdmissionCatalogRow(row) {
  return {
    id: row.id,
    code: row.code,
    tier: row.tier,
    name: row.name,
    comparisonEvent: row.comparison_event || '',
    detailNote: row.detail_note || '',
    sortOrder: row.sort_order,
  }
}

async function loadCatalog(client) {
  const result = await client
    .from('admission_competition_catalog')
    .select('id,code,tier,name,comparison_event,detail_note,sort_order')
    .eq('is_active', true)
    .order('tier')
    .order('sort_order')
  return requireData(result.data, result.error, '無法讀取競賽項目，請稍後再試。')
    .map(mapAdmissionCatalogRow)
}

export async function loadMyAdmissionSelfCheck(studentId) {
  const client = requireSupabase()
  const [checkResult, entriesResult, catalog] = await Promise.all([
    client
      .from('admission_self_checks')
      .select('*')
      .eq('student_id', studentId)
      .maybeSingle(),
    client
      .from('admission_competition_entries')
      .select('*')
      .eq('student_id', studentId)
      .order('school_year')
      .order('created_at'),
    loadCatalog(client),
  ])

  return {
    check: mapAdmissionCheckRow(requireData(
      checkResult.data,
      checkResult.error,
      '無法讀取超額比序自我檢核表。',
    )),
    competitions: requireData(
      entriesResult.data,
      entriesResult.error,
      '無法讀取競賽紀錄。',
    ).map(mapAdmissionCompetitionRow),
    catalog,
  }
}

export async function saveMyAdmissionSelfCheck(check) {
  const client = requireSupabase()
  const { data, error } = await client.rpc('save_my_admission_self_check', {
    p_payload: {
      preferenceOrder: check.preferenceOrder === '' ? null : Number(check.preferenceOrder),
      economicWeakness: check.economicWeakness,
      nearbyEnrollment: check.nearbyEnrollment,
      noTruancySemesters: Number(check.noTruancySemesters || 0),
      disciplineStatus: check.disciplineStatus || null,
      balancedDomains: check.balancedDomains || [],
      remoteSchoolBand: check.remoteSchoolBand || null,
      majorMerits: Number(check.majorMerits || 0),
      minorMerits: Number(check.minorMerits || 0),
      commendations: Number(check.commendations || 0),
      fitnessQualifiedItems: Number(check.fitnessQualifiedItems || 0),
    },
  })
  if (error) throw new Error('自我檢核表儲存失敗，請檢查欄位後再試。')
  return data
}

export async function saveMyAdmissionCompetition(entry) {
  const client = requireSupabase()
  const { data, error } = await client.rpc('save_my_admission_competition', {
    p_entry_id: entry.id || null,
    p_catalog_code: entry.catalogCode || null,
    p_custom_name: entry.customName || null,
    p_competition_detail: entry.competitionDetail || '',
    p_school_year: Number(entry.schoolYear),
    p_tier: entry.tier,
    p_award_level: entry.awardLevel,
    p_team_scale: entry.teamScale,
  })
  if (error) throw new Error('競賽紀錄儲存失敗，請確認競賽、名次及團體人數。')
  return data
}

export async function deleteMyAdmissionCompetition(entryId) {
  const client = requireSupabase()
  const { error } = await client.rpc('delete_my_admission_competition', {
    p_entry_id: entryId,
  })
  if (error) throw new Error('競賽紀錄刪除失敗，請稍後再試。')
}

export async function loadAdminAdmissionWorkspace(classId) {
  const client = requireSupabase()
  const [studentsResult, checksResult, entriesResult, catalog] = await Promise.all([
    client
      .from('students')
      .select('id,student_id_code,seat_number,full_name')
      .eq('class_id', classId)
      .eq('is_active', true)
      .order('seat_number'),
    client
      .from('admission_self_checks')
      .select('*')
      .eq('class_id', classId),
    client
      .from('admission_competition_entries')
      .select('*')
      .eq('class_id', classId)
      .order('school_year')
      .order('created_at'),
    loadCatalog(client),
  ])

  const students = requireData(studentsResult.data, studentsResult.error, '無法讀取學生名單。')
  const checks = requireData(checksResult.data, checksResult.error, '無法讀取學生自我檢核表。')
    .map(mapAdmissionCheckRow)
  const competitions = requireData(entriesResult.data, entriesResult.error, '無法讀取學生競賽紀錄。')
    .map(mapAdmissionCompetitionRow)

  return {
    students: students.map((student) => ({
      id: student.id,
      studentId: student.student_id_code,
      seatNumber: student.seat_number,
      fullName: student.full_name,
    })),
    checks,
    competitions,
    catalog,
  }
}

export async function reviewAdmissionSelfCheck({ selfCheckId, reviewStatus, adminNote }) {
  const client = requireSupabase()
  const { error } = await client.rpc('admin_review_admission_self_check', {
    p_self_check_id: selfCheckId,
    p_review_status: reviewStatus,
    p_admin_note: adminNote || '',
  })
  if (error) throw new Error('檢核狀態儲存失敗，請稍後再試。')
}

export async function reviewAdmissionCompetition({ entryId, reviewStatus, adminNote }) {
  const client = requireSupabase()
  const { error } = await client.rpc('admin_review_admission_competition', {
    p_entry_id: entryId,
    p_review_status: reviewStatus,
    p_admin_note: adminNote || '',
  })
  if (error) throw new Error('競賽審閱結果儲存失敗，請稍後再試。')
}
