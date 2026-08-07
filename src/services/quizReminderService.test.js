import { describe, expect, it } from 'vitest'
import {
  buildQuizReminderItems,
  buildQuizReminderBoardGroups,
  groupStudentQuizReminders,
  quizReminderDisplayText,
  quizReminderKey,
  reminderCountsFromRows,
  splitQuizReminderSubjects,
} from './quizReminderService.js'

const subjects = [
  { id: 'chinese-id', code: 'chinese', name: '國文' },
  { id: 'english-id', code: 'english', name: '英語' },
  { id: 'science-id', code: 'science', name: '自然' },
]

describe('每日測驗提醒', () => {
  it('將英語與數學放在第一列，並以歷史、地理、公民取代社會總項', () => {
    const arranged = splitQuizReminderSubjects([
      { id: 'social-id', code: 'social', name: '社會', sortOrder: 50 },
      { id: 'math-id', code: 'math', name: '數學', sortOrder: 30 },
      { id: 'history-id', code: 'history', name: '歷史', sortOrder: 51 },
      { id: 'chinese-id', code: 'chinese', name: '國文', sortOrder: 10 },
      { id: 'english-id', code: 'english', name: '英語', sortOrder: 20 },
      { id: 'geography-id', code: 'geography', name: '地理', sortOrder: 52 },
      { id: 'civics-id', code: 'civics', name: '公民', sortOrder: 53 },
      { id: 'arts-id', code: 'arts', name: '藝文', sortOrder: 60 },
      { id: 'health-id', code: 'health_pe', name: '健體', sortOrder: 70 },
      { id: 'integrative-id', code: 'integrative', name: '綜合', sortOrder: 80 },
      { id: 'other-id', code: 'other', name: '其他', sortOrder: 90 },
      { id: 'chemical-id', code: 'chemical_engineering', name: '化工', sortOrder: 100 },
    ])

    expect(arranged.groupedSubjects.map((subject) => subject.code)).toEqual(['english', 'math'])
    expect(arranged.otherSubjects.map((subject) => subject.code)).toEqual([
      'chinese',
      'history',
      'geography',
      'civics',
    ])
    expect(arranged.visibleSubjects.some((subject) => subject.code === 'social')).toBe(false)
    expect(arranged.visibleSubjects.some((subject) => subject.code === 'other')).toBe(false)
    expect(arranged.visibleSubjects.some((subject) => subject.code === 'chemical_engineering')).toBe(false)
  })

  it('一般科目只建立共同提醒，英語可分共同、A、B 組', () => {
    const items = buildQuizReminderItems([
      ...subjects,
      { id: 'chemical-id', code: 'chemical_engineering', name: '化工' },
    ], {
      [quizReminderKey('chinese-id')]: 3,
      [quizReminderKey('english-id', 'A')]: 2,
      [quizReminderKey('english-id', 'B')]: 1,
      [quizReminderKey('science-id')]: 0,
      [quizReminderKey('chemical-id')]: 2,
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
        subject: { code: 'chinese', name: '國文' },
      },
      {
        id: '2',
        academicTermId: 'term-1',
        reminderDate: '2026-08-10',
        targetType: 'group',
        targetGroupCode: 'B',
        quizCount: 2,
        subject: { code: 'english', name: '英語' },
      },
      {
        id: '3',
        academicTermId: 'term-1',
        reminderDate: '2026-08-09',
        targetType: 'common',
        targetGroupCode: null,
        quizCount: 1,
        subject: { code: 'science', name: '自然' },
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

  it('全畫面看板只顯示當組需要登記的七科提醒', () => {
    const common = {
      id: 'common-chinese',
      targetType: 'common',
      quizCount: 1,
      subject: { code: 'chinese', name: '國文' },
    }
    const englishA = {
      id: 'english-a',
      targetType: 'group',
      targetGroupCode: 'A',
      quizCount: 2,
      subject: { code: 'english', name: '英語' },
    }
    const englishBZero = {
      id: 'english-b',
      targetType: 'group',
      targetGroupCode: 'B',
      quizCount: 0,
      subject: { code: 'english', name: '英語' },
    }
    const unsupported = {
      id: 'chemical',
      targetType: 'common',
      quizCount: 1,
      subject: { code: 'chemical_engineering', name: '化工' },
    }

    const groups = buildQuizReminderBoardGroups([
      common,
      englishA,
      englishBZero,
      unsupported,
    ])

    expect(groups.A.map((item) => item.id)).toEqual(['common-chinese', 'english-a'])
    expect(groups.B.map((item) => item.id)).toEqual(['common-chinese'])
  })
})
