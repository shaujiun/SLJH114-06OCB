import { beforeEach, describe, expect, it, vi } from 'vitest'
import { requireSupabase } from '../lib/supabase.js'
import {
  mapAdmissionCheckRow,
  mapAdmissionCompetitionRow,
  saveMyAdmissionCompetition,
  saveMyAdmissionSelfCheck,
} from './admissionService.js'

vi.mock('../lib/supabase.js', () => ({ requireSupabase: vi.fn() }))

describe('超額比序資料轉換', () => {
  it('將資料庫欄位轉為學生表單欄位', () => {
    expect(mapAdmissionCheckRow({
      id: 'check-1', student_id: 'student-1', class_id: 'class-1',
      rule_version: 'yunlin-113-05-16', preference_order: 5,
      economic_weakness: false, nearby_enrollment: true,
      no_truancy_semesters: 3, discipline_status: 'none',
      semester_records: [{ semester: 'grade7_1', truancyPeriods: 0, warningCount: 0 }],
      balanced_domains: ['arts'], remote_school_band: 'other',
      balanced_scores: [{ semester: 'grade7_1', arts: 88 }],
      major_merits: 1, minor_merits: 2, commendations: 3,
      fitness_qualified_items: 2, fitness_gender: 'female',
      fitness_records: [{ semester: 'grade7_1', age: 13, curlUps: 13 }],
      review_status: 'reviewed',
      admin_note: '已核對', reviewed_at: '2026-10-06', updated_at: '2026-10-06',
    })).toMatchObject({
      id: 'check-1', studentId: 'student-1', preferenceOrder: 5,
      economicWeakness: false, nearbyEnrollment: true,
      balancedDomains: ['arts'], fitnessGender: 'female',
      reviewStatus: 'reviewed', adminNote: '已核對',
    })
  })

  it('保留競賽的採計狀態與快照名稱', () => {
    expect(mapAdmissionCompetitionRow({
      id: 'entry-1', self_check_id: 'check-1', student_id: 'student-1', class_id: 'class-1',
      catalog_id: 'catalog-1', catalog_code: 'county-03', competition_name: '全縣語文競賽',
      competition_detail: '國語朗讀', school_year: 115, tier: 'county', award_level: 'first',
      team_scale: 'individual', review_status: 'listed', admin_note: '', updated_at: '2026-10-06',
    })).toMatchObject({ catalogCode: 'county-03', competitionName: '全縣語文競賽', schoolYear: 115 })
  })
})

describe('學生超額比序儲存', () => {
  const rpc = vi.fn()

  beforeEach(() => {
    rpc.mockReset()
    rpc.mockResolvedValue({ data: 'saved-id', error: null })
    requireSupabase.mockReturnValue({ rpc })
  })

  it('固定項目只傳送可計分欄位', async () => {
    await saveMyAdmissionSelfCheck({
      preferenceOrder: '10', economicWeakness: true, nearbyEnrollment: false,
      noTruancySemesters: '4', disciplineStatus: 'none', balancedDomains: ['health', 'arts'],
      semesterRecords: [{ semester: 'grade7_1', truancyPeriods: '0', warningCount: '1', disciplineCleared: false }],
      balancedScores: [{ semester: 'grade7_1', health: '80', arts: '', integrated: '59', technology: '70' }],
      remoteSchoolBand: 'other', majorMerits: '1', minorMerits: '2', commendations: '3',
      fitnessQualifiedItems: '2', fitnessGender: 'male',
      fitnessRecords: [{ semester: 'grade7_1', age: '13', curlUps: '17', cardioType: 'run', cardioResult: '11:16' }],
      adminNote: '不可由學生改寫',
    })
    expect(rpc).toHaveBeenCalledWith('save_my_admission_self_check', {
      p_payload: expect.objectContaining({
        preferenceOrder: 10, noTruancySemesters: 4, majorMerits: 1,
        balancedDomains: ['health', 'arts'],
        fitnessGender: 'male',
      }),
    })
    const payload = rpc.mock.calls[0][1].p_payload
    expect(payload.semesterRecords[0]).toMatchObject({ truancyPeriods: 0, warningCount: 1 })
    expect(payload.balancedScores[0]).toMatchObject({ health: 80, arts: null, integrated: 59 })
    expect(payload.fitnessRecords[0]).toMatchObject({ age: 13, curlUps: 17, cardioResult: '11:16' })
    expect(rpc.mock.calls[0][1].p_payload).not.toHaveProperty('adminNote')
  })

  it('新增競賽時由資料庫依目錄代碼決定名稱與採計狀態', async () => {
    await saveMyAdmissionCompetition({
      catalogCode: 'national-01', schoolYear: 115, tier: 'national',
      awardLevel: 'first', teamScale: 'team_4_19', competitionDetail: '數學科',
    })
    expect(rpc).toHaveBeenCalledWith('save_my_admission_competition', {
      p_entry_id: null,
      p_catalog_code: 'national-01',
      p_custom_name: null,
      p_competition_detail: '數學科',
      p_school_year: 115,
      p_tier: 'national',
      p_award_level: 'first',
      p_team_scale: 'team_4_19',
    })
  })
})
