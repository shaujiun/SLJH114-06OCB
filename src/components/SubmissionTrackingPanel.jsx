import { useCallback, useEffect, useMemo, useState } from 'react'
import { AlertTriangle, CheckCircle2, History, RefreshCw, Save, X } from 'lucide-react'
import {
  isFollowUpOverdue,
  loadSubmissionTracking,
  recordSubmissionCheck,
} from '../services/adminService.js'

const reasonOptions = [
  ['incomplete', '未完成'],
  ['not_brought', '未攜帶'],
  ['late', '遲交'],
  ['leave', '請假待補'],
  ['official_leave', '公假待補'],
  ['exempt', '免繳'],
]
const reasonLabels = new Map(reasonOptions)

function formatDateTime(value) {
  if (!value) return '未記錄時間'
  return new Intl.DateTimeFormat('zh-TW', {
    year: 'numeric', month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit',
  }).format(new Date(value))
}

function eventDescription(event) {
  if (!event.fromReason) return `建立為「${reasonLabels.get(event.toReason) || event.toReason}」`
  if (event.toState === 'made_up') return '改為「已補交」'
  if (event.toState === 'waived') return '改為「免繳結案」'
  const fromLabel = reasonLabels.get(event.fromReason) || event.fromReason
  const toLabel = reasonLabels.get(event.toReason) || event.toReason
  return fromLabel === toLabel ? `維持「${toLabel}」` : `「${fromLabel}」改為「${toLabel}」`
}

function toLocalInput(value) {
  if (!value) return ''
  const date = new Date(value)
  const local = new Date(date.getTime() - date.getTimezoneOffset() * 60_000)
  return local.toISOString().slice(0, 16)
}

function defaultFollowUp(dueAt) {
  const date = new Date(dueAt)
  date.setDate(date.getDate() + 7)
  return toLocalInput(date)
}

export default function SubmissionTrackingPanel({ assignment, stage = 'teacher', onClose, onNotice }) {
  const isHelperStage = stage === 'helper'
  const [tracking, setTracking] = useState(null)
  const [forms, setForms] = useState({})
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const data = await loadSubmissionTracking({ assignmentId: assignment.id })
      setTracking(data)
      setForms(Object.fromEntries(data.students.map((student) => [student.id, {
        selected: student.exception?.workflowState === 'open',
        reason: student.exception?.reason || 'incomplete',
        followUpDueAt: toLocalInput(student.exception?.followUpDueAt),
      }])))
    } catch (error) {
      onNotice('error', error.message)
    } finally {
      setLoading(false)
    }
  }, [assignment.id, onNotice])

  useEffect(() => { load() }, [load])

  const selectedCount = useMemo(
    () => Object.values(forms).filter((item) => item.selected).length,
    [forms],
  )

  function update(studentId, changes) {
    setForms((current) => ({
      ...current,
      [studentId]: { ...current[studentId], ...changes },
    }))
  }

  async function save() {
    const exceptions = tracking.students
      .filter((student) => forms[student.id]?.selected)
      .map((student) => ({ studentId: student.id, ...forms[student.id] }))
    const missingFollowUp = exceptions.some((item) => (
      ['leave', 'official_leave'].includes(item.reason) && !item.followUpDueAt
    ))
    if (missingFollowUp) {
      onNotice('error', '請假或公假學生必須設定下一次繳交期限。')
      return
    }
    const invalidFollowUp = exceptions.some((item) => {
      if (!['leave', 'official_leave'].includes(item.reason) || !item.followUpDueAt) return false
      const student = tracking.students.find((candidate) => candidate.id === item.studentId)
      const lockedExisting = isHelperStage && student?.exception?.workflowState === 'open'
      return !lockedExisting && new Date(item.followUpDueAt).getTime() <= Date.now()
    })
    if (invalidFollowUp) {
      onNotice('error', '追繳期限已到的請假或公假，請改登記為未完成、未攜帶或遲交；若期限有誤，也可改成未來的正確期限。')
      return
    }

    setSaving(true)
    try {
      const result = await recordSubmissionCheck({ assignmentId: assignment.id, stage, exceptions })
      await load()
      onNotice(
        'success',
        result.openExceptionCount
          ? `${isHelperStage ? '第一階段已保存，' : '已保存，'}尚有 ${result.openExceptionCount} 位學生待處理。`
          : isHelperStage ? '第一階段已登記全班繳交完成。' : '已登記全班繳交完成。',
      )
    } catch (error) {
      onNotice('error', error.message)
    } finally {
      setSaving(false)
    }
  }

  return (
    <section className="submission-tracking-panel">
      <header>
        <div><strong>{isHelperStage ? '小老師第一階段點收' : '教師繳交確認'}</strong><span>{isHelperStage ? '勾選未繳交學生並選擇原因；既有例外需由任課老師或導師修正。' : '勾選仍需處理的學生；取消既有勾選並儲存會改為已補交。'}</span></div>
        <button type="button" aria-label="關閉繳交確認" onClick={onClose}><X /></button>
      </header>
      {loading && <div className="submission-loading"><RefreshCw className="is-spinning" />讀取名單中…</div>}
      {!loading && tracking && (
        <>
          <div className="submission-check-history">
            {tracking.checks.length
              ? tracking.checks.map((check) => <span key={check.check_stage}>{check.check_stage === 'teacher' ? '教師' : '小老師'}：{check.result === 'all_submitted' ? '全班已繳' : '有例外'}</span>)
              : <span>尚未登記繳交確認</span>}
          </div>
          <div className="submission-student-list">{tracking.students.map((student) => {
            const form = forms[student.id]
            const needsFollowUp = ['leave', 'official_leave'].includes(form?.reason)
            const lockedExisting = isHelperStage && student.exception?.workflowState === 'open'
            const overdue = isFollowUpOverdue(student.exception)
            return (
              <article className={`${form?.selected ? 'is-selected' : ''}${overdue ? ' is-follow-up-overdue' : ''}`} key={student.id}>
                <label className="submission-student-toggle">
                  <input type="checkbox" checked={Boolean(form?.selected)} disabled={lockedExisting} onChange={(event) => update(student.id, { selected: event.target.checked })} />
                  <span><strong>{student.seatNumber} 號・{student.fullName}</strong><small>{student.studentId}</small></span>
                </label>
                {form?.selected ? (
                  <>
                    <select value={form.reason} disabled={lockedExisting} onChange={(event) => update(student.id, {
                      reason: event.target.value,
                      followUpDueAt: ['leave', 'official_leave'].includes(event.target.value)
                        ? form.followUpDueAt || defaultFollowUp(assignment.dueAt)
                        : '',
                    })}>{reasonOptions.map(([value, label]) => <option value={value} key={value}>{label}</option>)}</select>
                    {needsFollowUp && <input aria-label={`${student.fullName}補交期限`} type="datetime-local" disabled={lockedExisting} value={form.followUpDueAt} onChange={(event) => update(student.id, { followUpDueAt: event.target.value })} />}
                    {overdue && <div className="submission-overdue-alert"><AlertTriangle aria-hidden="true" /><span><strong>追繳期限已到</strong>{isHelperStage ? '請通知任課老師或導師處理。' : '請改為未完成、未攜帶、遲交，或修正追繳期限。'}</span></div>}
                  </>
                ) : (
                  <span className="submission-complete-status"><CheckCircle2 />{student.exception ? '已補交／本次已繳' : '已繳交'}</span>
                )}
                {student.exception && (
                  <details className="submission-status-history">
                    <summary><History aria-hidden="true" />查看修正歷程・原始原因：{reasonLabels.get(student.exception.initialReason) || student.exception.initialReason}</summary>
                    <ol>
                      {student.exception.events.length
                        ? student.exception.events.map((event) => (
                          <li key={event.id}><time>{formatDateTime(event.createdAt)}</time><span>{eventDescription(event)}</span></li>
                        ))
                        : <li><span>目前沒有可顯示的修正紀錄。</span></li>}
                    </ol>
                  </details>
                )}
              </article>
            )
          })}</div>
          <footer>
            <span>目前勾選 {selectedCount} 位例外學生</span>
            <button className="approve-button" type="button" disabled={saving} onClick={save}><Save />{saving ? '儲存中…' : selectedCount ? '儲存例外名單' : '登記全班已繳交'}</button>
          </footer>
        </>
      )}
    </section>
  )
}
