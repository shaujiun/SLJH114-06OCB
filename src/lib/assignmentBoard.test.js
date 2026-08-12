import { describe, expect, it } from 'vitest'
import { buildAssignmentBoardGroups, filterCurrentAssignmentBoardItems } from './assignmentBoard.js'

describe('作業長全畫面作業看板', () => {
  const common = { id: 'common', targetType: 'common' }
  const groupA = { id: 'group-a', targetType: 'group', targetGroupCode: 'A' }
  const groupB = { id: 'group-b', targetType: 'group', targetGroupCode: 'B' }

  it('共同作業會同時顯示在 A 組與 B 組', () => {
    const result = buildAssignmentBoardGroups([common, groupA, groupB])

    expect(result.A.map((item) => item.id)).toEqual(['common', 'group-a'])
    expect(result.B.map((item) => item.id)).toEqual(['common', 'group-b'])
  })

  it('不會把另一組的專屬作業帶入', () => {
    const result = buildAssignmentBoardGroups([groupA, groupB])

    expect(result.A.map((item) => item.id)).toEqual(['group-a'])
    expect(result.B.map((item) => item.id)).toEqual(['group-b'])
  })

  it('資料未載入時安全回傳空看板', () => {
    expect(buildAssignmentBoardGroups()).toEqual({ A: [], B: [] })
  })
  it('全螢幕只保留今天以前發布、未到期且尚未全班繳交的作業', () => {
    const now = new Date('2026-08-12T10:00:00+08:00')
    const assignments = [
      { id: 'today-open', assignmentDate: '2026-08-13', publishedAt: '2026-08-12T09:00:00+08:00', dueAt: '2026-08-12T17:00:00+08:00', isFullySubmitted: false },
      { id: 'older-open', assignmentDate: '2026-08-13', publishedAt: '2026-08-10T09:00:00+08:00', dueAt: '2026-08-13T08:00:00+08:00', isFullySubmitted: false },
      { id: 'expired', assignmentDate: '2026-08-13', publishedAt: '2026-08-10T09:00:00+08:00', dueAt: '2026-08-12T09:59:59+08:00', isFullySubmitted: false },
      { id: 'fully-submitted', assignmentDate: '2026-08-13', publishedAt: '2026-08-11T09:00:00+08:00', dueAt: '2026-08-13T08:00:00+08:00', isFullySubmitted: true },
      { id: 'future', assignmentDate: '2026-08-13', publishedAt: '2026-08-13T09:00:00+08:00', dueAt: '2026-08-14T08:00:00+08:00', isFullySubmitted: false },
    ]

    expect(filterCurrentAssignmentBoardItems(assignments, now).map((item) => item.id))
      .toEqual(['today-open', 'older-open'])
  })
})
