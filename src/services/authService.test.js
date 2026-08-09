import { beforeEach, describe, expect, it, vi } from 'vitest'
import { requireSupabase } from '../lib/supabase.js'
import { resetStudentPassword, restoreCurrentAccount } from './authService.js'

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

describe('Edge Function 錯誤訊息', () => {
  it('學生重設密碼時顯示函式回傳的中文原因', async () => {
    const invoke = vi.fn().mockResolvedValue({
      data: null,
      error: {
        message: 'Edge Function returned a non-2xx status code',
        context: new Response(JSON.stringify({
          error: '重設碼不正確、已使用或已超過 24 小時，請導師重新產生一組重設碼。',
        }), {
          status: 400,
          headers: { 'content-type': 'application/json' },
        }),
      },
    })
    requireSupabase.mockReturnValue({ functions: { invoke } })

    await expect(resetStudentPassword({
      studentId: '114108',
      resetCode: 'ABCD2345',
      password: 'newpass1',
    })).rejects.toThrow('重設碼不正確、已使用或已超過 24 小時')
  })

  it('沒有可讀回應時不再顯示 non-2xx 英文訊息', async () => {
    requireSupabase.mockReturnValue({
      functions: {
        invoke: vi.fn().mockResolvedValue({
          data: null,
          error: { message: 'Edge Function returned a non-2xx status code' },
        }),
      },
    })

    await expect(resetStudentPassword({
      studentId: '114108',
      resetCode: 'ABCD2345',
      password: 'newpass1',
    })).rejects.toThrow('系統目前無法完成操作')
  })
})
