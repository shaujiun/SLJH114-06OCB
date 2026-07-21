import { beforeEach, describe, expect, it, vi } from 'vitest'
import { requireSupabase } from '../lib/supabase.js'
import {
  createHonorEntries,
  deleteHonorGroup,
  groupHonorRows,
  mapHonorRow,
  setHonorVisibility,
  updateHonorGroup,
  validateHonorInput,
} from './honorService.js'

vi.mock('../lib/supabase.js', () => ({ requireSupabase: vi.fn() }))

describe('榮譽榜資料', () => {
  it('整理建立資料並限制必要欄位', () => {
    expect(validateHonorInput({
      studentIds: ['student-1', 'student-2', 'student-1'], title: '  校內   作文比賽  ', description: '  榮獲第一名  ', awardedOn: '2026-09-18',
    })).toEqual({ studentIds: ['student-1', 'student-2'], title: '校內 作文比賽', description: '榮獲第一名' })
    expect(() => validateHonorInput({ studentIds: [], title: '獲獎', description: '', awardedOn: '2026-09-18' }))
      .toThrow('請至少選擇一位獲獎學生。')
  })

  it('將同一次建立的多位學生合併為一個榮譽項目', () => {
    const groups = groupHonorRows([
      { id: 'entry-1', honor_group_id: 'group-1', class_id: 'class-id', student_id: 'student-1', student_display_name: '王小明', title: '接力賽第一名', description: null, awarded_on: '2026-10-01', is_visible: true, created_at: '2026-10-01T00:00:00Z' },
      { id: 'entry-2', honor_group_id: 'group-1', class_id: 'class-id', student_id: 'student-2', student_display_name: '陳小華', title: '接力賽第一名', description: null, awarded_on: '2026-10-01', is_visible: true, created_at: '2026-10-01T00:00:00Z' },
    ])
    expect(groups).toHaveLength(1)
    expect(groups[0].studentDisplayNames).toEqual(['王小明', '陳小華'])
  })

  it('將資料庫欄位轉為前端榮譽資料', () => {
    expect(mapHonorRow({
      id: 'honor-id', class_id: 'class-id', student_id: 'student-id', student_display_name: '王小明',
      title: '服務楷模', description: null, awarded_on: '2026-10-01', is_visible: true,
      created_at: '2026-10-01T00:00:00Z',
    })).toMatchObject({
      id: 'honor-id', studentDisplayName: '王小明', title: '服務楷模', description: '', isVisible: true,
    })
  })
})

describe('管理員建立榮譽榜', () => {
  const rpc = vi.fn()

  beforeEach(() => {
    rpc.mockReset()
    requireSupabase.mockReturnValue({ rpc })
  })

  it('透過受保護的資料庫操作保存學生姓名快照', async () => {
    rpc.mockResolvedValue({ data: { id: 'honor-id' }, error: null })
    await createHonorEntries({
      classId: 'class-id', studentIds: ['student-1', 'student-2'], title: '服務楷模', description: '', awardedOn: '2026-10-01',
    })
    expect(rpc).toHaveBeenCalledWith('admin_create_honor_entries', {
      p_class_id: 'class-id',
      p_student_ids: ['student-1', 'student-2'],
      p_title: '服務楷模',
      p_description: '',
      p_awarded_on: '2026-10-01',
    })
  })

  it('透過受保護的操作隱藏榮譽紀錄', async () => {
    rpc.mockResolvedValue({ data: null, error: null })
    await setHonorVisibility({ honorGroupId: 'group-id', isVisible: false })
    expect(rpc).toHaveBeenCalledWith('admin_set_honor_group_visibility', {
      p_honor_group_id: 'group-id',
      p_is_visible: false,
    })
  })

  it('以群組識別碼更新多人榮譽紀錄', async () => {
    rpc.mockResolvedValue({ data: { honorGroupId: 'group-id', studentCount: 2 }, error: null })
    await updateHonorGroup({
      honorGroupId: 'group-id',
      studentIds: ['student-1', 'student-2'],
      title: ' 校內   作文比賽 ',
      description: ' 優等 ',
      awardedOn: '2026-10-02',
    })
    expect(rpc).toHaveBeenCalledWith('admin_update_honor_group', {
      p_honor_group_id: 'group-id',
      p_student_ids: ['student-1', 'student-2'],
      p_title: '校內 作文比賽',
      p_description: '優等',
      p_awarded_on: '2026-10-02',
    })
  })

  it('透過受保護的操作刪除整組榮譽紀錄', async () => {
    rpc.mockResolvedValue({ data: { honorGroupId: 'group-id', deletedCount: 2 }, error: null })
    await deleteHonorGroup({ honorGroupId: 'group-id' })
    expect(rpc).toHaveBeenCalledWith('admin_delete_honor_group', {
      p_honor_group_id: 'group-id',
    })
  })
})
