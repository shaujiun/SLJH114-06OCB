import { requireSupabase } from '../lib/supabase.js'

function relation(value) {
  return Array.isArray(value) ? value[0] : value
}

function normalizeCount(value) {
  const number = Number(value)
  return Number.isInteger(number) && number >= 1 && number <= 9 ? number : 0
}

const QUIZ_REMINDER_SUBJECT_ORDER = [
  'chinese',
  'english',
  'math',
  'science',
  'history',
  'geography',
  'civics',
]

const QUIZ_REMINDER_SUBJECT_CODES = new Set(QUIZ_REMINDER_SUBJECT_ORDER)

export function isQuizReminderSubjectCode(subjectCode) {
  return QUIZ_REMINDER_SUBJECT_CODES.has(subjectCode)
}

export function quizReminderKey(classSubjectId, target = 'common') {
  return `${classSubjectId}|${target}`
}

export function splitQuizReminderSubjects(classSubjects) {
  const sorted = [...(classSubjects || [])]
    .filter((subject) => isQuizReminderSubjectCode(subject.code))
    .sort((left, right) => (
      QUIZ_REMINDER_SUBJECT_ORDER.indexOf(left.code)
      - QUIZ_REMINDER_SUBJECT_ORDER.indexOf(right.code)
    ))
  const groupedOrder = { english: 0, math: 1 }
  const groupedSubjects = sorted
    .filter((subject) => ['english', 'math'].includes(subject.code))
    .sort((left, right) => groupedOrder[left.code] - groupedOrder[right.code])
  const otherSubjects = sorted.filter((subject) => (
    !['english', 'math'].includes(subject.code)
  ))

  return {
    groupedSubjects,
    otherSubjects,
    visibleSubjects: [...groupedSubjects, ...otherSubjects],
  }
}

export function buildQuizReminderItems(classSubjects, counts) {
  const items = []
  for (const subject of classSubjects || []) {
    if (!isQuizReminderSubjectCode(subject.code)) continue
    const targets = ['math', 'english'].includes(subject.code)
      ? ['common', 'A', 'B']
      : ['common']
    for (const target of targets) {
      const quizCount = normalizeCount(counts?.[quizReminderKey(subject.id, target)])
      if (!quizCount) continue
      items.push({
        classSubjectId: subject.id,
        targetType: target === 'common' ? 'common' : 'group',
        targetGroupCode: target === 'common' ? null : target,
        quizCount,
      })
    }
  }
  return items
}

export function mapQuizReminderRow(row) {
  const classSubject = relation(row.class_subjects)
  const subject = relation(classSubject?.subjects)
  return {
    id: row.id,
    academicTermId: row.academic_term_id,
    classSubjectId: row.class_subject_id,
    reminderDate: row.reminder_date,
    targetType: row.target_type,
    targetGroupCode: row.target_group_code,
    quizCount: row.quiz_count,
    subject: {
      code: subject?.code,
      name: subject?.name,
    },
  }
}

export function reminderCountsFromRows(rows) {
  return Object.fromEntries((rows || []).map((row) => [
    quizReminderKey(
      row.classSubjectId,
      row.targetType === 'common' ? 'common' : row.targetGroupCode,
    ),
    row.quizCount,
  ]))
}

export function groupStudentQuizReminders(
  reminders,
  academicTermId,
  reminderDate,
) {
  const groups = new Map()
  for (const reminder of reminders || []) {
    if (
      !isQuizReminderSubjectCode(reminder?.subject?.code)
      || normalizeCount(reminder?.quizCount) === 0
      || reminder.academicTermId !== academicTermId
      || reminder.reminderDate !== reminderDate
    ) continue
    const key = reminder.targetType === 'common'
      ? 'common'
      : String(reminder.targetGroupCode || '').toUpperCase()
    const current = groups.get(key) || {
      key,
      label: key === 'common' ? '共同' : `${key} 組`,
      reminders: [],
    }
    current.reminders.push(reminder)
    groups.set(key, current)
  }
  const order = { common: 0, A: 1, B: 2 }
  return [...groups.values()]
    .map((group) => ({
      ...group,
      reminders: [...group.reminders].sort((left, right) => (
        String(left.subject?.name || '').localeCompare(
          String(right.subject?.name || ''),
          'zh-TW',
        )
      )),
    }))
    .sort((left, right) => (
      (order[left.key] ?? 99) - (order[right.key] ?? 99)
    ))
}

export function quizReminderDisplayText(reminder) {
  if (!reminder?.subject?.name) return ''
  return reminder.quizCount > 1
    ? `${reminder.subject.name} ×${reminder.quizCount}`
    : reminder.subject.name
}

export function quizReminderBoardDisplayText(reminder) {
  if (!reminder?.subject?.name) return ''
  const quizCount = normalizeCount(reminder.quizCount)
  return quizCount > 0 ? `${reminder.subject.name} ×${quizCount}` : ''
}

export function buildQuizReminderBoardGroups(reminders = []) {
  const visible = (Array.isArray(reminders) ? reminders : [])
    .filter((reminder) => (
      isQuizReminderSubjectCode(reminder?.subject?.code)
      && normalizeCount(reminder?.quizCount) > 0
    ))
    .sort((left, right) => (
      QUIZ_REMINDER_SUBJECT_ORDER.indexOf(left.subject.code)
      - QUIZ_REMINDER_SUBJECT_ORDER.indexOf(right.subject.code)
    ))

  function belongsToGroup(reminder, groupCode) {
    return reminder.targetType === 'common'
      || (
        reminder.targetType === 'group'
        && String(reminder.targetGroupCode || '').toUpperCase() === groupCode
      )
  }

  return {
    A: visible.filter((reminder) => belongsToGroup(reminder, 'A')),
    B: visible.filter((reminder) => belongsToGroup(reminder, 'B')),
  }
}

export async function loadDailyQuizReminderSettings({
  classId,
  academicTermId,
  reminderDate,
}) {
  const client = requireSupabase()
  const { data, error } = await client
    .from('daily_quiz_reminders')
    .select('id,academic_term_id,class_subject_id,reminder_date,target_type,target_group_code,quiz_count,class_subjects!inner(subjects!inner(code,name))')
    .eq('class_id', classId)
    .eq('academic_term_id', academicTermId)
    .eq('reminder_date', reminderDate)
    .eq('is_active', true)
  if (error) throw new Error('無法讀取今日測驗提醒，請重新整理後再試。')
  return (data || [])
    .map(mapQuizReminderRow)
    .filter((row) => isQuizReminderSubjectCode(row.subject.code))
}

export async function saveDailyQuizReminders({
  classId,
  academicTermId,
  reminderDate,
  items,
}) {
  const client = requireSupabase()
  const { data, error } = await client.rpc('save_daily_quiz_reminders', {
    p_class_id: classId,
    p_academic_term_id: academicTermId,
    p_reminder_date: reminderDate,
    p_items: (items || []).map((item) => ({
      class_subject_id: item.classSubjectId,
      target_type: item.targetType,
      target_group_code: item.targetGroupCode,
      quiz_count: item.quizCount,
    })),
  })
  if (error) {
    const databaseMessage = error.message || ''
    if (databaseMessage.includes('quiz_reminder_permission_required')) {
      throw new Error('目前帳號沒有登記每日測驗提醒的權限。')
    }
    if (databaseMessage.includes('empty_quiz_reminder_audience')) {
      throw new Error('所選分組目前沒有學生，請先確認學生分組。')
    }
    if (databaseMessage.includes('invalid_quiz_reminder_term')) {
      throw new Error('選擇的學期不屬於目前班級，請重新整理。')
    }
    if (
      databaseMessage.includes('invalid_quiz_reminder')
      || databaseMessage.includes('duplicate_quiz_reminder')
    ) {
      throw new Error('測驗次數或適用分組不正確，請檢查後再儲存。')
    }
    if (error.code === 'PGRST202') {
      throw new Error('每日測驗提醒功能正在更新，請稍後重新整理。')
    }
    throw new Error('每日測驗提醒儲存失敗，請稍後再試。')
  }
  return data
}

export async function loadStudentQuizReminders({ classId }) {
  const client = requireSupabase()
  const { data, error } = await client
    .from('daily_quiz_reminders')
    .select('id,academic_term_id,class_subject_id,reminder_date,target_type,target_group_code,quiz_count,class_subjects!inner(subjects!inner(code,name))')
    .eq('class_id', classId)
    .eq('is_active', true)
    .order('reminder_date', { ascending: false })
  if (error) throw new Error('無法讀取每日測驗提醒，請重新整理後再試。')
  return (data || [])
    .map(mapQuizReminderRow)
    .filter((row) => isQuizReminderSubjectCode(row.subject.code))
}
