import { describe, expect, it } from 'vitest'
import {
  formatAssignmentDueMonthDay,
  isAssignmentOverdue,
  isPastAssignmentDue,
} from './assignmentDeadline.js'

describe('作業逾期顯示', () => {
  const now = new Date('2026-09-29T12:00:00+08:00')

  it('截止時間已過且仍有人未繳才算逾期', () => {
    expect(isAssignmentOverdue({
      dueAt: '2026-09-29T11:59:00+08:00', pendingRecipientCount: 1,
    }, now)).toBe(true)
    expect(isAssignmentOverdue({
      dueAt: '2026-09-29T13:00:00+08:00', pendingRecipientCount: 1,
    }, now)).toBe(false)
    expect(isAssignmentOverdue({
      dueAt: '2026-09-29T11:59:00+08:00', pendingRecipientCount: 0,
    }, now)).toBe(false)
  })

  it('缺交名單可單獨判斷截止時間並只顯示月日', () => {
    expect(isPastAssignmentDue('2026-09-28T23:59:00+08:00', now)).toBe(true)
    expect(formatAssignmentDueMonthDay('2026-09-28T23:59:00+08:00')).toBe('9/28')
    expect(formatAssignmentDueMonthDay('')).toBe('')
  })
})
