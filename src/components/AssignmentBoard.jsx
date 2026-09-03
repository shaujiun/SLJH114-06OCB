import { useEffect, useMemo } from 'react'
import { createPortal } from 'react-dom'
import { BookOpenCheck, ClipboardPenLine, RefreshCw, X } from 'lucide-react'
import {
  buildAssignmentBoardGroups,
  filterCurrentAssignmentBoardItems,
  filterPreviousDayAssignmentBoardItems,
  isUnreviewedPreviousDayCarryover,
} from '../lib/assignmentBoard.js'
import {
  buildQuizReminderBoardGroups,
  quizReminderBoardDisplayText,
} from '../services/quizReminderService.js'

function QuizReminderSection({ reminders, loading, error, title = '今日成績提醒' }) {
  if (!loading && !error && reminders.length === 0) return null

  return (
    <section className={`assignment-board-score-reminders${error ? ' is-error' : ''}`}>
      <div>
        <ClipboardPenLine aria-hidden="true" />
        <h3>{title}</h3>
      </div>
      {loading && <p><RefreshCw className="is-spinning" aria-hidden="true" />讀取中…</p>}
      {!loading && error && <p>{error}</p>}
      {!loading && !error && reminders.length > 0 && (
        <ul>
          {reminders.map((reminder) => (
            <li key={reminder.id}>{quizReminderBoardDisplayText(reminder)}</li>
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
  quizReminderTitle,
  mode,
  referenceDate,
  loading,
  error,
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
          title={quizReminderTitle}
        />

        {error && <div className="assignment-board-warning"><strong>{error}</strong></div>}
        {loading ? (
          <div className="assignment-board-empty"><RefreshCw className="is-spinning" aria-hidden="true" /><strong>讀取待完成座號…</strong></div>
        ) : assignments.length > 0 ? (
          <ol className="assignment-board-list">
            {assignments.map((assignment) => (
              <li key={assignment.id}>
                <span>{assignment.subject?.name || '未設定科目'}</span>
                <div className="assignment-board-item-copy">
                  <strong>{assignment.content}</strong>
                  {assignment.targetType === 'individual' && assignment.recipientStudents?.length > 0 && <small>個別指定：{assignment.recipientStudents.map((student) => student.seatNumber).join('、')} 號</small>}
                  {assignment.outstandingSeatNumbers?.length > 0 && <small>缺交名單：{assignment.outstandingSeatNumbers.join('、')} 號</small>}
                  {mode === 'previous-day' && isUnreviewedPreviousDayCarryover(assignment, referenceDate) && <small>尚未檢查繳交狀況</small>}
                </div>
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
  mode = 'current',
  referenceDate = '',
  loading = false,
  error = '',
  onClose,
}) {
  const groups = useMemo(
    () => {
      const filtered = mode === 'previous-day'
        ? filterPreviousDayAssignmentBoardItems(assignments, referenceDate)
        : filterCurrentAssignmentBoardItems(assignments)
      return buildAssignmentBoardGroups(filtered)
    },
    [assignments, mode, referenceDate],
  )
  const reminderGroups = useMemo(
    () => buildQuizReminderBoardGroups(quizReminders),
    [quizReminders],
  )
  const isPreviousDay = mode === 'previous-day'
  const referenceLabel = referenceDate
    ? new Intl.DateTimeFormat('zh-TW', { month: 'numeric', day: 'numeric', weekday: 'short' })
      .format(new Date(`${referenceDate}T12:00:00`))
    : '前一日'

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
          <p>{isPreviousDay ? 'PREVIOUS CONTACT BOOK' : 'CLASS HOMEWORK BOARD'}</p>
          <h1 id="assignment-board-title">{isPreviousDay ? `${referenceLabel} 聯絡簿作業` : '全班作業一覽'}</h1>
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
          quizReminderTitle={isPreviousDay ? '成績填寫項目' : '今日成績提醒'}
          mode={mode}
          referenceDate={referenceDate}
          loading={loading}
          error={error}
        />
        <AssignmentGroupColumn
          groupCode="B"
          assignments={groups.B}
          quizReminders={reminderGroups.B}
          quizReminderLoading={quizReminderLoading}
          quizReminderError={quizReminderError}
          quizReminderTitle={isPreviousDay ? '成績填寫項目' : '今日成績提醒'}
          mode={mode}
          referenceDate={referenceDate}
          loading={loading}
          error={error}
        />
      </div>
    </div>,
    document.body,
  )
}
