import { useEffect, useMemo } from 'react'
import { createPortal } from 'react-dom'
import { BookOpenCheck, ClipboardPenLine, RefreshCw, X } from 'lucide-react'
import { buildAssignmentBoardGroups } from '../lib/assignmentBoard.js'
import {
  buildQuizReminderBoardGroups,
  quizReminderDisplayText,
} from '../services/quizReminderService.js'

function QuizReminderSection({ reminders, loading, error }) {
  if (!loading && !error && reminders.length === 0) return null

  return (
    <section className={`assignment-board-score-reminders${error ? ' is-error' : ''}`}>
      <div>
        <ClipboardPenLine aria-hidden="true" />
        <h3>今日成績提醒</h3>
      </div>
      {loading && <p><RefreshCw className="is-spinning" aria-hidden="true" />讀取中…</p>}
      {!loading && error && <p>{error}</p>}
      {!loading && !error && reminders.length > 0 && (
        <ul>
          {reminders.map((reminder) => (
            <li key={reminder.id}>{quizReminderDisplayText(reminder)}</li>
          ))}
        </ul>
      )}
    </section>
  )
}

function AssignmentGroupColumn({
  groupCode,
  assignments,
  quizReminders,
  quizReminderLoading,
  quizReminderError,
}) {
  return (
    <section className={`assignment-board-column is-${groupCode.toLowerCase()}`}>
      <header>
        <span>{groupCode}</span>
        <h2>{groupCode} 組作業區</h2>
        <small>{assignments.length} 項作業</small>
      </header>

      <div className="assignment-board-column-body">
        <QuizReminderSection
          reminders={quizReminders}
          loading={quizReminderLoading}
          error={quizReminderError}
        />

        {assignments.length > 0 ? (
          <ol className="assignment-board-list">
            {assignments.map((assignment) => (
              <li key={assignment.id}>
                <span>{assignment.subject?.name || '未設定科目'}</span>
                <strong>{assignment.content}</strong>
              </li>
            ))}
          </ol>
        ) : (
          <div className="assignment-board-empty">
            <BookOpenCheck aria-hidden="true" />
            <strong>目前沒有作業</strong>
          </div>
        )}
      </div>
    </section>
  )
}

export default function AssignmentBoard({
  assignments,
  quizReminders = [],
  quizReminderLoading = false,
  quizReminderError = '',
  onClose,
}) {
  const groups = useMemo(() => buildAssignmentBoardGroups(assignments), [assignments])
  const reminderGroups = useMemo(
    () => buildQuizReminderBoardGroups(quizReminders),
    [quizReminders],
  )

  useEffect(() => {
    const previousOverflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'

    function closeWithEscape(event) {
      if (event.key === 'Escape') onClose()
    }

    window.addEventListener('keydown', closeWithEscape)
    return () => {
      document.body.style.overflow = previousOverflow
      window.removeEventListener('keydown', closeWithEscape)
    }
  }, [onClose])

  return createPortal(
    <div className="assignment-board-overlay" role="dialog" aria-modal="true" aria-labelledby="assignment-board-title">
      <header className="assignment-board-header">
        <div>
          <p>CLASS HOMEWORK BOARD</p>
          <h1 id="assignment-board-title">全班作業一覽</h1>
        </div>
        <button type="button" onClick={onClose} aria-label="關閉全畫面作業看板">
          <X aria-hidden="true" />
          <span>關閉</span>
        </button>
      </header>

      <div className="assignment-board-columns">
        <AssignmentGroupColumn
          groupCode="A"
          assignments={groups.A}
          quizReminders={reminderGroups.A}
          quizReminderLoading={quizReminderLoading}
          quizReminderError={quizReminderError}
        />
        <AssignmentGroupColumn
          groupCode="B"
          assignments={groups.B}
          quizReminders={reminderGroups.B}
          quizReminderLoading={quizReminderLoading}
          quizReminderError={quizReminderError}
        />
      </div>
    </div>,
    document.body,
  )
}
