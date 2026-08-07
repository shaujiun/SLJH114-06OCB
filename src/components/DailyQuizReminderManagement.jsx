import { useCallback, useEffect, useMemo, useState } from 'react'
import { CalendarDays, ClipboardPenLine, RefreshCw, Save } from 'lucide-react'
import {
  buildQuizReminderItems,
  loadDailyQuizReminderSettings,
  quizReminderKey,
  reminderCountsFromRows,
  saveDailyQuizReminders,
  splitQuizReminderSubjects,
} from '../services/quizReminderService.js'

function localDateString(date = new Date()) {
  const local = new Date(date.getTime() - date.getTimezoneOffset() * 60_000)
  return local.toISOString().slice(0, 10)
}

function subjectTargets(subject) {
  return ['math', 'english'].includes(subject.code)
    ? [
      { key: 'common', label: '共同' },
      { key: 'A', label: 'A 組' },
      { key: 'B', label: 'B 組' },
    ]
    : [{ key: 'common', label: '共同' }]
}

export default function DailyQuizReminderManagement({
  classId,
  academicTermId,
  classSubjects,
  helperMode = false,
}) {
  const [reminderDate, setReminderDate] = useState(localDateString())
  const [counts, setCounts] = useState({})
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [notice, setNotice] = useState(null)

  const subjectRows = useMemo(
    () => splitQuizReminderSubjects(classSubjects),
    [classSubjects],
  )

  const load = useCallback(async () => {
    if (!classId || !academicTermId || !reminderDate) return
    setLoading(true)
    try {
      const rows = await loadDailyQuizReminderSettings({
        classId,
        academicTermId,
        reminderDate,
      })
      setCounts(reminderCountsFromRows(rows))
      setNotice(null)
    } catch (error) {
      setNotice({ type: 'error', message: error.message })
    } finally {
      setLoading(false)
    }
  }, [academicTermId, classId, reminderDate])

  useEffect(() => { load() }, [load])

  function changeCount(subjectId, target, value) {
    const parsed = Math.max(0, Math.min(9, Number.parseInt(value || '0', 10) || 0))
    setCounts((current) => ({
      ...current,
      [quizReminderKey(subjectId, target)]: parsed,
    }))
  }

  async function save() {
    setSaving(true)
    setNotice(null)
    try {
      const items = buildQuizReminderItems(subjectRows.visibleSubjects, counts)
      const result = await saveDailyQuizReminders({
        classId,
        academicTermId,
        reminderDate,
        items,
      })
      await load()
      setNotice({
        type: 'success',
        message: result.savedCount
          ? result.emptyAudienceCount
            ? `已儲存 ${result.savedCount} 項提醒；其中 ${result.emptyAudienceCount} 項目前沒有符合的學生。`
            : `已儲存 ${result.savedCount} 項測驗提醒。`
          : '這一天的測驗提醒已全部清除。',
      })
    } catch (error) {
      setNotice({ type: 'error', message: error.message })
    } finally {
      setSaving(false)
    }
  }

  function renderSubject(subject) {
    const grouped = ['math', 'english'].includes(subject.code)
    return (
      <article key={subject.id} className={grouped ? 'is-grouped-subject' : 'is-common-subject'}>
        <strong>{subject.name}</strong>
        <div className="daily-quiz-target-inputs">
          {subjectTargets(subject).map((target) => (
            <label key={target.key}>
              <span>{target.label}</span>
              <input
                type="number"
                min="0"
                max="9"
                inputMode="numeric"
                aria-label={`${subject.name}${target.label}測驗次數`}
                value={counts[quizReminderKey(subject.id, target.key)] || 0}
                onChange={(event) => changeCount(
                  subject.id,
                  target.key,
                  event.target.value,
                )}
              />
              <small>次</small>
            </label>
          ))}
        </div>
      </article>
    )
  }

  return (
    <section className="daily-quiz-management">
      <div className="daily-quiz-management-heading">
        <div>
          <span><ClipboardPenLine aria-hidden="true" /></span>
          <div>
            <h3>今日成績提醒</h3>
            <p>只登記各科測驗次數，提醒學生填入學校紙本聯絡簿，不保存實際分數。</p>
          </div>
        </div>
        <label>
          <CalendarDays aria-hidden="true" />
          <span>聯絡簿日期</span>
          <input
            type="date"
            value={reminderDate}
            onChange={(event) => {
              setReminderDate(event.target.value)
              setNotice(null)
            }}
          />
        </label>
      </div>

      {notice && <div className={`admin-notice is-${notice.type}`}>{notice.message}</div>}
      {loading && <div className="daily-quiz-loading"><RefreshCw className="is-spinning" />正在讀取測驗提醒…</div>}

      {!loading && (
        <>
          <div className="daily-quiz-subject-rows">
            <div className="daily-quiz-subject-grid is-grouped-row">
              {subjectRows.groupedSubjects.map(renderSubject)}
            </div>
            <div
              className="daily-quiz-subject-grid is-other-row"
              style={{ '--quiz-other-count': Math.max(subjectRows.otherSubjects.length, 1) }}
            >
              {subjectRows.otherSubjects.map(renderSubject)}
            </div>
          </div>
          <div className="daily-quiz-save-row">
            <button
              type="button"
              className="approve-button"
              disabled={saving}
              onClick={save}
            >
              <Save aria-hidden="true" />
              {saving ? '儲存中…' : helperMode ? '儲存作業長登記' : '儲存測驗提醒'}
            </button>
          </div>
        </>
      )}
    </section>
  )
}
