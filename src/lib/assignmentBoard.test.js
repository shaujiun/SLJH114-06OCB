import { describe, expect, it } from 'vitest'
import {
  buildAssignmentBoardGroups,
  filterCurrentAssignmentBoardItems,
  filterPreviousDayAssignmentBoardItems,
  previousLocalDateString,
  previousSchoolDateString,
} from './assignmentBoard.js'

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

  it('前一上課日聯絡簿包含當日發布及更早發布但當時仍未逾期的作業', () => {
    const now = new Date('2026-08-14T10:00:00+08:00')
    const assignments = [
      { id: 'previous-day-open', publishedAt: '2026-08-13T09:00:00+08:00', dueAt: '2026-08-14T08:00:00+08:00', isFullySubmitted: false },
      { id: 'previous-day-complete', publishedAt: '2026-08-13T10:00:00+08:00', dueAt: '2026-08-14T08:00:00+08:00', isFullySubmitted: true },
      { id: 'older-open', publishedAt: '2026-08-11T09:00:00+08:00', dueAt: '2026-08-14T08:00:00+08:00', isFullySubmitted: false },
      { id: 'published-today', publishedAt: '2026-08-14T08:00:00+08:00', dueAt: '2026-08-15T08:00:00+08:00', isFullySubmitted: false },
      { id: 'expired-before-reference-ended', publishedAt: '2026-08-12T09:00:00+08:00', dueAt: '2026-08-13T17:00:00+08:00', isFullySubmitted: false },
    ]

    expect(filterPreviousDayAssignmentBoardItems(assignments, '2026-08-13', now).map((item) => item.id))
      .toEqual(['previous-day-open', 'older-open'])
    expect(previousLocalDateString(now)).toBe('2026-08-13')
  })

  it('前一次上課日會跳過週末及行事曆中的放假日', () => {
    const monday = new Date('2026-08-17T09:00:00+08:00')
    expect(previousSchoolDateString(monday)).toBe('2026-08-14')
    expect(previousSchoolDateString(monday, [
      { category: 'holiday', startsOn: '2026-08-14', endsOn: '2026-08-14' },
    ])).toBe('2026-08-13')
  })
})
