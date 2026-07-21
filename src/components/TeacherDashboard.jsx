import { useCallback, useEffect, useState } from 'react'
import {
  BookOpen,
  CalendarRange,
  ClipboardList,
  GraduationCap,
  LogOut,
  RefreshCw,
  ShieldCheck,
} from 'lucide-react'
import { loadTeacherDashboard } from '../services/teacherService.js'
import AssignmentManagement from './AssignmentManagement.jsx'
import CalendarViewer from './CalendarViewer.jsx'

export default function TeacherDashboard({ user, onExit }) {
  const [dashboard, setDashboard] = useState(null)
  const [loading, setLoading] = useState(true)
  const [refreshing, setRefreshing] = useState(false)
  const [notice, setNotice] = useState(null)
  const [activeSection, setActiveSection] = useState('assignments')

  const load = useCallback(async ({ quiet = false } = {}) => {
    if (quiet) setRefreshing(true)
    else setLoading(true)
    try {
      setDashboard(await loadTeacherDashboard())
      setNotice(null)
    } catch (error) {
      setNotice({ type: 'error', message: error.message })
    } finally {
      setLoading(false)
      setRefreshing(false)
    }
  }, [])

  useEffect(() => { load() }, [load])

  return (
    <div className="admin-shell teacher-workspace-shell">
      <aside className="admin-sidebar teacher-workspace-sidebar">
        <div className="admin-brand">
          <span><BookOpen aria-hidden="true" /></span>
          <div><strong>八年六班</strong><small>教師工作台</small></div>
        </div>
        <nav aria-label="教師功能">
          <button className={activeSection === 'assignments' ? 'is-active' : ''} type="button" onClick={() => { setActiveSection('assignments'); setNotice(null) }}><ClipboardList aria-hidden="true" />作業與繳交</button>
          <button className={activeSection === 'calendar' ? 'is-active' : ''} type="button" onClick={() => { setActiveSection('calendar'); setNotice(null) }}><CalendarRange aria-hidden="true" />班級行事曆</button>
        </nav>
        <div className="admin-sidebar-foot">
          <ShieldCheck aria-hidden="true" />
          <span><strong>任課老師模式</strong><small>僅能操作獲授權科目</small></span>
        </div>
      </aside>

      <main className="admin-main">
        <header className="admin-topbar teacher-workspace-topbar">
          <div>
            <p className="eyebrow">TEACHER WORKSPACE</p>
            <h1>{user.displayName}老師，您好</h1>
            <p>{activeSection === 'calendar' ? '查看班級、學校、考試及放假行程。' : '發布任教科目作業，並登記全班繳交或例外學生。'}</p>
            {dashboard && (
              <div className="teacher-workspace-subjects" aria-label="可管理科目">
                <GraduationCap aria-hidden="true" />
                {dashboard.classSubjects.map((subject) => <span key={subject.id}>{subject.name}</span>)}
              </div>
            )}
          </div>
          <div className="admin-topbar-actions">
            <button className="admin-icon-button" type="button" aria-label="重新整理教師工作台" disabled={refreshing} onClick={() => load({ quiet: true })}>
              <RefreshCw className={refreshing ? 'is-spinning' : ''} aria-hidden="true" />
            </button>
            <button className="secondary-button" type="button" onClick={onExit}><LogOut aria-hidden="true" />登出</button>
          </div>
        </header>

        {notice && <div className={`admin-notice is-${notice.type}`}>{notice.message}</div>}
        {loading && <div className="admin-loading"><RefreshCw className="is-spinning" aria-hidden="true" />正在讀取任教資料…</div>}
        {!loading && dashboard && activeSection === 'assignments' && <AssignmentManagement dashboard={dashboard} />}
        {!loading && dashboard && activeSection === 'calendar' && <CalendarViewer classId={dashboard.classInfo.id} audience="teacher" />}
      </main>
    </div>
  )
}
