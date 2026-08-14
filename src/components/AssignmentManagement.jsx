import { useCallback, useEffect, useMemo, useState } from 'react'
import { Ban, BookOpenCheck, CalendarClock, CalendarSearch, CheckCheck, MonitorUp, Plus, RefreshCw, RotateCcw, Send, UserRoundCheck } from 'lucide-react'
import {
  cancelAssignment,
  filterAssignmentsByDate,
  getOutstandingAssignmentDates,
  loadAssignments,
  loadOutstandingAssignmentSeats,
  publishAssignment,
  recordSubmissionCheck,
  restoreAssignment,
  sortAssignmentsByTarget,
} from '../services/adminService.js'
import { loadRecentCalendarHolidays } from '../services/calendarService.js'
import { loadDailyQuizReminderSettings } from '../services/quizReminderService.js'
import AssignmentBoard from './AssignmentBoard.jsx'
import {
  filterPreviousDayAssignmentBoardItems,
  previousSchoolDateString,
} from '../lib/assignmentBoard.js'
import DailyQuizReminderManagement from './DailyQuizReminderManagement.jsx'
import SubmissionTrackingPanel from './SubmissionTrackingPanel.jsx'

function nextDay(date) {
  if (!date) return ''
  const value = new Date(`${date}T08:00:00`)
  value.setDate(value.getDate() + 1)
  const local = new Date(value.getTime() - value.getTimezoneOffset() * 60000)
  return local.toISOString().slice(0, 16)
}

function localDateString(date = new Date()) {
  const local = new Date(date.getTime() - date.getTimezoneOffset() * 60_000)
  return local.toISOString().slice(0, 10)
}

function formatCompactDateTime(value) {
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return '未設定'
  return `${date.getMonth() + 1}/${date.getDate()} ${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`
}

function formatAssignmentDate(value) {
  if (!value) return '未選擇日期'
  const date = new Date(`${value}T00:00:00`)
  if (Number.isNaN(date.getTime())) return value
  return new Intl.DateTimeFormat('zh-TW', {
    month: 'numeric',
    day: 'numeric',
    weekday: 'short',
  }).format(date)
}

function allowedTargets(subject) {
  if (subject?.allowedTargetGroups?.length) return subject.allowedTargetGroups
  return ['math', 'english'].includes(subject?.code) ? ['common', 'A', 'B'] : ['common']
}

function firstTarget(subject) {
  const first = allowedTargets(subject)[0] || 'common'
  return first === 'common'
    ? { targetType: 'common', targetGroupCode: 'A' }
    : { targetType: 'group', targetGroupCode: first }
}

export default function AssignmentManagement({
  dashboard,
  submissionStage = 'teacher',
  hideTermPicker = false,
  allowQuizReminders = false,
  allowAssignmentBoard = false,
  allowPreviousDayBoard = false,
  filterByOutstandingDate = false,
}) {
  const isHelperMode = submissionStage === 'helper'
  const firstTerm = dashboard.terms[0]
  const firstSubject = dashboard.classSubjects[0]
  const today = localDateString()
  const [termId, setTermId] = useState(firstTerm?.id || '')
  const [form, setForm] = useState({
    classSubjectId: firstSubject?.id || '',
    assignmentDate: today,
    dueAt: nextDay(today),
    content: '', ...firstTarget(firstSubject),
  })
  const [assignments, setAssignments] = useState([])
  const [cancelledAssignments, setCancelledAssignments] = useState([])
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [submissionSavingId, setSubmissionSavingId] = useState('')
  const [cancellingId, setCancellingId] = useState('')
  const [restoringId, setRestoringId] = useState('')
  const [showCancelledAssignments, setShowCancelledAssignments] = useState(false)
  const [trackingAssignmentId, setTrackingAssignmentId] = useState('')
  const [selectedAssignmentDate, setSelectedAssignmentDate] = useState('')
  const [showAssignmentBoard, setShowAssignmentBoard] = useState(false)
  const [showPreviousDayBoard, setShowPreviousDayBoard] = useState(false)
  const [previousDayAssignments, setPreviousDayAssignments] = useState([])
  const [previousDayReferenceDate, setPreviousDayReferenceDate] = useState('')
  const [previousDayBoardLoading, setPreviousDayBoardLoading] = useState(false)
  const [previousDayBoardError, setPreviousDayBoardError] = useState('')
  const [boardQuizReminders, setBoardQuizReminders] = useState([])
  const [boardQuizReminderLoading, setBoardQuizReminderLoading] = useState(false)
  const [boardQuizReminderError, setBoardQuizReminderError] = useState('')
  const [notice, setNotice] = useState(null)

  const selectedSubject = useMemo(
    () => dashboard.classSubjects.find((subject) => subject.id === form.classSubjectId),
    [dashboard.classSubjects, form.classSubjectId],
  )
  const selectedTerm = useMemo(
    () => dashboard.terms.find((term) => term.id === termId),
    [dashboard.terms, termId],
  )
  const selectedAllowedTargets = allowedTargets(selectedSubject)
  const outstandingAssignmentDates = useMemo(
    () => getOutstandingAssignmentDates(assignments),
    [assignments],
  )
  const visibleAssignments = useMemo(
    () => filterByOutstandingDate
      ? filterAssignmentsByDate(assignments, selectedAssignmentDate)
      : assignments,
    [assignments, filterByOutstandingDate, selectedAssignmentDate],
  )

  const load = useCallback(async () => {
    if (!termId) return
    setLoading(true)
    try {
      const query = {
        academicTermId: termId,
        classSubjectIds: dashboard.classSubjects.map((subject) => subject.id),
      }
      const [rows, cancelledRows] = await Promise.all([
        loadAssignments(query),
        isHelperMode ? Promise.resolve([]) : loadAssignments({ ...query, isActive: false }),
      ])
      setAssignments(sortAssignmentsByTarget(rows.filter((assignment) => {
        const subject = dashboard.classSubjects.find((item) => item.id === assignment.classSubjectId)
        const target = assignment.targetType === 'common' ? 'common' : assignment.targetGroupCode
        return allowedTargets(subject).includes(target)
      })))
      setCancelledAssignments(cancelledRows.sort((left, right) => (
        new Date(right.cancelledAt || 0).getTime() - new Date(left.cancelledAt || 0).getTime()
      )))
    }
    catch (error) { setNotice({ type: 'error', message: error.message }) }
    finally { setLoading(false) }
  }, [dashboard.classSubjects, isHelperMode, termId])

  useEffect(() => { load() }, [load])

  useEffect(() => {
    if (!filterByOutstandingDate) return
    setSelectedAssignmentDate((current) => (
      outstandingAssignmentDates.includes(current) ? current : outstandingAssignmentDates[0] || ''
    ))
  }, [filterByOutstandingDate, outstandingAssignmentDates])

  function changeTerm(nextTermId) {
    setTermId(nextTermId)
    setNotice(null)
  }

  function changeAssignmentDate(assignmentDate) {
    setForm((current) => ({
      ...current,
      assignmentDate,
      dueAt: nextDay(assignmentDate),
    }))
  }

  async function submit(event) {
    event.preventDefault()
    if (!form.content.trim()) {
      setNotice({ type: 'error', message: '請輸入作業內容。' })
      return
    }
    if (!form.dueAt || new Date(form.dueAt) < new Date(`${form.assignmentDate}T00:00:00`)) {
      setNotice({ type: 'error', message: '繳交期限不得早於作業日期。' })
      return
    }
    setSaving(true)
    setNotice(null)
    try {
      const result = await publishAssignment({ ...form, academicTermId: termId })
      setForm((current) => ({ ...current, content: '' }))
      await load()
      setNotice({ type: 'success', message: `作業已發布給 ${result.recipientCount} 位學生。` })
    } catch (error) { setNotice({ type: 'error', message: error.message }) }
    finally { setSaving(false) }
  }

  async function markAllSubmitted(assignment) {
    if (!window.confirm(`確定「${assignment.subject?.name}・${assignment.content}」全班都已繳交嗎？`)) return
    setSubmissionSavingId(assignment.id)
    setNotice(null)
    try {
      await recordSubmissionCheck({ assignmentId: assignment.id, stage: submissionStage, exceptions: [] })
      await load()
      setNotice({
        type: 'success',
        message: isHelperMode ? '第一階段已登記全班繳交完成。' : '已登記全班繳交完成。',
      })
    } catch (error) {
      setNotice({ type: 'error', message: error.message })
    } finally {
      setSubmissionSavingId('')
    }
  }

  async function cancelPublishedAssignment(assignment) {
    const label = `${assignment.subject?.name}・${assignment.content}`
    if (!window.confirm(`確定要取消「${label}」嗎？取消後學生端不再顯示，尚未結束的缺交紀錄也不再計數。`)) return
    setCancellingId(assignment.id)
    setNotice(null)
    try {
      await cancelAssignment({ assignmentId: assignment.id })
      if (trackingAssignmentId === assignment.id) setTrackingAssignmentId('')
      await load()
      setNotice({ type: 'success', message: `作業「${label}」已取消。` })
    } catch (error) {
      setNotice({ type: 'error', message: error.message })
    } finally {
      setCancellingId('')
    }
  }

  async function restoreCancelledAssignment(assignment) {
    const label = `${assignment.subject?.name}・${assignment.content}`
    if (!window.confirm(`確定要恢復「${label}」嗎？學生端會重新顯示這項作業；取消前已成立的遲交紀錄會繼續保留。`)) return
    setRestoringId(assignment.id)
    setNotice(null)
    try {
      await restoreAssignment({ assignmentId: assignment.id })
      await load()
      setNotice({ type: 'success', message: `作業「${label}」已恢復。` })
    } catch (error) {
      setNotice({ type: 'error', message: error.message })
    } finally {
      setRestoringId('')
    }
  }

  async function openAssignmentBoard() {
    setShowAssignmentBoard(true)
    setBoardQuizReminders([])
    setBoardQuizReminderError('')
    setBoardQuizReminderLoading(true)
    try {
      const rows = await loadDailyQuizReminderSettings({
        classId: dashboard.classInfo.id,
        academicTermId: termId,
        reminderDate: localDateString(),
      })
      setBoardQuizReminders(rows)
    } catch (error) {
      setBoardQuizReminderError(error.message)
    } finally {
      setBoardQuizReminderLoading(false)
    }
  }

  async function openPreviousDayBoard() {
    let referenceDate = previousSchoolDateString()
    let warningMessage = ''
    const initialCandidates = filterPreviousDayAssignmentBoardItems(assignments, referenceDate)
    setShowPreviousDayBoard(true)
    setPreviousDayReferenceDate(referenceDate)
    setPreviousDayAssignments(initialCandidates.map((assignment) => ({
      ...assignment,
      outstandingSeatNumbers: [],
    })))
    setPreviousDayBoardError('')
    setPreviousDayBoardLoading(true)
    try {
      const holidays = await loadRecentCalendarHolidays({
        classId: dashboard.classInfo.id,
        beforeDate: localDateString(),
      })
      referenceDate = previousSchoolDateString(new Date(), holidays)
    } catch (error) {
      warningMessage = `${error.message} 已先依週末規則顯示作業。`
    }

    const candidates = filterPreviousDayAssignmentBoardItems(assignments, referenceDate)
    setPreviousDayReferenceDate(referenceDate)
    setPreviousDayAssignments(candidates.map((assignment) => ({
      ...assignment,
      outstandingSeatNumbers: [],
    })))
    setPreviousDayBoardLoading(false)
    setPreviousDayBoardError(warningMessage)

    try {
      const seatsByAssignment = await loadOutstandingAssignmentSeats({
        assignmentIds: candidates.map((assignment) => assignment.id),
      })
      setPreviousDayAssignments(candidates.map((assignment) => ({
        ...assignment,
        outstandingSeatNumbers: seatsByAssignment[assignment.id] || [],
      })))
    } catch (error) {
      setPreviousDayBoardError([
        warningMessage,
        `${error.message} 作業內容仍會正常顯示。`,
      ].filter(Boolean).join(' '))
    }
  }

  return (
    <section className="assignment-management">
      <div className="student-page-heading">
        <div><p className="eyebrow">{isHelperMode ? 'CLASS HELPER' : 'ASSIGNMENTS'}</p><h2>{isHelperMode ? '幹部作業登記' : '作業管理'}</h2><p>{isHelperMode ? '只能操作導師指派的科目，第一階段登記會立即生效。' : '共同、A 組與 B 組作業會依發布當下的學生分組保存對象。'}</p></div>
        {(allowAssignmentBoard || allowPreviousDayBoard || !hideTermPicker) && <div className="assignment-heading-actions">
          {allowAssignmentBoard && <button className="assignment-board-launch" type="button" onClick={openAssignmentBoard}><MonitorUp aria-hidden="true" />全畫面顯示作業</button>}
          {allowPreviousDayBoard && <button className="assignment-board-launch is-previous-day" type="button" onClick={openPreviousDayBoard}><CalendarSearch aria-hidden="true" />前一日聯絡簿</button>}
          {!hideTermPicker && <label className="term-picker"><span>查看學期</span><select value={termId} onChange={(event) => changeTerm(event.target.value)}>{dashboard.terms.map((term) => <option value={term.id} key={term.id}>第 {term.semester} 學期</option>)}</select></label>}
        </div>}
      </div>
      {notice && <div className={`admin-notice is-${notice.type}`}>{notice.message}</div>}
      {allowQuizReminders && termId && (
        <DailyQuizReminderManagement
          classId={dashboard.classInfo.id}
          academicTermId={termId}
          classSubjects={dashboard.classSubjects}
          helperMode={isHelperMode}
        />
      )}
      <div className="assignment-layout-grid">
        <form className="assignment-create-panel" onSubmit={submit}>
          <div className="student-panel-title"><span><Plus aria-hidden="true" /></span><div><h3>發布新作業</h3><p>{isHelperMode ? '使用學生幹部權限，不會開放教師設定' : '不需要上傳照片或附件'}</p></div></div>
          <label><span>科目</span><select required value={form.classSubjectId} onChange={(event) => { const subject = dashboard.classSubjects.find((item) => item.id === event.target.value); setForm({ ...form, classSubjectId: event.target.value, ...firstTarget(subject) }) }}>{dashboard.classSubjects.map((subject) => <option value={subject.id} key={subject.id}>{subject.name}</option>)}</select></label>
          <div className="student-form-grid"><label><span>作業日期</span><input required type="date" value={form.assignmentDate} onChange={(event) => changeAssignmentDate(event.target.value)} /></label><label><span>繳交期限</span><input required type="datetime-local" min={form.assignmentDate ? `${form.assignmentDate}T00:00` : undefined} value={form.dueAt} onChange={(event) => setForm({ ...form, dueAt: event.target.value })} /></label></div>
          {selectedTerm && <p className="assignment-term-hint">此作業歸類至第 {selectedTerm.semester} 學期；日期可設定在學期間外或跨越學期。</p>}
          <label><span>作業內容</span><textarea required maxLength="1000" value={form.content} onChange={(event) => setForm({ ...form, content: event.target.value })} placeholder="例如：完成習作第 12～13 頁" /></label>
          <fieldset className="assignment-targets"><legend>適用對象</legend><div>{selectedAllowedTargets.includes('common') && <button className={form.targetType === 'common' ? 'is-active' : ''} type="button" onClick={() => setForm({ ...form, targetType: 'common' })}>共同作業</button>}{selectedAllowedTargets.includes('A') && <button className={form.targetType === 'group' && form.targetGroupCode === 'A' ? 'is-active is-a' : ''} type="button" onClick={() => setForm({ ...form, targetType: 'group', targetGroupCode: 'A' })}>A 組</button>}{selectedAllowedTargets.includes('B') && <button className={form.targetType === 'group' && form.targetGroupCode === 'B' ? 'is-active is-b' : ''} type="button" onClick={() => setForm({ ...form, targetType: 'group', targetGroupCode: 'B' })}>B 組</button>}</div></fieldset>
          <button className="approve-button" type="submit" disabled={saving}><Send aria-hidden="true" />{saving ? '發布中…' : '發布作業'}</button>
        </form>
        <section className="assignment-list-panel">
          <div className="student-list-heading"><div><span><BookOpenCheck aria-hidden="true" /></span><div><h3>已發布作業</h3><p>{filterByOutstandingDate ? selectedAssignmentDate ? `${formatAssignmentDate(selectedAssignmentDate)}・共 ${visibleAssignments.length} 筆` : '目前沒有待處理日期' : `共 ${assignments.length} 筆`}</p></div></div><button type="button" onClick={load}><RefreshCw aria-hidden="true" /></button></div>
          {loading && <div className="student-list-empty"><RefreshCw className="is-spinning" />讀取中…</div>}
          {!loading && !assignments.length && <div className="student-list-empty"><BookOpenCheck /><strong>尚未發布作業</strong><span>建立後會依共同或分組顯示。</span></div>}
          {!loading && filterByOutstandingDate && Boolean(assignments.length) && Boolean(outstandingAssignmentDates.length) && <label className="assignment-date-picker"><span>選擇發布日期</span><select value={selectedAssignmentDate} onChange={(event) => { setSelectedAssignmentDate(event.target.value); setTrackingAssignmentId('') }}>{outstandingAssignmentDates.map((date) => <option value={date} key={date}>{formatAssignmentDate(date)}</option>)}</select><small>只保留仍有學生未繳交的發布日期</small></label>}
          {!loading && filterByOutstandingDate && Boolean(assignments.length) && !outstandingAssignmentDates.length && <div className="student-list-empty"><CheckCheck /><strong>目前所有作業皆已繳交</strong><span>有未繳交作業的日期才會出現在選單。</span></div>}
          <div className="assignment-items">{visibleAssignments.map((item) => <article key={item.id}>
            <div className="assignment-item-summary">
              <div className="assignment-item-copy"><span className={`assignment-audience is-${item.targetType === 'common' ? 'common' : item.targetGroupCode.toLowerCase()}`}>{item.targetType === 'common' ? '共同' : `${item.targetGroupCode} 組`}</span><strong>{item.subject?.name}・{item.content}</strong></div>
              <div className="assignment-item-meta"><span><CalendarClock />期限：{formatCompactDateTime(item.dueAt)}</span><small>發布者：{item.publisher}・{item.recipientCount} 人</small></div>
            </div>
            <div className="assignment-submission-actions"><button type="button" disabled={submissionSavingId === item.id} onClick={() => markAllSubmitted(item)}><CheckCheck />{submissionSavingId === item.id ? '登記中…' : '全班已繳交'}</button><button type="button" onClick={() => setTrackingAssignmentId((current) => current === item.id ? '' : item.id)}><UserRoundCheck />登記例外學生</button>{!isHelperMode && <button className="assignment-cancel-button" type="button" disabled={cancellingId === item.id} onClick={() => cancelPublishedAssignment(item)}><Ban />{cancellingId === item.id ? '取消中…' : '取消作業'}</button>}</div>
            {trackingAssignmentId === item.id && <SubmissionTrackingPanel assignment={item} stage={submissionStage} onClose={() => setTrackingAssignmentId('')} onNotice={(type, message) => setNotice({ type, message })} onSaved={load} />}
          </article>)}</div>
          {!isHelperMode && <section className="cancelled-assignment-panel">
            <button className="cancelled-assignment-toggle" type="button" onClick={() => setShowCancelledAssignments((current) => !current)} aria-expanded={showCancelledAssignments}>
              <RotateCcw aria-hidden="true" />
              <span>{showCancelledAssignments ? '收合已取消作業' : '查看已取消作業'}</span>
              <strong>{cancelledAssignments.length} 筆</strong>
            </button>
            {showCancelledAssignments && <div className="cancelled-assignment-list">
              {!cancelledAssignments.length && <div className="student-list-empty"><CheckCheck /><strong>目前沒有已取消作業</strong></div>}
              {cancelledAssignments.map((item) => <article key={item.id}>
                <div className="assignment-item-summary">
                  <div className="assignment-item-copy"><span className="assignment-audience is-cancelled">已取消</span><strong>{item.subject?.name}・{item.content}</strong></div>
                  <div className="assignment-item-meta"><span><CalendarClock />期限：{formatCompactDateTime(item.dueAt)}</span><small>原發布者：{item.publisher}・{item.recipientCount} 人</small></div>
                </div>
                <div className="assignment-submission-actions"><button className="assignment-restore-button" type="button" disabled={restoringId === item.id} onClick={() => restoreCancelledAssignment(item)}><RotateCcw />{restoringId === item.id ? '恢復中…' : '恢復作業'}</button></div>
              </article>)}
            </div>}
          </section>}
        </section>
      </div>
      {showAssignmentBoard && <AssignmentBoard
        assignments={assignments}
        quizReminders={boardQuizReminders}
        quizReminderLoading={boardQuizReminderLoading}
        quizReminderError={boardQuizReminderError}
        onClose={() => setShowAssignmentBoard(false)}
      />}
      {showPreviousDayBoard && <AssignmentBoard
        assignments={previousDayAssignments}
        mode="previous-day"
        referenceDate={previousDayReferenceDate}
        loading={previousDayBoardLoading}
        error={previousDayBoardError}
        onClose={() => setShowPreviousDayBoard(false)}
      />}
    </section>
  )
}
