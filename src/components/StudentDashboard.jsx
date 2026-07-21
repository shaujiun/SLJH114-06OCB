import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  BookOpen,
  CalendarRange,
  CheckCircle2,
  ClipboardPenLine,
  ClipboardList,
  ExternalLink,
  GraduationCap,
  Eye,
  LogOut,
  Megaphone,
  RefreshCw,
  Medal,
  Trophy,
  TriangleAlert,
  UserRound,
} from 'lucide-react'
import {
  buildExceptionSummary,
  buildPeriodExceptionSummaries,
  getEligibleHelperTermIds,
  groupStudentAssignments,
  loadStudentDashboard,
} from '../services/studentService.js'
import { markAnnouncementRead } from '../services/announcementService.js'
import StudentHelperWorkspace from './StudentHelperWorkspace.jsx'
import CalendarViewer from './CalendarViewer.jsx'

const reasonLabels = {
  incomplete: '未完成',
  not_brought: '未攜帶',
  late: '遲交',
  leave: '請假待補',
  official_leave: '公假待補',
  exempt: '免繳',
}

function formatDateTime(value) {
  if (!value) return '尚未設定'
  return new Intl.DateTimeFormat('zh-TW', {
    month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit',
  }).format(new Date(value))
}

function formatMonthDay(value) {
  if (!value) return '未設定'
  return new Intl.DateTimeFormat('zh-TW', {
    month: 'numeric', day: 'numeric',
  }).format(new Date(value))
}

function currentGroup(groups, term, subjectCode) {
  if (!term) return '未設定'
  const now = new Date()
  const today = new Date(now.getTime() - now.getTimezoneOffset() * 60_000).toISOString().slice(0, 10)
  const referenceDate = today < term.starts_on
    ? term.starts_on
    : today > term.ends_on ? term.ends_on : today
  return groups.find((group) => (
    group.academicTermId === term.id
    && group.subjectCode === subjectCode
    && group.effectiveFrom <= referenceDate
    && (!group.effectiveTo || group.effectiveTo >= referenceDate)
  ))?.groupCode || '未設定'
}

function AssignmentGroupCard({ group, exceptionsByAssignment }) {
  return (
    <article className="student-assignment-card student-assignment-group-card">
      <span className={`student-target-badge is-${group.key === 'common' ? 'common' : group.key.toLowerCase()}`}>
        {group.label}
      </span>
      <div className="student-assignment-group-rows">
        {group.assignments.map((assignment) => {
          const exception = exceptionsByAssignment.get(assignment.id)
          const overdue = new Date(assignment.dueAt).getTime() < Date.now()
            && exception?.workflowState === 'open'
          return (
            <div className="student-assignment-row" key={assignment.id}>
              <span className="student-subject-name">{assignment.subject.name}</span>
              <strong>{assignment.content}</strong>
              <span className={`student-assignment-deadline${overdue ? ' is-overdue' : ''}`}>期限：{formatMonthDay(assignment.dueAt)}</span>
              {exception && (
                <span className={`student-status is-${exception.workflowState}`}>
                  {exception.workflowState === 'made_up' ? '已補交' : reasonLabels[exception.currentReason]}
                </span>
              )}
            </div>
          )
        })}
      </div>
    </article>
  )
}

function StudentAnnouncementCard({ announcement, reading, onRead }) {
  return (
    <article className={`student-announcement-card ${announcement.readAt ? 'is-read' : 'is-unread'}`}>
      {announcement.imageUrl && <img src={announcement.imageUrl} alt={announcement.imageAltText} />}
      <div className="student-announcement-body">
        <div className="student-announcement-topline">
          <span className={`announcement-scope is-${announcement.scope}`}>{announcement.scope === 'school' ? '全校公告' : '班級公告'}</span>
          <span>{formatDateTime(announcement.publishedAt)}</span>
        </div>
        <h3>{announcement.title}</h3>
        {announcement.content && <p>{announcement.content}</p>}
        {announcement.expiresAt && <small>顯示至：{formatDateTime(announcement.expiresAt)}</small>}
        {announcement.readAt
          ? <span className="student-announcement-read"><CheckCircle2 />已閱讀</span>
          : <button type="button" disabled={reading} onClick={() => onRead(announcement)}><Eye />{reading ? '儲存中…' : '我已閱讀'}</button>}
      </div>
    </article>
  )
}

export default function StudentDashboard({ onExit, learningSystemUrl }) {
  const [dashboard, setDashboard] = useState(null)
  const [termId, setTermId] = useState('')
  const [loading, setLoading] = useState(true)
  const [refreshing, setRefreshing] = useState(false)
  const [readingAnnouncementId, setReadingAnnouncementId] = useState('')
  const [activeView, setActiveView] = useState('home')
  const [notice, setNotice] = useState(null)

  const load = useCallback(async ({ quiet = false } = {}) => {
    if (quiet) setRefreshing(true)
    else setLoading(true)
    try {
      const data = await loadStudentDashboard()
      setDashboard(data)
      setTermId((current) => current || data.defaultTermId)
      if (!data.helperAssignments.length) {
        setActiveView((current) => current === 'helper' ? 'home' : current)
      }
      setNotice(null)
    } catch (error) {
      setNotice({ type: 'error', message: error.message })
    } finally {
      setLoading(false)
      setRefreshing(false)
    }
  }, [])

  useEffect(() => { load() }, [load])

  const selectedTerm = useMemo(
    () => dashboard?.terms.find((term) => term.id === termId),
    [dashboard, termId],
  )
  const assignments = useMemo(
    () => dashboard?.assignments.filter((item) => item.academicTermId === termId) || [],
    [dashboard, termId],
  )
  const assignmentGroups = useMemo(
    () => groupStudentAssignments(assignments),
    [assignments],
  )
  const exceptionsByAssignment = useMemo(
    () => new Map((dashboard?.exceptions || []).map((item) => [item.assignmentId, item])),
    [dashboard],
  )
  const exceptionSummary = useMemo(
    () => buildExceptionSummary(dashboard?.exceptions || []),
    [dashboard],
  )
  const periodSummaries = useMemo(
    () => buildPeriodExceptionSummaries({
      assignments: dashboard?.assignments || [],
      exceptions: dashboard?.exceptions || [],
      terms: dashboard?.terms || [],
      selectedTermId: termId,
    }),
    [dashboard, termId],
  )
  const visibleExceptions = useMemo(
    () => exceptionSummary.visible.filter((item) => {
      const assignment = dashboard?.assignments.find((row) => row.id === item.assignmentId)
      return assignment?.academicTermId === termId
    }),
    [dashboard, exceptionSummary.visible, termId],
  )

  async function handleAnnouncementRead(announcement) {
    setReadingAnnouncementId(announcement.id)
    try {
      const readAt = await markAnnouncementRead({
        announcementId: announcement.id,
        studentId: dashboard.student.id,
      })
      setDashboard((current) => ({
        ...current,
        announcements: current.announcements.map((item) => (
          item.id === announcement.id ? { ...item, readAt } : item
        )),
      }))
      setNotice(null)
    } catch (error) {
      setNotice({ type: 'error', message: error.message })
    } finally {
      setReadingAnnouncementId('')
    }
  }

  if (loading) {
    return <main className="student-home-loading"><RefreshCw className="is-spinning" /><strong>正在整理你的聯絡簿…</strong></main>
  }

  if (!dashboard) {
    return (
      <main className="student-home-loading">
        <TriangleAlert /><strong>{notice?.message || '學生資料讀取失敗。'}</strong>
        <button className="secondary-button" type="button" onClick={() => load()}>重新讀取</button>
      </main>
    )
  }

  const mathGroup = currentGroup(dashboard.groups, selectedTerm, 'math')
  const englishGroup = currentGroup(dashboard.groups, selectedTerm, 'english')
  const hasHelperRole = getEligibleHelperTermIds(
    dashboard.helperAssignments,
    dashboard.terms,
  ).length > 0

  return (
    <div className="student-home-shell">
      <header className="student-home-header">
        <div className="student-home-brand"><span><BookOpen /></span><div><strong>八年六班</strong><small>線上聯絡簿</small></div></div>
        {activeView !== 'helper' && <nav className="student-view-tabs" aria-label="學生功能切換"><button className={activeView === 'home' ? 'is-active' : ''} type="button" onClick={() => { setActiveView('home'); setNotice(null) }}><BookOpen />聯絡簿</button><button className={activeView === 'announcements' ? 'is-active' : ''} type="button" onClick={() => { setActiveView('announcements'); setNotice(null) }}><Megaphone />公告欄</button><button className={activeView === 'calendar' ? 'is-active' : ''} type="button" onClick={() => { setActiveView('calendar'); setNotice(null) }}><CalendarRange />班級行事曆</button></nav>}
        <div className="student-home-actions">
          {hasHelperRole && activeView === 'home' && <button type="button" className="student-helper-launch" onClick={() => setActiveView('helper')}><ClipboardPenLine />幹部工作區</button>}
          <button type="button" className="student-refresh-button" aria-label="重新整理" onClick={() => load({ quiet: true })}><RefreshCw className={refreshing ? 'is-spinning' : ''} /></button>
          <button type="button" className="secondary-button" onClick={onExit}><LogOut />登出</button>
        </div>
      </header>

      <main className="student-home-main">
        {notice && <div className={`admin-notice is-${notice.type}`}>{notice.message}</div>}
        {activeView === 'helper' && hasHelperRole && <StudentHelperWorkspace dashboard={dashboard} onBack={() => setActiveView('home')} />}
        {activeView === 'calendar' && <CalendarViewer classId={dashboard.classInfo.id} audience="student" />}
        {activeView === 'announcements' && <div className="student-announcement-view">
          <section className="student-home-panel student-announcements-panel">
            <div className="student-home-panel-heading">
              <div><span><Megaphone /></span><div><h2>公告欄</h2><p>全校與班級的最新消息</p></div></div>
              <strong>{dashboard.announcements.filter((item) => !item.readAt).length} 則未讀</strong>
            </div>
            {!dashboard.announcements.length && <div className="student-home-empty is-small"><CheckCircle2 /><strong>目前沒有新公告</strong></div>}
            <div className="student-announcement-list">
              {dashboard.announcements.map((announcement) => (
                <StudentAnnouncementCard
                  key={announcement.id}
                  announcement={announcement}
                  reading={readingAnnouncementId === announcement.id}
                  onRead={handleAnnouncementRead}
                />
              ))}
            </div>
          </section>

          <section className="student-home-panel student-honor-panel">
            <div className="student-home-panel-heading">
              <div><span><Trophy /></span><div><h2>班級榮譽榜</h2><p>一起為班上同學的好表現喝采</p></div></div>
              <strong>{dashboard.honors.length} 則榮譽</strong>
            </div>
            {!dashboard.honors.length && <div className="student-home-empty is-small"><Medal /><strong>目前尚無榮譽紀錄</strong></div>}
            <div className="student-honor-list">
              {dashboard.honors.map((item) => (
                <article key={item.id}>
                  <span className="student-honor-medal"><Medal /></span>
                  <div><div className="student-honor-names">{item.studentDisplayNames.map((name, index) => <strong key={item.studentIds[index]}>{name}</strong>)}</div><h3>{item.title}</h3>{item.description && <p>{item.description}</p>}<small>{item.awardedOn}</small></div>
                </article>
              ))}
            </div>
          </section>
        </div>}
        {activeView === 'home' && <>
        <section className="student-welcome-card">
          <div className="student-welcome-copy">
            <div className="student-welcome-meta">
              <p className="eyebrow">MY CONTACT BOOK</p>
              <div className="student-welcome-groups">
                <span>數學 <strong>{mathGroup} 組</strong></span>
                <span>英語 <strong>{englishGroup} 組</strong></span>
              </div>
            </div>
            <h1>{dashboard.student.fullName}，今天也一起加油！</h1>
            <p>{dashboard.classInfo.name}・座號 {dashboard.student.seatNumber}・學號 {dashboard.student.studentId}</p>
          </div>
          <button
            type="button"
            className="student-learning-launch"
            aria-label="前往各科學習系統"
            onClick={() => {
              if (learningSystemUrl) window.location.href = learningSystemUrl
              else setNotice({ type: 'error', message: '各科學習系統網址尚未設定。' })
            }}
          >
            <GraduationCap />
            <span>前往各科<br />學習系統</span>
            <ExternalLink className="student-learning-external" />
          </button>
        </section>

        <section className="student-overview-row">
          <label className="student-term-control">
            <span>查看學期</span>
            <select value={termId} onChange={(event) => setTermId(event.target.value)}>{dashboard.terms.map((term) => <option key={term.id} value={term.id}>第 {term.semester} 學期</option>)}</select>
            {selectedTerm && <small>{selectedTerm.starts_on}～{selectedTerm.ends_on}</small>}
          </label>
          <div className="student-record-table-card">
            <strong>繳交紀錄統計</strong>
            <table aria-label="本週、本月、本學期及本學年繳交紀錄摘要">
              <thead><tr><th>期間</th><th>待處理</th><th>未完成</th><th>未攜帶</th><th>遲交</th></tr></thead>
              <tbody>{periodSummaries.map((summary) => <tr key={summary.key}><th scope="row">{summary.label}</th><td>{summary.openCount}</td><td>{summary.incompleteCount}</td><td>{summary.notBroughtCount}</td><td>{summary.lateCount}</td></tr>)}</tbody>
            </table>
          </div>
        </section>

        <div className="student-home-grid">
          <section className="student-home-panel student-assignments-panel">
            <div className="student-home-panel-heading"><div><span><ClipboardList /></span><div><h2>我的作業</h2><p>只顯示共同作業與你的分組作業</p></div></div><strong>{assignments.length} 筆</strong></div>
            {!assignments.length && <div className="student-home-empty"><CheckCircle2 /><strong>目前沒有作業</strong><span>老師發布後會顯示在這裡。</span></div>}
            <div className="student-assignment-list">{assignmentGroups.map((group) => <AssignmentGroupCard key={group.key} group={group} exceptionsByAssignment={exceptionsByAssignment} />)}</div>
          </section>

          <section className="student-home-panel student-exceptions-panel">
            <div className="student-home-panel-heading"><div><span><UserRound /></span><div><h2>繳交提醒</h2><p>補交後保留 3 天，累積紀錄不消失</p></div></div><strong>{visibleExceptions.length} 筆</strong></div>
            {!visibleExceptions.length && <div className="student-home-empty is-small"><CheckCircle2 /><strong>目前沒有待處理項目</strong></div>}
            <div className="student-exception-list">{visibleExceptions.map((item) => {
              const assignment = dashboard.assignments.find((row) => row.id === item.assignmentId)
              return <article key={item.id}><div><span className={`student-reason is-${item.currentReason}`}>{item.workflowState === 'made_up' ? '已補交' : reasonLabels[item.currentReason]}</span><strong>{assignment ? `${assignment.subject.name}・${assignment.content}` : '過往作業'}</strong></div>{item.followUpDueAt && <p>補交期限：{formatDateTime(item.followUpDueAt)}</p>}</article>
            })}</div>
          </section>
        </div>
        </>}
      </main>
    </div>
  )
}
