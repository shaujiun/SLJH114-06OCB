import { renderToStaticMarkup } from 'react-dom/server'
import { describe, expect, it } from 'vitest'
import { AssignmentGroupColumn } from './AssignmentBoard.jsx'

function render(assignments) {
  return renderToStaticMarkup(<AssignmentGroupColumn
    groupCode="A"
    assignments={assignments}
    quizReminders={[]}
    quizReminderLoading={false}
    quizReminderError=""
    quizReminderTitle="今日成績提醒"
    mode="current"
    referenceDate="2026-09-29"
    loading={false}
    error=""
  />)
}

describe('作業看板逾期提示', () => {
  it('有人逾期時在作業右側顯示月日且不加入期限文字', () => {
    const html = render([{
      id: 'late', content: '完成學習單', dueAt: '2020-09-28T17:00:00+08:00',
      subject: { name: '數學' }, pendingRecipientCount: 2, outstandingSeatNumbers: [2, 7],
      targetType: 'common',
    }])
    expect(html).toContain('class="is-overdue"')
    expect(html).toContain('<strong>完成學習單</strong><time')
    expect(html).toContain('>9/28</time>')
    expect(html).not.toContain('期限')
  })

  it('尚未到期時不顯示截止日期', () => {
    const html = render([{
      id: 'open', content: '完成習作', dueAt: '2099-09-30T17:00:00+08:00',
      subject: { name: '英語' }, pendingRecipientCount: 2, outstandingSeatNumbers: [3],
      targetType: 'common',
    }])
    expect(html).not.toContain('is-overdue')
    expect(html).not.toContain('>9/30</time>')
  })
})
