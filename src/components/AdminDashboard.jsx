import { useCallback, useEffect, useState } from 'react'
import {
  ArrowDown,
  ArrowUp,
  BookOpen,
  CalendarDays,
  CalendarRange,
  Check,
  ClipboardList,
  GraduationCap,
  Eye,
  EyeOff,
  LayoutDashboard,
  LogOut,
  Megaphone,
  Plus,
  RefreshCw,
  Save,
  School,
  ShieldCheck,
  Trophy,
  UserCheck,
  UserCog,
  Users,
} from 'lucide-react'
import { addClassSubject, approveTeacher, loadAdminDashboard, updateClassSubjects } from '../services/adminService.js'
import StudentManagement from './StudentManagement.jsx'
import AssignmentManagement from './AssignmentManagement.jsx'
import AnnouncementManagement from './AnnouncementManagement.jsx'
import HonorManagement from './HonorManagement.jsx'
import TeacherManagement from './TeacherManagement.jsx'
import CalendarManagement from './CalendarManagement.jsx'

function formatDate(value) {
  if (!value) return '尚未設定'
  return new Intl.DateTimeFormat('zh-TW', {
    year: 'numeric',
    month: 'numeric',
    day: 'numeric',
  }).format(new Date(`${value}T00:00:00`))
}

function SummaryCard({ icon: Icon, label, value, tone }) {
  return (
    <article className={`admin-summary-card ${tone}`}>
      <span className="admin-summary-icon"><Icon aria-hidden="true" /></span>
      <span>{label}</span>
      <strong>{value}</strong>
    </article>
  )
}

function EmptyTeachers() {
  return (
    <div className="admin-empty-state">
      <span><UserCheck aria-hidden="true" /></span>
      <div>
        <strong>目前沒有待核准教師</strong>
        <p>任課老師送出註冊申請後，會出現在這裡供您選擇任教科目。</p>
      </div>
    </div>
  )
}

export default function AdminDashboard({ user, onExit }) {
  const [activeSection, setActiveSection] = useState('dashboard')
  const [dashboard, setDashboard] = useState(null)
  const [selectedSubjects, setSelectedSubjects] = useState({})
  const [loading, setLoading] = useState(true)
  const [refreshing, setRefreshing] = useState(false)
  const [approvingId, setApprovingId] = useState('')
  const [newSubjectName, setNewSubjectName] = useState('')
  const [addingSubject, setAddingSubject] = useState(false)
  const [subjectSettings, setSubjectSettings] = useState([])
  const [savingSubjects, setSavingSubjects] = useState(false)
  const [notice, setNotice] = useState(null)
  const handleSectionNotice = useCallback((type, message) => setNotice({ type, message }), [])

  const load = useCallback(async ({ quiet = false } = {}) => {
    if (quiet) setRefreshing(true)
    else setLoading(true)
    try {
      const data = await loadAdminDashboard()
      setDashboard(data)
      setSubjectSettings(data.allClassSubjects)
      setNotice(null)
    } catch (error) {
      setNotice({ type: 'error', message: error.message })
    } finally {
      setLoading(false)
      setRefreshing(false)
    }
  }, [])

  useEffect(() => {
    load()
  }, [load])

  function toggleSubject(teacherId, subjectId) {
    setSelectedSubjects((current) => {
      const selected = new Set(current[teacherId] || [])
      if (selected.has(subjectId)) selected.delete(subjectId)
      else selected.add(subjectId)
      return { ...current, [teacherId]: [...selected] }
    })
  }

  function changeSection(section) {
    setActiveSection(section)
    setNotice(null)
  }

  async function handleApprove(teacher) {
    const classSubjectIds = selectedSubjects[teacher.id] || []
    if (!classSubjectIds.length) {
      setNotice({ type: 'error', message: `請先選擇 ${teacher.displayName} 老師的任教科目。` })
      return
    }

    setApprovingId(teacher.id)
    setNotice(null)
    try {
      await approveTeacher({
        profileId: teacher.id,
        classId: dashboard.classInfo.id,
        classSubjectIds,
      })
      setSelectedSubjects((current) => {
        const next = { ...current }
        delete next[teacher.id]
        return next
      })
      await load({ quiet: true })
      setNotice({
        type: 'success',
        message: `${teacher.displayName} 老師已核准，並完成任教科目設定。`,
      })
    } catch (error) {
      setNotice({ type: 'error', message: error.message })
    } finally {
      setApprovingId('')
    }
  }

  async function handleAddSubject(event) {
    event.preventDefault()
    const subjectName = newSubjectName.trim().replace(/\s+/g, ' ')
    if (!subjectName) {
      setNotice({ type: 'error', message: '請輸入科目名稱。' })
      return
    }

    setAddingSubject(true)
    setNotice(null)
    try {
      await addClassSubject({ classId: dashboard.classInfo.id, name: subjectName })
      setNewSubjectName('')
      await load({ quiet: true })
      setNotice({ type: 'success', message: `已新增「${subjectName}」科目。` })
    } catch (error) {
      setNotice({ type: 'error', message: error.message })
    } finally {
      setAddingSubject(false)
    }
  }

  function moveClassSubject(index, offset) {
    setSubjectSettings((current) => {
      const target = index + offset
      if (target < 0 || target >= current.length) return current
      const next = [...current]
      ;[next[index], next[target]] = [next[target], next[index]]
      return next
    })
  }

  function toggleClassSubject(subjectId) {
    setSubjectSettings((current) => current.map((subject) => (
      subject.id === subjectId ? { ...subject, isActive: !subject.isActive } : subject
    )))
  }

  async function saveClassSubjects() {
    if (!subjectSettings.some((subject) => subject.isActive)) {
      setNotice({ type: 'error', message: '班級至少需要保留一個啟用科目。' })
      return
    }
    setSavingSubjects(true)
    setNotice(null)
    try {
      await updateClassSubjects({ classId: dashboard.classInfo.id, subjects: subjectSettings })
      await load({ quiet: true })
      setNotice({ type: 'success', message: '班級科目的啟用狀態與順序已儲存。' })
    } catch (error) {
      setNotice({ type: 'error', message: error.message })
    } finally {
      setSavingSubjects(false)
    }
  }

  return (
    <div className="admin-shell">
      <aside className="admin-sidebar">
        <div className="admin-brand">
          <span><BookOpen aria-hidden="true" /></span>
          <div><strong>八年六班</strong><small>線上聯絡簿</small></div>
        </div>
        <nav aria-label="管理員功能">
          <button
            className={activeSection === 'dashboard' ? 'is-active' : ''}
            type="button"
            onClick={() => changeSection('dashboard')}
          >
            <LayoutDashboard aria-hidden="true" />後台總覽
          </button>
          <button
            className={activeSection === 'students' ? 'is-active' : ''}
            type="button"
            onClick={() => changeSection('students')}
          >
            <Users aria-hidden="true" />學生與分組
          </button>
          <button className={activeSection === 'teachers' ? 'is-active' : ''} type="button" onClick={() => changeSection('teachers')}><UserCog aria-hidden="true" />教師與權限</button>
          <button className={activeSection === 'announcements' ? 'is-active' : ''} type="button" onClick={() => changeSection('announcements')}><Megaphone aria-hidden="true" />公告管理</button>
          <button className={activeSection === 'honors' ? 'is-active' : ''} type="button" onClick={() => changeSection('honors')}><Trophy aria-hidden="true" />榮譽榜</button>
          <button className={activeSection === 'calendar' ? 'is-active' : ''} type="button" onClick={() => changeSection('calendar')}><CalendarRange aria-hidden="true" />行事曆管理</button>
          <button className={activeSection === 'assignments' ? 'is-active' : ''} type="button" onClick={() => changeSection('assignments')}><ClipboardList aria-hidden="true" />作業管理</button>
        </nav>
        <div className="admin-sidebar-foot">
          <ShieldCheck aria-hidden="true" />
          <span><strong>管理員模式</strong><small>所有操作均受權限保護</small></span>
        </div>
      </aside>

      <main className="admin-main">
        <header className="admin-topbar">
          <div>
            <p className="eyebrow">ADMIN DASHBOARD</p>
            <h1>{user.displayName}老師，您好</h1>
            <p>{activeSection === 'dashboard' ? '先確認班級設定，再處理任課老師申請。' : activeSection === 'students' ? '建立學生帳號資料並分別設定數學、英語分組。' : activeSection === 'teachers' ? '查看已核准教師並調整可管理的任教科目。' : activeSection === 'announcements' ? '發布全校或班級公告，並查看學生已讀狀況。' : activeSection === 'honors' ? '建立向全班公開的榮譽紀錄，不顯示個人私密資料。' : activeSection === 'calendar' ? '建立與維護班級月份行事曆。' : '發布共同與分組作業，系統會保存學生對象快照。'}</p>
          </div>
          <div className="admin-topbar-actions">
            <button
              className="admin-icon-button"
              type="button"
              aria-label="重新整理"
              disabled={refreshing}
              onClick={() => load({ quiet: true })}
            >
              <RefreshCw className={refreshing ? 'is-spinning' : ''} aria-hidden="true" />
            </button>
            <button className="secondary-button" type="button" onClick={onExit}>
              <LogOut aria-hidden="true" />登出
            </button>
          </div>
        </header>

        {notice && <div className={`admin-notice is-${notice.type}`}>{notice.message}</div>}

        {loading && (
          <div className="admin-loading"><RefreshCw className="is-spinning" aria-hidden="true" />正在讀取班級資料…</div>
        )}

        {!loading && dashboard && activeSection === 'dashboard' && (
          <>
            <section className="admin-summary-grid" aria-label="班級摘要">
              <SummaryCard icon={CalendarDays} label="目前學年度" value={`${dashboard.academicYear.schoolYear} 學年度`} tone="is-yellow" />
              <SummaryCard icon={School} label="使用班級" value={dashboard.classInfo.name} tone="is-purple" />
              <SummaryCard icon={GraduationCap} label="啟用科目" value={`${dashboard.classSubjects.length} 科`} tone="is-mint" />
              <SummaryCard icon={Users} label="待核准教師" value={`${dashboard.pendingTeachers.length} 人`} tone="is-coral" />
            </section>

            <div className="admin-content-grid">
              <section className="admin-panel class-panel">
                <div className="admin-panel-heading">
                  <div><span className="panel-icon"><School aria-hidden="true" /></span><div><h2>班級基本設定</h2><p>已套用至共用 Supabase 資料庫</p></div></div>
                  <span className="status-pill">已啟用</span>
                </div>
                <div className="term-list">
                  {dashboard.terms.map((term) => (
                    <div key={term.id}>
                      <strong>第 {term.semester} 學期</strong>
                      <span>{formatDate(term.starts_on)}－{formatDate(term.ends_on)}</span>
                    </div>
                  ))}
                </div>
                <div className="subject-section">
                  <h3>班級科目</h3>
                  <div className="subject-chips">
                    {dashboard.classSubjects.map((subject) => <span key={subject.id}>{subject.name}</span>)}
                  </div>
                  <div className="subject-manager-list" aria-label="班級科目排序與啟用設定">
                    {subjectSettings.map((subject, index) => (
                      <div className={subject.isActive ? '' : 'is-inactive'} key={subject.id}>
                        <span>{index + 1}</span>
                        <strong>{subject.name}</strong>
                        <button type="button" aria-label={`${subject.name}上移`} disabled={index === 0 || savingSubjects} onClick={() => moveClassSubject(index, -1)}><ArrowUp /></button>
                        <button type="button" aria-label={`${subject.name}下移`} disabled={index === subjectSettings.length - 1 || savingSubjects} onClick={() => moveClassSubject(index, 1)}><ArrowDown /></button>
                        <button className="subject-active-toggle" type="button" disabled={savingSubjects} onClick={() => toggleClassSubject(subject.id)}>{subject.isActive ? <Eye /> : <EyeOff />}{subject.isActive ? '啟用' : '停用'}</button>
                      </div>
                    ))}
                    <button className="subject-settings-save" type="button" disabled={savingSubjects} onClick={saveClassSubjects}><Save />{savingSubjects ? '儲存中…' : '儲存科目順序與狀態'}</button>
                  </div>
                  <form className="subject-add-form" onSubmit={handleAddSubject}>
                    <label htmlFor="new-class-subject">新增科目</label>
                    <div>
                      <input
                        id="new-class-subject"
                        type="text"
                        maxLength="20"
                        value={newSubjectName}
                        placeholder="例如：資訊科技"
                        disabled={addingSubject}
                        onChange={(event) => setNewSubjectName(event.target.value)}
                      />
                      <button type="submit" disabled={addingSubject || !newSubjectName.trim()}>
                        <Plus aria-hidden="true" />{addingSubject ? '新增中…' : '新增'}
                      </button>
                    </div>
                    <small>新增後即可用於作業發布、教師科目與小老師設定。</small>
                  </form>
                </div>
              </section>

              <section className="admin-panel teacher-panel">
                <div className="admin-panel-heading">
                  <div><span className="panel-icon"><UserCheck aria-hidden="true" /></span><div><h2>任課老師核准</h2><p>核准時一併設定可管理的科目</p></div></div>
                  <span className="pending-count">{dashboard.pendingTeachers.length}</span>
                </div>

                {!dashboard.pendingTeachers.length && <EmptyTeachers />}

                <div className="pending-teacher-list">
                  {dashboard.pendingTeachers.map((teacher) => (
                    <article className="pending-teacher-card" key={teacher.id}>
                      <div className="teacher-identity">
                        <span>{teacher.displayName.slice(0, 1)}</span>
                        <div><strong>{teacher.displayName}老師</strong><small>@{teacher.username}</small></div>
                      </div>
                      <fieldset>
                        <legend>選擇任教科目</legend>
                        <div className="subject-options">
                          {dashboard.classSubjects.map((subject) => {
                            const checked = (selectedSubjects[teacher.id] || []).includes(subject.id)
                            return (
                              <label className={checked ? 'is-checked' : ''} key={subject.id}>
                                <input
                                  type="checkbox"
                                  checked={checked}
                                  onChange={() => toggleSubject(teacher.id, subject.id)}
                                />
                                <span>{checked && <Check aria-hidden="true" />}{subject.name}</span>
                              </label>
                            )
                          })}
                        </div>
                      </fieldset>
                      <button
                        className="approve-button"
                        type="button"
                        disabled={approvingId === teacher.id}
                        onClick={() => handleApprove(teacher)}
                      >
                        <UserCheck aria-hidden="true" />
                        {approvingId === teacher.id ? '核准中…' : '核准並設定科目'}
                      </button>
                    </article>
                  ))}
                </div>
              </section>
            </div>
          </>
        )}

        {!loading && dashboard && activeSection === 'students' && (
          <StudentManagement dashboard={dashboard} />
        )}
        {!loading && dashboard && activeSection === 'teachers' && (
          <TeacherManagement dashboard={dashboard} onNotice={handleSectionNotice} />
        )}
        {!loading && dashboard && activeSection === 'announcements' && (
          <AnnouncementManagement dashboard={dashboard} onNotice={handleSectionNotice} />
        )}
        {!loading && dashboard && activeSection === 'honors' && (
          <HonorManagement dashboard={dashboard} onNotice={handleSectionNotice} />
        )}
        {!loading && dashboard && activeSection === 'calendar' && (
          <CalendarManagement dashboard={dashboard} onNotice={handleSectionNotice} />
        )}
        {!loading && dashboard && activeSection === 'assignments' && (
          <AssignmentManagement dashboard={dashboard} />
        )}
      </main>
    </div>
  )
}
