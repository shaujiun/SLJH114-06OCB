import { describe, expect, it } from 'vitest'
import {
  announcementMonthKey,
  announcementMonthOptions,
  announcementPreview,
  announcementsForMonth,
} from './studentAnnouncementView.js'

describe('學生公告欄月份與摘要', () => {
  const announcements = [
    { id: 'a', publishedAt: '2026-09-01T00:30:00+08:00' },
    { id: 'b', publishedAt: '2026-08-31T23:30:00+08:00' },
    { id: 'c', publishedAt: '2025-09-10T10:00:00+08:00' },
  ]

  it('按臺灣發布月份歸類，年份不同的同月不混在一起', () => {
    expect(announcementMonthKey('2026-08-31T16:30:00Z')).toBe('2026-09')
    expect(announcementMonthOptions(announcements)).toEqual([
      { value: '2026-09', label: '2026 年 9 月' },
      { value: '2026-08', label: '2026 年 8 月' },
      { value: '2025-09', label: '2025 年 9 月' },
    ])
    expect(announcementsForMonth(announcements, '2026-09').map((item) => item.id)).toEqual(['a'])
    expect(announcementsForMonth(announcements).map((item) => item.id)).toEqual(['a', 'b', 'c'])
  })

  it('摘要最多顯示前兩句，長段落截短，全文仍由公告原文提供', () => {
    expect(announcementPreview('第一句。第二句！第三句。')).toBe('第一句。第二句！…')
    expect(announcementPreview('甲'.repeat(110))).toBe(`${'甲'.repeat(96)}…`)
    expect(announcementPreview('')).toBe('')
  })
})
