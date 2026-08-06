import { beforeEach, describe, expect, it, vi } from 'vitest'
import { requireSupabase } from '../lib/supabase.js'
import { setGradeRankVisibility } from './gradeService.js'

vi.mock('../lib/supabase.js', () => ({ requireSupabase: vi.fn() }))

describe('導師設定學生端排名顯示', () => {
  const rpc = vi.fn()

  beforeEach(() => {
    rpc.mockReset()
    requireSupabase.mockReturnValue({ rpc })
  })

  it('一次保存班排與校排兩個獨立設定', async () => {
    rpc.mockResolvedValue({
      data: { showClassRank: true, showSchoolRank: false },
      error: null,
    })
    const result = await setGradeRankVisibility({
      classId: 'class-id',
      showClassRank: true,
      showSchoolRank: false,
    })
    expect(rpc).toHaveBeenCalledWith('admin_set_grade_rank_visibility', {
      p_class_id: 'class-id',
      p_show_class_rank: true,
      p_show_school_rank: false,
    })
    expect(result).toEqual({ showClassRank: true, showSchoolRank: false })
  })

  it('未具權限時提供明確訊息', async () => {
    rpc.mockResolvedValue({ data: null, error: { message: 'permission_denied' } })
    await expect(setGradeRankVisibility({
      classId: 'class-id',
      showClassRank: true,
      showSchoolRank: true,
    })).rejects.toThrow('目前帳號沒有調整學生排名顯示的權限。')
  })
})
