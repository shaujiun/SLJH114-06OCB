import { describe, expect, it } from 'vitest'
import {
  buildExceptionSummary,
  buildPeriodExceptionSummaries,
  getHelperSubjectIds,
  getHelperSubjectPermissions,
  getEligibleHelperTermIds,
  groupStudentAssignments,
  mapStudentAssignmentRow,
  pickDefaultTermId,
} from './studentService.js'

describe('學生聯絡簿資料', () => {
  const terms = [
    { id: 'term-1', starts_on: '2026-08-10', ends_on: '2026-11-15' },
    { id: 'term-2', starts_on: '2026-11-30', ends_on: '2027-03-14' },
  ]

  it('開學前預設最近一個學期', () => {
    expect(pickDefaultTermId(terms, '2026-07-19')).toBe('term-1')
  })

  it('保留作業的科目與分組快照', () => {
    expect(mapStudentAssignmentRow({
      id: 'assignment-id', academic_term_id: 'term-1', assignment_date: '2026-08-10',
      content: '完成習作', due_at: '2026-08-11T00:00:00Z',
      target_type: 'group', target_group_code: 'B', published_by_display_name: '測試導師',
      class_subjects: { subjects: { code: 'math', name: '數學' } },
    })).toMatchObject({
      id: 'assignment-id', targetType: 'group', targetGroupCode: 'B',
      subject: { code: 'math', name: '數學' },
    })
  })

  it('不同科目的共同或同組作業會合併成同一區塊', () => {
    const groups = groupStudentAssignments([
      { id: 'english-b', targetType: 'group', targetGroupCode: 'B', subject: { name: '英語' } },
      { id: 'math-common', targetType: 'common', targetGroupCode: null, subject: { name: '數學' } },
      { id: 'math-b', targetType: 'group', targetGroupCode: 'B', subject: { name: '數學' } },
      { id: 'science-common', targetType: 'common', targetGroupCode: null, subject: { name: '自然' } },
    ])
    expect(groups.map((group) => group.label)).toEqual(['共同', 'B 組'])
    expect(groups[0].assignments.map((item) => item.id)).toEqual(['math-common', 'science-common'])
    expect(groups[1].assignments.map((item) => item.id)).toEqual(['english-b', 'math-b'])
  })

  it('補交紀錄三天內仍顯示，累積遲交不消失', () => {
    const future = new Date(Date.now() + 60_000).toISOString()
    const summary = buildExceptionSummary([
      { initialReason: 'late', workflowState: 'made_up', hideAfter: future, countsAsLate: true },
      { initialReason: 'not_brought', workflowState: 'open', hideAfter: null, countsAsLate: false },
    ])
    expect(summary.visible).toHaveLength(2)
    expect(summary.lateCount).toBe(1)
    expect(summary.notBroughtCount).toBe(1)
  })

  it('依作業繳交期限同時產生四種期間統計', () => {
    const assignments = [
      { id: 'week-item', dueAt: '2026-08-12T08:00:00+08:00' },
      { id: 'month-item', dueAt: '2026-08-25T08:00:00+08:00' },
      { id: 'term-item', dueAt: '2026-10-01T08:00:00+08:00' },
      { id: 'gap-item', dueAt: '2026-11-20T08:00:00+08:00' },
    ]
    const exceptions = [
      { assignmentId: 'week-item', currentReason: 'incomplete', workflowState: 'open', countsAsLate: false },
      { assignmentId: 'month-item', currentReason: 'not_brought', workflowState: 'made_up', countsAsLate: true },
      { assignmentId: 'term-item', currentReason: 'late', workflowState: 'made_up', countsAsLate: true },
      { assignmentId: 'gap-item', currentReason: 'incomplete', workflowState: 'open', countsAsLate: false },
    ]
    const summaries = buildPeriodExceptionSummaries({
      assignments,
      exceptions,
      terms: [
        { id: 'term-1', semester: 1, starts_on: '2026-08-10', ends_on: '2026-11-15' },
        { id: 'term-2', semester: 2, starts_on: '2026-11-30', ends_on: '2027-03-14' },
      ],
      selectedTermId: 'term-1',
      today: '2026-08-12',
    })
    expect(summaries.map((item) => item.key)).toEqual(['week', 'month', 'term', 'year'])
    expect(summaries[0]).toMatchObject({ openCount: 1, incompleteCount: 1, lateCount: 0 })
    expect(summaries[1]).toMatchObject({ incompleteCount: 1, notBroughtCount: 1, lateCount: 1 })
    expect(summaries[2]).toMatchObject({ incompleteCount: 1, notBroughtCount: 1, lateCount: 2 })
    expect(summaries[3]).toMatchObject({ incompleteCount: 2, notBroughtCount: 1, lateCount: 2 })
  })

  it('科目小老師只取得被指派科目，作業長取得全部科目', () => {
    const subjects = [{ id: 'math-id', code: 'math' }, { id: 'english-id', code: 'english' }, { id: 'science-id', code: 'science' }]
    expect(getHelperSubjectIds([
      { academicTermId: 'term-1', helperRole: 'subject_helper', classSubjectId: 'math-id' },
      { academicTermId: 'term-2', helperRole: 'subject_helper', classSubjectId: 'english-id' },
    ], subjects, 'term-1')).toEqual(['math-id'])
    expect(getHelperSubjectIds([
      { academicTermId: 'term-1', helperRole: 'homework_leader', classSubjectId: null },
    ], subjects, 'term-1')).toEqual(['math-id', 'english-id', 'science-id'])
    expect(getHelperSubjectPermissions([
      { academicTermId: 'term-1', helperRole: 'subject_helper', classSubjectId: 'math-id', targetGroupCode: 'B' },
      { academicTermId: 'term-1', helperRole: 'subject_helper', classSubjectId: 'science-id', targetGroupCode: null },
    ], subjects, 'term-1')).toEqual([
      expect.objectContaining({ id: 'math-id', allowedTargetGroups: ['B'] }),
      expect.objectContaining({ id: 'science-id', allowedTargetGroups: ['common'] }),
    ])
  })

  it('開學前可預先操作，學期結束後不再保留幹部操作權', () => {
    const helperAssignments = [
      { academicTermId: 'term-1', startsOn: '2026-08-10', endsOn: '2026-11-15' },
      { academicTermId: 'term-2', startsOn: '2026-11-30', endsOn: '2027-03-14' },
    ]
    expect(getEligibleHelperTermIds(helperAssignments, terms, '2026-07-19')).toEqual(['term-1'])
    expect(getEligibleHelperTermIds(helperAssignments, terms, '2026-11-20')).toEqual(['term-2'])
  })
})
