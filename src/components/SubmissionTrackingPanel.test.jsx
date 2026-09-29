import { describe, expect, it } from 'vitest'
import { hasSubmissionStatusChanged } from './SubmissionTrackingPanel.jsx'

describe('個別繳交狀態批次編輯', () => {
  it('狀態或補交期限有異動時才列入待儲存名單', () => {
    const initial = { status: 'leave', followUpDueAt: '2026-10-02T16:00' }
    expect(hasSubmissionStatusChanged({ ...initial }, initial)).toBe(false)
    expect(hasSubmissionStatusChanged({ ...initial, status: 'submitted', followUpDueAt: '' }, initial)).toBe(true)
    expect(hasSubmissionStatusChanged({ ...initial, followUpDueAt: '2026-10-03T16:00' }, initial)).toBe(true)
  })
})
