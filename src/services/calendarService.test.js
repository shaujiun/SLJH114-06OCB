import { beforeEach, describe, expect, it, vi } from 'vitest'
import { requireSupabase } from '../lib/supabase.js'
import {
  buildMonthCells,
  eventsOnDate,
  saveCalendarEvent,
  shiftMonth,
  validateCalendarEventInput,
} from './calendarService.js'

vi.mock('../lib/supabase.js', () => ({ requireSupabase: vi.fn() }))

describe('行事曆日期工具', () => {
  it('可跨年切換月份並建立完整六週月曆', () => {
    expect(shiftMonth('2026-12', 1)).toBe('2027-01')
    const cells = buildMonthCells('2026-08')
    expect(cells).toHaveLength(42)
    expect(cells.filter((cell) => cell.isCurrentMonth)).toHaveLength(31)
  })

  it('跨日行程會出現在期間內的每一天', () => {
    const event = { startsOn: '2026-08-10', endsOn: '2026-08-12' }
    expect(eventsOnDate([event], '2026-08-11')).toEqual([event])
    expect(eventsOnDate([event], '2026-08-13')).toEqual([])
  })
})

describe('行事曆管理服務', () => {
  const rpc = vi.fn()

  beforeEach(() => {
    rpc.mockReset()
    requireSupabase.mockReturnValue({ rpc })
  })

  it('全天行程不傳送時間並整理文字', async () => {
    rpc.mockResolvedValue({ data: { id: 'event-id' }, error: null })
    await saveCalendarEvent({
      classId: 'class-id', title: '  校外   教學 ', description: '', location: ' 科博館 ',
      category: 'school_activity', startsOn: '2026-10-01', endsOn: '2026-10-02',
      isAllDay: true, startTime: '08:00', endTime: '16:00',
    })
    expect(rpc).toHaveBeenCalledWith('admin_save_calendar_event', expect.objectContaining({
      p_title: '校外 教學', p_location: '科博館', p_start_time: null, p_end_time: null,
    }))
  })

  it('同日非全天行程必須晚於開始時間', () => {
    expect(() => validateCalendarEventInput({
      title: '班會', category: 'class_activity', startsOn: '2026-08-10', endsOn: '2026-08-10',
      isAllDay: false, startTime: '09:00', endTime: '08:00',
    })).toThrow('結束時間必須晚於開始時間。')
  })
})
