import { beforeEach, describe, expect, it, vi } from 'vitest'
import { requireSupabase } from '../lib/supabase.js'
import {
  addClassSubject,
  approveTeacher,
  cancelAssignment,
  createStudentPasswordReset,
  createStudent,
  isFollowUpOverdue,
  mapSubmissionTrackingData,
  mapClassSubjectRow,
  regenerateStudentActivation,
  publishAssignment,
  recordSubmissionCheck,
  sortAssignmentsByTarget,
  updateClassSubjects,
  updateStudentSettings,
} from './adminService.js'

vi.mock('../lib/supabase.js', () => ({
  requireSupabase: vi.fn(),
}))

describe('班級科目資料', () => {
  it('保留 class_subjects ID，不被 subjects ID 覆蓋', () => {
    expect(mapClassSubjectRow({
      id: 'class-subject-id',
      sort_order: 4,
      subjects: { id: 'subject-id', code: 'science', name: '自然' },
    })).toEqual({
      id: 'class-subject-id',
      subjectId: 'subject-id',
      code: 'science',
      name: '自然',
      sortOrder: 4,
      isActive: true,
    })
  })
})

describe('管理員新增科目', () => {
  const rpc = vi.fn()

  beforeEach(() => {
    rpc.mockReset()
    requireSupabase.mockReturnValue({ rpc })
  })

  it('會整理科目名稱後呼叫資料庫', async () => {
    rpc.mockResolvedValue({
      data: { classSubjectId: 'class-subject-id', name: '資訊 科技' },
      error: null,
    })

    const result = await addClassSubject({ classId: 'class-id', name: '  資訊   科技  ' })

    expect(rpc).toHaveBeenCalledWith('admin_add_class_subject', {
      p_class_id: 'class-id',
      p_name: '資訊 科技',
    })
    expect(result.classSubjectId).toBe('class-subject-id')
  })

  it('會阻擋空白或過長的科目名稱', async () => {
    await expect(addClassSubject({ classId: 'class-id', name: '   ' }))
      .rejects.toThrow('科目名稱必須為 1 至 20 個字。')
    expect(rpc).not.toHaveBeenCalled()
  })

  it('會將重複科目轉為易懂的訊息', async () => {
    rpc.mockResolvedValue({ data: null, error: { message: 'subject_exists' } })

    await expect(addClassSubject({ classId: 'class-id', name: '自然' }))
      .rejects.toThrow('這個科目已經在班級科目中。')
  })
})

describe('管理員調整班級科目', () => {
  it('依畫面順序保存排序及啟用狀態', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: { activeCount: 1 }, error: null })
    requireSupabase.mockReturnValue({ rpc })
    await updateClassSubjects({
      classId: 'class-id',
      subjects: [
        { id: 'english-id', isActive: true },
        { id: 'math-id', isActive: false },
      ],
    })
    expect(rpc).toHaveBeenCalledWith('admin_update_class_subjects', {
      p_class_id: 'class-id',
      p_subjects: [
        { class_subject_id: 'english-id', is_active: true, sort_order: 10 },
        { class_subject_id: 'math-id', is_active: false, sort_order: 20 },
      ],
    })
  })

  it('至少保留一個啟用科目', async () => {
    await expect(updateClassSubjects({
      classId: 'class-id',
      subjects: [{ id: 'math-id', isActive: false }],
    })).rejects.toThrow('班級至少需要保留一個啟用科目。')
  })
})

describe('教師核准服務', () => {
  const rpc = vi.fn()

  beforeEach(() => {
    rpc.mockReset()
    requireSupabase.mockReturnValue({ rpc })
  })

  it('一次傳送班級與多個任教科目', async () => {
    rpc.mockResolvedValue({
      data: { assignedSubjectCount: 2 },
      error: null,
    })

    const result = await approveTeacher({
      profileId: 'teacher-id',
      classId: 'class-id',
      classSubjectIds: ['math-id', 'english-id'],
    })

    expect(rpc).toHaveBeenCalledWith('approve_pending_teacher', {
      p_profile_id: 'teacher-id',
      p_class_id: 'class-id',
      p_class_subject_ids: ['math-id', 'english-id'],
    })
    expect(result.assignedSubjectCount).toBe(2)
  })

  it('將未選科目的資料庫錯誤轉為中文提示', async () => {
    rpc.mockResolvedValue({
      data: null,
      error: { message: 'subject_required' },
    })

    await expect(approveTeacher({
      profileId: 'teacher-id',
      classId: 'class-id',
      classSubjectIds: [],
    })).rejects.toThrow('請至少選擇一個任教科目。')
  })
})

describe('作業發布服務', () => {
  it('已發布作業固定依共同、A 組、B 組排列', () => {
    const sorted = sortAssignmentsByTarget([
      { id: 'b-new', targetType: 'group', targetGroupCode: 'B', dueAt: '2026-08-13T08:00:00+08:00' },
      { id: 'a-new', targetType: 'group', targetGroupCode: 'A', dueAt: '2026-08-14T08:00:00+08:00' },
      { id: 'common-old', targetType: 'common', targetGroupCode: null, dueAt: '2026-08-11T08:00:00+08:00' },
      { id: 'common-new', targetType: 'common', targetGroupCode: null, dueAt: '2026-08-15T08:00:00+08:00' },
    ])
    expect(sorted.map((item) => item.id)).toEqual(['common-new', 'common-old', 'a-new', 'b-new'])
  })

  it('共同作業不傳分組代碼', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: { recipientCount: 2 }, error: null })
    requireSupabase.mockReturnValue({ rpc })
    await publishAssignment({
      classSubjectId: 'subject-id', academicTermId: 'term-id',
      assignmentDate: '2026-08-10', content: '完成學習單',
      dueAt: '2026-08-11T08:00', targetType: 'common', targetGroupCode: 'A',
    })
    expect(rpc).toHaveBeenCalledWith('publish_contact_book_assignment', expect.objectContaining({
      p_target_type: 'common', p_target_group_code: null,
    }))
  })

  it('允許作業日期位於所選學期範圍外', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: { recipientCount: 2 }, error: null })
    requireSupabase.mockReturnValue({ rpc })

    await publishAssignment({
      classSubjectId: 'subject-id', academicTermId: 'term-id',
      assignmentDate: '2026-07-19', content: '完成學習單',
      dueAt: '2026-07-20T08:00', targetType: 'common', targetGroupCode: null,
    })
    expect(rpc).toHaveBeenCalledWith('publish_contact_book_assignment', expect.objectContaining({
      p_academic_term_id: 'term-id',
      p_assignment_date: '2026-07-19',
    }))
  })

  it('由受保護的資料庫操作取消作業', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: { assignmentId: 'assignment-id' }, error: null })
    requireSupabase.mockReturnValue({ rpc })
    await cancelAssignment({ assignmentId: 'assignment-id' })
    expect(rpc).toHaveBeenCalledWith('cancel_contact_book_assignment', {
      p_assignment_id: 'assignment-id',
    })
  })
})

describe('作業繳交確認服務', () => {
  it('保留原始原因並依時間整理每次修正歷程', () => {
    const result = mapSubmissionTrackingData({
      recipients: [{
        student_id: 'student-id',
        students: { id: 'student-id', student_id_code: '900001', seat_number: 1, full_name: '測試學生甲' },
      }],
      checks: [],
      exceptions: [{
        id: 'exception-id', student_id: 'student-id', initial_reason: 'leave',
        current_reason: 'late', workflow_state: 'open', follow_up_due_at: '2026-08-17T08:00:00Z',
        counts_as_missing: false, counts_as_late: true, resolved_at: null,
        hide_after: null, updated_at: '2026-08-18T08:00:00Z',
      }],
      events: [
        { id: 'event-2', submission_exception_id: 'exception-id', from_reason: 'leave', to_reason: 'late', from_state: 'open', to_state: 'open', counts_as_missing: false, counts_as_late: true, changed_by: 'teacher-id', created_at: '2026-08-18T08:00:00Z' },
        { id: 'event-1', submission_exception_id: 'exception-id', from_reason: null, to_reason: 'leave', from_state: null, to_state: 'open', counts_as_missing: false, counts_as_late: false, changed_by: 'helper-id', created_at: '2026-08-10T08:00:00Z' },
      ],
    })

    expect(result.students[0].exception.initialReason).toBe('leave')
    expect(result.students[0].exception.events.map((event) => event.id)).toEqual(['event-1', 'event-2'])
  })

  it('只將仍開啟且已到期的請假或公假標為追繳逾期', () => {
    const now = new Date('2026-08-18T08:00:00Z').getTime()
    expect(isFollowUpOverdue({ workflowState: 'open', reason: 'leave', followUpDueAt: '2026-08-17T08:00:00Z' }, now)).toBe(true)
    expect(isFollowUpOverdue({ workflowState: 'made_up', reason: 'leave', followUpDueAt: '2026-08-17T08:00:00Z' }, now)).toBe(false)
    expect(isFollowUpOverdue({ workflowState: 'open', reason: 'incomplete', followUpDueAt: '2026-08-17T08:00:00Z' }, now)).toBe(false)
  })

  it('沒有例外學生時登記為全班已繳交', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: { openExceptionCount: 0 }, error: null })
    requireSupabase.mockReturnValue({ rpc })
    await recordSubmissionCheck({ assignmentId: 'assignment-id', exceptions: [] })
    expect(rpc).toHaveBeenCalledWith('record_assignment_submission_check_v2', {
      p_assignment_id: 'assignment-id', p_stage: 'teacher',
      p_result: 'all_submitted', p_exceptions: [],
    })
  })

  it('請假學生會傳送下一次繳交期限', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: { openExceptionCount: 1 }, error: null })
    requireSupabase.mockReturnValue({ rpc })
    await recordSubmissionCheck({
      assignmentId: 'assignment-id',
      exceptions: [{ studentId: 'student-id', reason: 'leave', followUpDueAt: '2026-08-18T08:00' }],
    })
    expect(rpc).toHaveBeenCalledWith('record_assignment_submission_check_v2', expect.objectContaining({
      p_result: 'exceptions_recorded',
      p_exceptions: [expect.objectContaining({ student_id: 'student-id', reason: 'leave' })],
    }))
  })

  it('學生幹部使用第一階段點收，不會冒用教師階段', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: { openExceptionCount: 0 }, error: null })
    requireSupabase.mockReturnValue({ rpc })
    await recordSubmissionCheck({ assignmentId: 'assignment-id', stage: 'helper', exceptions: [] })
    expect(rpc).toHaveBeenCalledWith('record_assignment_submission_check_v2', expect.objectContaining({
      p_stage: 'helper',
      p_result: 'all_submitted',
    }))
  })
})

describe('學生建檔服務', () => {
  it('以數英獨立分組呼叫受保護函式', async () => {
    const invoke = vi.fn().mockResolvedValue({
      data: { student: { fullName: '測試學生' }, activation: { code: 'ABC23456' } },
      error: null,
    })
    requireSupabase.mockReturnValue({ functions: { invoke } })

    const result = await createStudent({
      classId: 'class-id',
      academicTermId: 'term-id',
      studentId: ' 115001 ',
      seatNumber: '1',
      fullName: ' 測試學生 ',
      mathGroup: 'B',
      englishGroup: 'A',
    })

    expect(invoke).toHaveBeenCalledWith('admin-create-student', {
      body: {
        classId: 'class-id',
        academicTermId: 'term-id',
        studentId: '115001',
        seatNumber: 1,
        fullName: '測試學生',
        mathGroup: 'B',
        englishGroup: 'A',
      },
    })
    expect(result.activation.code).toBe('ABC23456')
  })

  it('以學期保存分組、作業長與各科小老師', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: { helperSubjectCount: 2 }, error: null })
    requireSupabase.mockReturnValue({ rpc })

    await updateStudentSettings({
      studentId: 'student-uuid',
      academicTermId: 'term-uuid',
      mathGroup: 'A',
      englishGroup: 'B',
      isHomeworkLeader: true,
      helperAssignments: [
        { classSubjectId: 'math-uuid', targetGroupCode: 'A' },
        { classSubjectId: 'science-uuid', targetGroupCode: null },
      ],
    })

    expect(rpc).toHaveBeenCalledWith('admin_update_student_settings_v2', {
      p_student_id: 'student-uuid',
      p_academic_term_id: 'term-uuid',
      p_math_group: 'A',
      p_english_group: 'B',
      p_is_homework_leader: true,
      p_helper_assignments: [
        { class_subject_id: 'math-uuid', target_group_code: 'A' },
        { class_subject_id: 'science-uuid', target_group_code: null },
      ],
    })
  })

  it('重發啟用碼時只傳學生識別資料', async () => {
    const invoke = vi.fn().mockResolvedValue({
      data: { activation: { code: 'NEW23456' } },
      error: null,
    })
    requireSupabase.mockReturnValue({ functions: { invoke } })

    const result = await regenerateStudentActivation({
      studentId: 'student-uuid',
      studentIdCode: '900001',
    })

    expect(invoke).toHaveBeenCalledWith('admin-regenerate-activation', {
      body: { studentId: 'student-uuid', studentIdCode: '900001' },
    })
    expect(result.activation.code).toBe('NEW23456')
  })

  it('已啟用學生可產生一次性密碼重設碼', async () => {
    const invoke = vi.fn().mockResolvedValue({
      data: { passwordReset: { code: 'RESET234' } },
      error: null,
    })
    requireSupabase.mockReturnValue({ functions: { invoke } })

    const result = await createStudentPasswordReset({
      studentId: 'student-uuid',
      studentIdCode: '900001',
    })

    expect(invoke).toHaveBeenCalledWith('admin-create-password-reset', {
      body: { studentId: 'student-uuid', studentIdCode: '900001' },
    })
    expect(result.passwordReset.code).toBe('RESET234')
  })
})
