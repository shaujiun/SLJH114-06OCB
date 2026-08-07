import { useEffect, useMemo } from 'react'
import { createPortal } from 'react-dom'
import { BookOpenCheck, X } from 'lucide-react'
import { buildAssignmentBoardGroups } from '../lib/assignmentBoard.js'

function AssignmentGroupColumn({ groupCode, assignments }) {
  return (
    <section className={`assignment-board-column is-${groupCode.toLowerCase()}`}>
      <header>
        <span>{groupCode}</span>
        <h2>{groupCode} 組作業區</h2>
        <small>共 {assignments.length} 項</small>
      </header>

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
    </section>
  )
}

export default function AssignmentBoard({ assignments, onClose }) {
  const groups = useMemo(() => buildAssignmentBoardGroups(assignments), [assignments])

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
        <AssignmentGroupColumn groupCode="A" assignments={groups.A} />
        <AssignmentGroupColumn groupCode="B" assignments={groups.B} />
      </div>
    </div>,
    document.body,
  )
}
