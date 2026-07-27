import { describe, expect, it } from 'vitest'
import {
  buildQuizReminderItems,
  groupStudentQuizReminders,
  quizReminderDisplayText,
  quizReminderKey,
  reminderCountsFromRows,
} from './quizReminderService.js'

const subjects = [
  { id: 'chinese-id', code: 'chinese', name: '國文' },
  { id: 'english-id', code: 'english', name: '英語' },
  { id: 'science-id', code: 'science', name: '自然' },
]

describe('每日測驗提醒', () => {
  it('一般科目只建立共同提醒，英語可分共同、A、B 組', () => {
    const items = buildQuizReminderItems(subjects, {
      [quizReminderKey('chinese-id')]: 3,
      [quizReminderKey('english-id', 'A')]: 2,
      [quizReminderKey('english-id', 'B')]: 1,
      [quizReminderKey('science-id')]: 0,
    })
    expect(items).toEqual([
      {
        classSubjectId: 'chinese-id',
        targetType: 'common',
        targetGroupCode: null,
        quizCount: 3,
      },
      {
        classSubjectId: 'english-id',
        targetType: 'group',
        targetGroupCode: 'A',
        quizCount: 2,
      },
      {
        classSubjectId: 'english-id',
        targetType: 'group',
        targetGroupCode: 'B',
        quizCount: 1,
      },
    ])
  })

  it('把已儲存資料還原成輸入格次數', () => {
    expect(reminderCountsFromRows([
      {
        classSubjectId: 'english-id',
        targetType: 'group',
        targetGroupCode: 'B',
        quizCount: 2,
      },
    ])).toEqual({ 'english-id|B': 2 })
  })

  it('只分組指定日期及學期內的學生提醒', () => {
    const reminders = [
      {
        id: '1',
        academicTermId: 'term-1',
        reminderDate: '2026-08-10',
        targetType: 'common',
        targetGroupCode: null,
        quizCount: 3,
        subject: { name: '國文' },
      },
      {
        id: '2',
        academicTermId: 'term-1',
        reminderDate: '2026-08-10',
        targetType: 'group',
        targetGroupCode: 'B',
        quizCount: 2,
        subject: { name: '英語' },
      },
      {
        id: '3',
        academicTermId: 'term-1',
        reminderDate: '2026-08-09',
        targetType: 'common',
        targetGroupCode: null,
        quizCount: 1,
        subject: { name: '自然' },
      },
    ]
    const groups = groupStudentQuizReminders(
      reminders,
      'term-1',
      '2026-08-10',
    )
    expect(groups.map((group) => group.key)).toEqual(['common', 'B'])
    expect(groups[1].reminders[0].subject.name).toBe('英語')
  })

  it('一次省略乘號，多次顯示次數', () => {
    expect(quizReminderDisplayText({
      subject: { name: '自然' },
      quizCount: 1,
    })).toBe('自然')
    expect(quizReminderDisplayText({
      subject: { name: '國文' },
      quizCount: 3,
    })).toBe('國文 ×3')
  })
})
