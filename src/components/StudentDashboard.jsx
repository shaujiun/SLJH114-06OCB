import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  BookOpen,
  BookOpenText,
  BarChart3,
  CalendarRange,
  CalendarDays,
  ChevronLeft,
  ChevronRight,
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
  filterAssignmentsForContactDate,
  getEligibleHelperTermIds,
  groupStudentAssignments,
  loadStudentDashboard,
} from '../services/studentService.js'
import {
  groupStudentQuizReminders,
  quizReminderDisplayText,
} from '../services/quizReminderService.js'
import { markAnnouncementRead } from '../services/announcementService.js'
import {
  announcementMonthOptions,
  announcementPreview,
  announcementsForMonth,
  paginateStudentMessages,
} from '../lib/studentAnnouncementView.js'
import StudentHelperWorkspace from './StudentHelperWorkspace.jsx'
import CalendarViewer from './CalendarViewer.jsx'
import StudentGrades from './StudentGrades.jsx'
import LearningResources from './LearningResources.jsx'

const reasonLabels = {
  incomplete: '未完成',
  not_brought: '未攜帶',
  late: '遲交',
  retest_required: '需補考',
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

function formatAnnouncementDateTime(value) {
  if (!value) return '尚未設定'
  return new Intl.DateTimeFormat('zh-TW', {
    timeZone: 'Asia/Taipei',
    month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit',
  }).format(new Date(value))
}

function formatMonthDay(value) {
  if (!value) return '未設定'
  return new Intl.DateTimeFormat('zh-TW', {
    month: 'numeric', day: 'numeric',
  }).format(new Date(value))
}

function localDateString(date = new Date()) {
  const local = new Date(date.getTime() - date.getTimezoneOffset() * 60_000)
  return local.toISOString().slice(0, 10)
}

function shiftContactDate(dateString, days) {
  const value = new Date(`${dateString}T12:00:00`)
  value.setDate(value.getDate() + days)
  return localDateString(value)
}

function contactDateLabel(dateString, today) {
  if (dateString === today) return '今天'
  const date = new Date(`${dateString}T12:00:00`)
  return `${date.getMonth() + 1}/${date.getDate()}`
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
                  {exception.workflowState === 'made_up'
                    ? exception.currentReason === 'retest_required' ? '已補考' : '已補交'
                    : reasonLabels[exception.currentReason]}
                </span>
              )}
            </div>
          )
        })}
      </div>
    </article>
  )
}

export function StudentAnnouncementCard({ announcement, reading, onRead }) {
  const preview = announcementPreview(announcement.content)
  return (
    <details className={`student-announcement-card ${announcement.readAt ? 'is-read' : 'is-unread'}`}>
      <summary className="student-announcement-summary">
        <span className="student-announcement-topline">
          <span className={`announcement-scope is-${announcement.scope}`}>{announcement.scope === 'school' ? '全校公告' : '班級公告'}</span>
          <span>{formatAnnouncementDateTime(announcement.publishedAt)}</span>
        </span>
        <strong className="student-announcement-title">{announcement.title}</strong>
        <span className="student-announcement-excerpt">{preview || '點開查看公告內容與圖片。'}</span>
        <span className="student-announcement-summary-footer">
          <span className={announcement.readAt ? 'is-read' : 'is-unread'}>{announcement.readAt ? '已閱讀' : '未讀'}</span>
          <span className="student-announcement-open-label">
            <span className="when-closed">點開看全文</span>
            <span className="when-open">收起全文</span>
            <ChevronRight aria-hidden="true" />
          </span>
        </span>
      </summary>
      <div className="student-announcement-body">
        {announcement.imageUrl && <img src={announcement.imageUrl} alt={announcement.imageAltText} loading="lazy" />}
        {announcement.imageError && <p className="private-image-error">{announcement.imageError}</p>}
        {announcement.content && <p>{announcement.content}</p>}
        {announcement.expiresAt && <small>顯示至：{formatAnnouncementDateTime(announcement.expiresAt)}</small>}
        {announcement.readAt
          ? <span className="student-announcement-read"><CheckCircle2 />已閱讀</span>
          : <button type="button" disabled={reading} onClick={() => onRead(announcement)}><Eye />{reading ? '儲存中…' : '我已閱讀'}</button>}
      </div>
    </details>
  )
}

function StudentMessagePagination({ label, page, totalPages, onPageChange }) {
  if (totalPages <= 1) return null
  return (
    <nav className="student-message-pagination" aria-label={`${label}分頁`}>
      <button type="button" disabled={page === 1} onClick={() => onPageChange(page - 1)}>上一頁</button>
      <span aria-live="polite">第 {page} 頁／共 {totalPages} 頁</span>
      <button type="button" disabled={page === totalPages} onClick={() => onPageChange(page + 1)}>下一頁</button>
    </nav>
  )
}

export default function StudentDashboard({ onExit, learningSystemUrl }) {
  const [dashboard, setDashboard] = useState(null)
  const [termId, setTermId] = useState('')
  const [loading, setLoading] = useState(true)
  const [refreshing, setRefreshing] = useState(false)
  const [readingAnnouncementId, setReadingAnnouncementId] = useState('')
  const [announcementMonth, setAnnouncementMonth] = useState('all')
  const [announcementSection, setAnnouncementSection] = useState(null)
  const [announcementPage, setAnnouncementPage] = useState(1)
  const [honorPage, setHonorPage] = useState(1)
  const [activeView, setActiveView] = useState('home')
  const [contactDate, setContactDate] = useState(localDateString())
  const [notice, setNotice] = useState(null)
  const today = localDateString()

  const load = useCallback(async ({ quiet = false } = {}) => {
    if (quiet) setRefreshing(true)
    else setLoading(true)
    try {
      const data = await loadStudentDashboard()
      setDashboard(data)
      setAnnouncementPage(1)
      setHonorPage(1)
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
    () => filterAssignmentsForContactDate(
      dashboard?.assignments,
      termId,
      contactDate,
      today,
    ),
    [contactDate, dashboard, termId, today],
  )
  const assignmentGroups = useMemo(
    () => groupStudentAssignments(assignments),
    [assignments],
  )
  const quizReminderGroups = useMemo(
    () => groupStudentQuizReminders(
      dashboard?.quizReminders,
      termId,
      contactDate,
    ),
    [contactDate, dashboard, termId],
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
      assignments: [
        ...(dashboard?.assignments || []),
        ...(dashboard?.cancelledLateAssignmentHistory || []),
      ],
      exceptions: dashboard?.exceptions || [],
      terms: dashboard?.terms || [],
      selectedTermId: termId,
    }),
    [dashboard, termId],
  )
  const availableAnnouncementMonths = useMemo(
    () => announcementMonthOptions(dashboard?.announcements),
    [dashboard?.announcements],
  )
  const visibleAnnouncements = useMemo(
    () => announcementsForMonth(dashboard?.announcements, announcementMonth),
    [dashboard?.announcements, announcementMonth],
  )
  const announcementPagination = useMemo(
    () => paginateStudentMessages(visibleAnnouncements, announcementPage),
    [visibleAnnouncements, announcementPage],
  )
  const honorPagination = useMemo(
    () => paginateStudentMessages(dashboard?.honors, honorPage),
    [dashboard?.honors, honorPage],
  )
  useEffect(() => {
    if (announcementMonth !== 'all'
      && !availableAnnouncementMonths.some((month) => month.value === announcementMonth)) {
      setAnnouncementMonth('all')
    }
  }, [announcementMonth, availableAnnouncementMonths])
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
        {activeView !== 'helper' && <nav className="student-view-tabs" aria-label="學生功能切換"><button className={activeView === 'home' ? 'is-active' : ''} type="button" onClick={() => { setActiveView('home'); setNotice(null) }}><BookOpen />聯絡簿</button><button className={activeView === 'announcements' ? 'is-active' : ''} type="button" onClick={() => { setActiveView('announcements'); setAnnouncementSection(null); setNotice(null) }}><Megaphone />公告欄</button><button className={activeView === 'calendar' ? 'is-active' : ''} type="button" onClick={() => { setActiveView('calendar'); setNotice(null) }}><CalendarRange />班級行事曆</button><button className={activeView === 'grades' ? 'is-active' : ''} type="button" onClick={() => { setActiveView('grades'); setNotice(null) }}><BarChart3 />個人成績</button><button className={activeView === 'learning' ? 'is-active' : ''} type="button" onClick={() => { setActiveView('learning'); setNotice(null) }}><BookOpenText />學習資源</button></nav>}
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
        {activeView === 'grades' && <StudentGrades studentId={dashboard.student.id} classId={dashboard.classInfo.id} />}
        {activeView === 'learning' && <LearningResources classId={dashboard.classInfo.id} />}
        {activeView === 'announcements' && <div className="student-announcement-view">
          <section className="student-home-panel student-announcement-choice" aria-label="公告欄分類">
            <h1>公告欄</h1>
            <div className="student-announcement-section-buttons">
              <button type="button" className={announcementSection === 'notices' ? 'is-active' : ''} aria-pressed={announcementSection === 'notices'} onClick={() => { setAnnouncementSection('notices'); setAnnouncementPage(1) }}><Megaphone />公告事項<span>{dashboard.announcements.filter((item) => !item.readAt).length} 則未讀</span></button>
              <button type="button" className={announcementSection === 'honors' ? 'is-active' : ''} aria-pressed={announcementSection === 'honors'} onClick={() => { setAnnouncementSection('honors'); setHonorPage(1) }}><Trophy />榮譽榜<span>{dashboard.honors.length} 則</span></button>
            </div>
            {!announcementSection && <p className="student-announcement-choice-hint">請選擇要查看的內容。</p>}
          </section>

          {announcementSection === 'notices' && <section className="student-home-panel student-announcements-panel">
            <div className="student-home-panel-heading">
              <div><span><Megaphone /></span><div><h2>公告事項</h2><p>全校與班級的最新消息</p></div></div>
              <strong>全部公告有 {dashboard.announcements.filter((item) => !item.readAt).length} 則未讀</strong>
            </div>
            {dashboard.announcements.length > 0 && <label className="student-announcement-month-filter">
              <span>選擇月份</span>
              <select value={announcementMonth} onChange={(event) => { setAnnouncementMonth(event.target.value); setAnnouncementPage(1) }}>
                <option value="all">全部月份</option>
                {availableAnnouncementMonths.map((month) => <option value={month.value} key={month.value}>{month.label}</option>)}
              </select>
            </label>}
            {!dashboard.announcements.length && <div className="student-home-empty is-small"><CheckCircle2 /><strong>目前沒有新公告</strong></div>}
            {dashboard.announcements.length > 0 && !visibleAnnouncements.length && <div className="student-home-empty is-small"><Megaphone /><strong>這個月份沒有公告</strong><span>請改選其他月份。</span></div>}
            <div className="student-announcement-list">
              {announcementPagination.items.map((announcement) => (
                <StudentAnnouncementCard
                  key={announcement.id}
                  announcement={announcement}
                  reading={readingAnnouncementId === announcement.id}
                  onRead={handleAnnouncementRead}
                />
              ))}
            </div>
            <StudentMessagePagination label="公告事項" page={announcementPagination.page} totalPages={announcementPagination.totalPages} onPageChange={setAnnouncementPage} />
          </section>}

          {announcementSection === 'honors' && <section className="student-home-panel student-honor-panel">
            <div className="student-home-panel-heading">
              <div><span><Trophy /></span><div><h2>榮譽榜</h2><p>一起為班上同學的好表現喝采</p></div></div>
              <strong>{dashboard.honors.length} 則榮譽</strong>
            </div>
            {!dashboard.honors.length && <div className="student-home-empty is-small"><Medal /><strong>目前尚無榮譽紀錄</strong></div>}
            <div className="student-honor-list">
              {honorPagination.items.map((item) => (
                <article key={item.id}>
                  <span className="student-honor-medal"><Medal /></span>
                  <div><div className="student-honor-names">{item.studentDisplayNames.map((name, index) => <strong key={item.studentIds[index]}>{name}</strong>)}</div><h3>{item.title}</h3>{item.description && <p>{item.description}</p>}<small>{item.awardedOn}</small></div>
                </article>
              ))}
            </div>
            <StudentMessagePagination label="榮譽榜" page={honorPagination.page} totalPages={honorPagination.totalPages} onPageChange={setHonorPage} />
          </section>}
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
            <div className="student-home-panel-heading student-contact-book-heading">
              <div><span><ClipboardList /></span><div><h2>{contactDate === today ? '我的作業' : `${contactDateLabel(contactDate, today)} 作業紀錄`}</h2><p>{contactDate === today ? '今天維持待辦模式，已繳交作業不顯示' : '歷史日期顯示當天完整作業，不列為新的待辦'}</p></div></div>
              <div className="student-contact-date-control">
                <button type="button" aria-label="前一天" onClick={() => setContactDate((current) => shiftContactDate(current, -1))}><ChevronLeft /></button>
                <label><CalendarDays /><span>聯絡簿日期</span><input type="date" max={today} value={contactDate} onChange={(event) => setContactDate(event.target.value || today)} /></label>
                <button type="button" aria-label="後一天" disabled={contactDate >= today} onClick={() => setContactDate((current) => shiftContactDate(current, 1))}><ChevronRight /></button>
                {contactDate !== today && <button type="button" className="student-contact-today-button" onClick={() => setContactDate(today)}>回到今天</button>}
              </div>
            </div>
            {quizReminderGroups.length > 0 && <section className="student-quiz-reminder-card">
              <div className="student-quiz-reminder-title"><ClipboardPenLine /><div><h3>{contactDate === today ? '今日測驗成績' : `${contactDateLabel(contactDate, today)} 測驗成績`}</h3><p>請將下列測驗成績填入學校紙本聯絡簿</p></div></div>
              <div className="student-quiz-reminder-groups">{quizReminderGroups.map((group) => <div key={group.key}><span className={`student-target-badge is-${group.key === 'common' ? 'common' : group.key.toLowerCase()}`}>{group.label}</span><p>{group.reminders.map((reminder) => <strong key={reminder.id}>{quizReminderDisplayText(reminder)}</strong>)}</p></div>)}</div>
            </section>}
            {!assignments.length && !quizReminderGroups.length && <div className="student-home-empty"><CheckCircle2 /><strong>{contactDate === today ? '目前沒有作業或測驗提醒' : '這一天沒有聯絡簿內容'}</strong><span>{contactDate === today ? '老師或作業長發布後會顯示在這裡。' : '可以切換其他日期繼續查詢。'}</span></div>}
            <div className="student-assignment-list">{assignmentGroups.map((group) => <AssignmentGroupCard key={group.key} group={group} exceptionsByAssignment={exceptionsByAssignment} />)}</div>
          </section>

          <section className="student-home-panel student-exceptions-panel">
            <div className="student-home-panel-heading"><div><span><UserRound /></span><div><h2>繳交提醒</h2><p>補交後保留 1 天，累積紀錄不消失</p></div></div><strong>{visibleExceptions.length} 筆</strong></div>
            {!visibleExceptions.length && <div className="student-home-empty is-small"><CheckCircle2 /><strong>目前沒有待處理項目</strong></div>}
            <div className="student-exception-list">{visibleExceptions.map((item) => {
              const assignment = dashboard.assignments.find((row) => row.id === item.assignmentId)
              return <article key={item.id}><div><span className={`student-reason is-${item.currentReason}`}>{item.workflowState === 'made_up' ? item.currentReason === 'retest_required' ? '已補考' : '已補交' : reasonLabels[item.currentReason]}</span><strong>{assignment ? `${assignment.subject.name}・${assignment.content}` : '過往作業'}</strong></div>{item.followUpDueAt && <p>補交期限：{formatDateTime(item.followUpDueAt)}</p>}</article>
            })}</div>
          </section>
        </div>
        </>}
      </main>
    </div>
  )
}
