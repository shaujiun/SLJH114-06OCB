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
  const individual = { id: 'individual', targetType: 'individual' }

  it('共同作業會同時顯示在 A 組與 B 組', () => {
    const result = buildAssignmentBoardGroups([common, groupA, groupB, individual])

    expect(result.A.map((item) => item.id)).toEqual(['common', 'group-a', 'individual'])
    expect(result.B.map((item) => item.id)).toEqual(['common', 'group-b', 'individual'])
  })

  it('不會把另一組的專屬作業帶入', () => {
    const result = buildAssignmentBoardGroups([groupA, groupB])

    expect(result.A.map((item) => item.id)).toEqual(['group-a'])
    expect(result.B.map((item) => item.id)).toEqual(['group-b'])
  })

  it('資料未載入時安全回傳空看板', () => {
    expect(buildAssignmentBoardGroups()).toEqual({ A: [], B: [] })
  })
  it('全螢幕顯示當日作業、未到期未完成作業，以及逾期但有缺交名單的作業', () => {
    const now = new Date('2026-08-12T10:00:00+08:00')
    const assignments = [
      { id: 'today-open', assignmentDate: '2026-08-12', dueAt: '2026-08-12T17:00:00+08:00', isFullySubmitted: false },
      { id: 'today-complete', assignmentDate: '2026-08-12', dueAt: '2026-08-12T17:00:00+08:00', isFullySubmitted: true },
      { id: 'older-open', assignmentDate: '2026-08-10', dueAt: '2026-08-13T08:00:00+08:00', isFullySubmitted: false },
      { id: 'expired-with-missing', assignmentDate: '2026-08-10', dueAt: '2026-08-12T09:59:59+08:00', isFullySubmitted: false, outstandingSeatNumbers: [3, 8] },
      { id: 'expired-without-missing', assignmentDate: '2026-08-10', dueAt: '2026-08-12T09:59:59+08:00', isFullySubmitted: false, outstandingSeatNumbers: [] },
      { id: 'older-complete', assignmentDate: '2026-08-11', dueAt: '2026-08-13T08:00:00+08:00', isFullySubmitted: true },
      { id: 'future', assignmentDate: '2026-08-13', dueAt: '2026-08-14T08:00:00+08:00', isFullySubmitted: false },
    ]

    expect(filterCurrentAssignmentBoardItems(assignments, now).map((item) => item.id))
      .toEqual(['today-open', 'today-complete', 'older-open', 'expired-with-missing'])
  })

  it('前一上課日聯絡簿顯示該日全部作業，更早作業只保留有缺交名單者', () => {
    const now = new Date('2026-08-14T10:00:00+08:00')
    const assignments = [
      { id: 'previous-day-open', assignmentDate: '2026-08-13', dueAt: '2026-08-14T08:00:00+08:00', isFullySubmitted: false },
      { id: 'previous-day-complete', assignmentDate: '2026-08-13', dueAt: '2026-08-14T08:00:00+08:00', isFullySubmitted: true },
      { id: 'older-with-missing', assignmentDate: '2026-08-11', dueAt: '2026-08-12T08:00:00+08:00', isFullySubmitted: false, outstandingSeatNumbers: [5] },
      { id: 'older-without-missing', assignmentDate: '2026-08-12', dueAt: '2026-08-14T08:00:00+08:00', isFullySubmitted: false, outstandingSeatNumbers: [] },
      { id: 'today', assignmentDate: '2026-08-14', dueAt: '2026-08-15T08:00:00+08:00', isFullySubmitted: false },
    ]

    expect(filterPreviousDayAssignmentBoardItems(assignments, '2026-08-13').map((item) => item.id))
      .toEqual(['previous-day-open', 'previous-day-complete', 'older-with-missing'])
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
