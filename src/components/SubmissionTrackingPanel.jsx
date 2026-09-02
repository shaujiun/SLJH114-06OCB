import { useCallback, useEffect, useMemo, useState } from 'react'
import { AlertTriangle, CheckCircle2, History, RefreshCw, Save, X } from 'lucide-react'
import {
  isFollowUpOverdue,
  loadSubmissionTracking,
  recordIndividualAssignmentStatus,
} from '../services/adminService.js'

const statusOptions = [
  ['pending', '尚未繳交'],
  ['submitted', '已繳交'],
  ['incomplete', '未完成'],
  ['not_brought', '未攜帶'],
  ['late', '遲交'],
  ['retest_required', '需補考'],
  ['leave', '請假待補'],
  ['official_leave', '公假待補'],
  ['exempt', '免繳'],
]
const statusLabels = new Map(statusOptions)

function formatDateTime(value) {
  if (!value) return '未記錄時間'
  return new Intl.DateTimeFormat('zh-TW', {
    year: 'numeric', month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit',
  }).format(new Date(value))
}

function eventDescription(event) {
  if (event.note === 'reset_to_pending') return '改回「尚未繳交」'
  if (!event.fromReason) return `建立為「${statusLabels.get(event.toReason) || event.toReason}」`
  if (event.toState === 'made_up') return event.fromReason === 'retest_required' || event.toReason === 'retest_required'
    ? '改為「已補考」'
    : '改為「已補交」'
  if (event.toState === 'waived') return '改為「免繳結案」'
  const fromLabel = statusLabels.get(event.fromReason) || event.fromReason
  const toLabel = statusLabels.get(event.toReason) || event.toReason
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

function currentStatus(student) {
  if (student.exception?.workflowState === 'open') return student.exception.reason
  if (student.submittedAt) return 'submitted'
  return 'pending'
}

export default function SubmissionTrackingPanel({ assignment, stage = 'teacher', onClose, onNotice, onSaved }) {
  const isHelperStage = stage === 'helper'
  const [tracking, setTracking] = useState(null)
  const [forms, setForms] = useState({})
  const [loading, setLoading] = useState(true)
  const [individualSavingId, setIndividualSavingId] = useState('')

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const data = await loadSubmissionTracking({ assignmentId: assignment.id })
      setTracking(data)
      setForms(Object.fromEntries(data.students.map((student) => [student.id, {
        status: currentStatus(student),
        followUpDueAt: toLocalInput(student.exception?.followUpDueAt),
      }])))
    } catch (error) {
      onNotice('error', error.message)
    } finally {
      setLoading(false)
    }
  }, [assignment.id, onNotice])

  useEffect(() => { load() }, [load])

  const pendingCount = useMemo(
    () => Object.values(forms).filter((item) => !['submitted', 'exempt'].includes(item.status)).length,
    [forms],
  )

  function update(studentId, changes) {
    setForms((current) => ({
      ...current,
      [studentId]: { ...current[studentId], ...changes },
    }))
  }

  async function saveStudentStatus(student) {
    const form = forms[student.id]
    if (!form) return
    if (['leave', 'official_leave'].includes(form.status) && !form.followUpDueAt) {
      onNotice('error', '請假或公假學生必須設定下一次繳交期限。')
      return
    }
    if (['leave', 'official_leave'].includes(form.status) && new Date(form.followUpDueAt).getTime() <= Date.now()) {
      onNotice('error', '補交期限必須晚於現在。')
      return
    }

    setIndividualSavingId(student.id)
    try {
      const result = await recordIndividualAssignmentStatus({
        assignmentId: assignment.id,
        studentId: student.id,
        stage,
        status: form.status,
        followUpDueAt: form.followUpDueAt,
      })
      await load()
      onNotice(
        'success',
        `${student.seatNumber} 號 ${student.fullName} 已設為「${statusLabels.get(form.status)}」，其他學生狀態未變更${result.countsAsLate ? '，原有遲交紀錄已保留。' : '。'}`,
      )
      await onSaved?.(result)
    } catch (error) {
      onNotice('error', error.message)
    } finally {
      setIndividualSavingId('')
    }
  }

  return (
    <section className="submission-tracking-panel">
      <header>
        <div><strong>{isHelperStage ? '小老師個別點收' : '個別繳交狀態'}</strong><span>每位學生分開儲存；修改一人不會連動其他學生。「免繳」不列入未繳交名單。</span></div>
        <button type="button" aria-label="關閉繳交確認" onClick={onClose}><X /></button>
      </header>
      {loading && <div className="submission-loading"><RefreshCw className="is-spinning" />讀取名單中…</div>}
      {!loading && tracking && (
        <>
          <div className="submission-check-history">
            {tracking.checks.length
              ? tracking.checks.map((check) => <span key={check.check_stage}>{check.check_stage === 'teacher' ? '教師' : '小老師'}：{check.result === 'all_submitted' ? '全班已繳' : '曾登記例外'}</span>)
              : <span>尚未登記全班繳交確認</span>}
          </div>
          <div className="submission-student-list">{tracking.students.map((student) => {
            const form = forms[student.id]
            const needsFollowUp = ['leave', 'official_leave'].includes(form?.status)
            const lockedExisting = isHelperStage && student.exception?.workflowState === 'open'
            const overdue = isFollowUpOverdue(student.exception)
            const saving = individualSavingId === student.id
            return (
              <article className={`${!['submitted', 'pending'].includes(form?.status) ? 'is-selected' : ''}${overdue ? ' is-follow-up-overdue' : ''}`} key={student.id}>
                <div className="submission-student-identity">
                  <strong>{student.seatNumber} 號・{student.fullName}</strong>
                  <small>{student.studentId}</small>
                </div>
                <div className="submission-row-actions">
                  <select
                    aria-label={`${student.fullName}繳交狀態`}
                    value={form?.status || 'pending'}
                    disabled={lockedExisting || Boolean(individualSavingId)}
                    onChange={(event) => update(student.id, {
                      status: event.target.value,
                      followUpDueAt: ['leave', 'official_leave'].includes(event.target.value)
                        ? form.followUpDueAt || defaultFollowUp(assignment.dueAt)
                        : '',
                    })}
                  >{statusOptions.map(([value, label]) => <option value={value} key={value}>{label}</option>)}</select>
                  {needsFollowUp && <input aria-label={`${student.fullName}補交期限`} type="datetime-local" disabled={lockedExisting || Boolean(individualSavingId)} value={form.followUpDueAt} onChange={(event) => update(student.id, { followUpDueAt: event.target.value })} />}
                  <button
                    className="submission-individual-submit-button"
                    type="button"
                    disabled={lockedExisting || Boolean(individualSavingId)}
                    onClick={() => saveStudentStatus(student)}
                  >
                    {saving ? <RefreshCw className="is-spinning" /> : form?.status === 'submitted' ? <CheckCircle2 /> : <Save />}
                    {saving ? '儲存中…' : '儲存此生狀態'}
                  </button>
                </div>
                {lockedExisting && <div className="submission-locked-hint">已有紀錄，請由任課老師或導師修改。</div>}
                {overdue && <div className="submission-overdue-alert"><AlertTriangle aria-hidden="true" /><span><strong>追繳期限已到</strong>{isHelperStage ? '請通知任課老師或導師處理。' : '請改為未完成、未攜帶、遲交，或修正追繳期限。'}</span></div>}
                {student.exception && (
                  <details className="submission-status-history">
                    <summary><History aria-hidden="true" />查看修正歷程・原始原因：{statusLabels.get(student.exception.initialReason) || student.exception.initialReason}</summary>
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
            <span>目前尚有 {pendingCount} 位學生未完成；需全班結案時，請使用作業上方的「全班已繳交」。</span>
          </footer>
        </>
      )}
    </section>
  )
}
