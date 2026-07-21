import { beforeEach, describe, expect, it, vi } from 'vitest'
import { requireSupabase } from '../lib/supabase.js'
import { restoreCurrentAccount } from './authService.js'

vi.mock('../lib/supabase.js', () => ({ requireSupabase: vi.fn() }))

describe('恢復登入狀態', () => {
  const single = vi.fn()

  beforeEach(() => {
    single.mockReset()
    requireSupabase.mockReturnValue({
      auth: {
        getSession: vi.fn().mockResolvedValue({
          data: { session: { user: { id: 'teacher-id' } } },
          error: null,
        }),
      },
      from: vi.fn(() => ({
        select: vi.fn(() => ({
          eq: vi.fn(() => ({ single })),
        })),
      })),
    })
  })

  it('已停用帳號重新整理後不會恢復工作台', async () => {
    single.mockResolvedValue({
      data: {
        display_name: '李老師',
        user_type: 'teacher',
        approval_status: 'approved',
        is_active: false,
      },
      error: null,
    })
    await expect(restoreCurrentAccount()).resolves.toBeNull()
  })

  it('啟用中的帳號仍可恢復登入', async () => {
    single.mockResolvedValue({
      data: {
        display_name: '李老師',
        user_type: 'teacher',
        approval_status: 'approved',
        is_active: true,
      },
      error: null,
    })
    await expect(restoreCurrentAccount()).resolves.toEqual({
      displayName: '李老師',
      role: 'teacher',
      approvalStatus: 'approved',
    })
  })
})
