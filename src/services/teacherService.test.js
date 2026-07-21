import { beforeEach, describe, expect, it, vi } from 'vitest'
import { requireSupabase } from '../lib/supabase.js'
import {
  groupTeacherAssignments,
  loadApprovedTeachers,
  mapTeacherDashboardRows,
  setTeacherActive,
  updateTeacherSubjects,
} from './teacherService.js'

vi.mock('../lib/supabase.js', () => ({ requireSupabase: vi.fn() }))

describe('已核准教師科目資料', () => {
  it('明確指定教師本人關聯，避免與建立者關聯衝突', async () => {
    const query = {
      select: vi.fn().mockReturnThis(),
      eq: vi.fn().mockReturnThis(),
      is: vi.fn().mockReturnThis(),
      then(resolve) { resolve({ data: [], error: null }) },
    }
    requireSupabase.mockReturnValue({ from: vi.fn().mockReturnValue(query) })

    await loadApprovedTeachers({ classId: 'class-id' })

    expect(query.select).toHaveBeenCalledWith(expect.stringContaining(
      'contact_book_profiles!class_staff_assignments_profile_id_fkey!inner',
    ))
  })

  it('將同一位教師的多筆科目指派合併', () => {
    const teachers = groupTeacherAssignments([
      { profile_id: 'teacher-id', class_subject_id: 'math-id', contact_book_profiles: { id: 'teacher-id', username: 'math01', display_name: '王老師', approval_status: 'approved', is_active: true } },
      { profile_id: 'teacher-id', class_subject_id: 'science-id', contact_book_profiles: { id: 'teacher-id', username: 'math01', display_name: '王老師', approval_status: 'approved', is_active: true } },
    ])
    expect(teachers).toHaveLength(1)
    expect(teachers[0].classSubjectIds).toEqual(['math-id', 'science-id'])
  })

  it('保留已停用教師及其原任教科目供管理員重新啟用', () => {
    const teachers = groupTeacherAssignments([
      { profile_id: 'teacher-id', class_subject_id: 'english-id', contact_book_profiles: { id: 'teacher-id', username: 'english01', display_name: '李老師', approval_status: 'approved', is_active: false } },
    ])
    expect(teachers[0]).toEqual(expect.objectContaining({
      id: 'teacher-id',
      isActive: false,
      classSubjectIds: ['english-id'],
    }))
  })

  it('將任課指派整理成只含獲授權科目的工作台資料', () => {
    const classData = {
      id: 'class-id', name: '八年六班', grade_level: 8, class_number: 6,
      academic_years: { id: 'year-id', school_year: 115, starts_on: '2026-08-10', ends_on: '2027-06-20' },
    }
    const rows = [
      { classes: classData, class_subjects: { id: 'science-id', sort_order: 4, is_active: true, subjects: { id: 'science', code: 'science', name: '自然' } } },
      { classes: classData, class_subjects: { id: 'math-id', sort_order: 2, is_active: true, subjects: { id: 'math', code: 'math', name: '數學' } } },
    ]
    const dashboard = mapTeacherDashboardRows(rows, [{ id: 'term-id', semester: 1 }])
    expect(dashboard.classInfo.name).toBe('八年六班')
    expect(dashboard.classSubjects.map((item) => item.name)).toEqual(['數學', '自然'])
    expect(dashboard.terms).toEqual([{ id: 'term-id', semester: 1 }])
  })
})

describe('調整教師任教科目', () => {
  const rpc = vi.fn()

  beforeEach(() => {
    rpc.mockReset()
    requireSupabase.mockReturnValue({ rpc })
  })

  it('去除重複科目後呼叫受保護的資料庫操作', async () => {
    rpc.mockResolvedValue({ data: { assignedSubjectCount: 2 }, error: null })
    await updateTeacherSubjects({ profileId: 'teacher-id', classId: 'class-id', classSubjectIds: ['math-id', 'science-id', 'math-id'] })
    expect(rpc).toHaveBeenCalledWith('admin_update_teacher_subjects', {
      p_profile_id: 'teacher-id',
      p_class_id: 'class-id',
      p_class_subject_ids: ['math-id', 'science-id'],
    })
  })

  it('不允許移除所有任教科目', async () => {
    await expect(updateTeacherSubjects({ profileId: 'teacher-id', classId: 'class-id', classSubjectIds: [] }))
      .rejects.toThrow('請至少保留一個任教科目。')
    expect(rpc).not.toHaveBeenCalled()
  })

  it('透過受保護函式停用教師並保留科目指派', async () => {
    rpc.mockResolvedValue({ data: { profileId: 'teacher-id', isActive: false }, error: null })
    await setTeacherActive({ profileId: 'teacher-id', classId: 'class-id', isActive: false })
    expect(rpc).toHaveBeenCalledWith('admin_set_teacher_active', {
      p_profile_id: 'teacher-id',
      p_class_id: 'class-id',
      p_is_active: false,
    })
  })
})
