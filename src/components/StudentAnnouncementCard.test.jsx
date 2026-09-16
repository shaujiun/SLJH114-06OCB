import React from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { describe, expect, it } from 'vitest'
import { StudentAnnouncementCard } from './StudentDashboard.jsx'

const announcement = {
  id: 'notice-1',
  scope: 'class',
  publishedAt: '2026-09-15T09:00:00+08:00',
  title: '校外教學提醒',
  content: '第一句提醒。第二句提醒！第三句才是全文內容。',
  imageUrl: 'https://example.invalid/notice.png',
  imageAltText: '集合地點示意圖',
  readAt: null,
}

describe('學生公告卡片', () => {
  it('摘要在可點開區，全文、圖片與已讀按鈕只放在展開內容', () => {
    const html = renderToStaticMarkup(
      <StudentAnnouncementCard announcement={announcement} reading={false} onRead={() => {}} />,
    )
    const summary = html.slice(html.indexOf('<summary'), html.indexOf('</summary>'))
    const full = html.slice(html.indexOf('</summary>'))
    expect(html).toContain('<details')
    expect(summary).toContain('第一句提醒。第二句提醒！…')
    expect(summary).not.toContain('第三句才是全文內容')
    expect(summary).not.toContain('<img')
    expect(full).toContain('第三句才是全文內容')
    expect(full).toContain('集合地點示意圖')
    expect(full).toContain('我已閱讀')
  })

  it('已讀公告仍可展開全文，但不重複顯示已讀按鈕', () => {
    const html = renderToStaticMarkup(
      <StudentAnnouncementCard announcement={{ ...announcement, readAt: '2026-09-15T09:05:00+08:00' }}
        reading={false} onRead={() => {}} />,
    )
    expect(html).toContain('已閱讀')
    expect(html).not.toContain('我已閱讀')
  })
})
