import { useEffect, useState } from 'react'
import {
  ArrowRight,
  BookOpen,
  CheckCircle2,
  ClipboardCheck,
  Clock3,
  Database,
  ExternalLink,
  GraduationCap,
  KeyRound,
  LockKeyhole,
  LogIn,
  ShieldCheck,
  Sparkles,
  UserPlus,
  Users,
} from 'lucide-react'
import { TextField, PasswordField } from './components/FormFields.jsx'
import AdminDashboard from './components/AdminDashboard.jsx'
import StudentDashboard from './components/StudentDashboard.jsx'
import TeacherDashboard from './components/TeacherDashboard.jsx'
import { isSupabaseConfigured } from './lib/supabase.js'
import {
  activateStudent,
  loginAccount,
  registerTeacher,
  resetStudentPassword,
  restoreCurrentAccount,
  signOut,
} from './services/authService.js'
import {
  validateLogin,
  validateStudentActivation,
  validateStudentPasswordReset,
  validateTeacherRegistration,
} from './utils/validation.js'

const learningSystemUrl = import.meta.env.VITE_LEARNING_SYSTEM_URL?.trim()
  || import.meta.env.VITE_ENGLISH_VOCAB_URL?.trim()

function ConnectionBadge() {
  return (
    <div className={`connection-badge ${isSupabaseConfigured ? 'is-ready' : 'is-pending'}`}>
      <Database aria-hidden="true" />
      <span>{isSupabaseConfigured ? '資料庫已連接' : '目前為介面預覽'}</span>
    </div>
  )
}

function Notice({ notice }) {
  if (!notice) return null
  return (
    <div className={`notice notice-${notice.type}`} role="status">
      {notice.type === 'success' ? <CheckCircle2 aria-hidden="true" /> : <ShieldCheck aria-hidden="true" />}
      <span>{notice.message}</span>
    </div>
  )
}

function PrimaryButton({ loading, icon: Icon = ArrowRight, children }) {
  return (
    <button className="primary-button" type="submit" disabled={loading}>
      <span>{loading ? '處理中…' : children}</span>
      <Icon aria-hidden="true" />
    </button>
  )
}

function StudentLogin({ onSignedIn }) {
  const [form, setForm] = useState({ username: '', password: '' })
  const [errors, setErrors] = useState({})
  const [notice, setNotice] = useState(null)
  const [loading, setLoading] = useState(false)

  async function handleSubmit(event) {
    event.preventDefault()
    const nextErrors = validateLogin(form)
    setErrors(nextErrors)
    setNotice(null)
    if (Object.keys(nextErrors).length) return

    setLoading(true)
    try {
      const data = await loginAccount({ accountType: 'student', ...form })
      onSignedIn(data?.profile || { displayName: '學生', role: 'student' })
    } catch (error) {
      setNotice({
        type: error.code === 'CONFIG_MISSING' ? 'setup' : 'error',
        message: error.message,
      })
    } finally {
      setLoading(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} noValidate>
      <div className="form-heading">
        <div className="form-icon student-icon"><GraduationCap aria-hidden="true" /></div>
        <div>
          <h2>學生／家長登入</h2>
          <p>家長與學生使用同一組學號及密碼。</p>
        </div>
      </div>
      <TextField
        id="student-login-id"
        label="學生學號"
        inputMode="numeric"
        autoComplete="username"
        placeholder="請輸入學號"
        value={form.username}
        error={errors.username}
        onChange={(event) => setForm({ ...form, username: event.target.value })}
      />
      <PasswordField
        id="student-login-password"
        label="密碼"
        autoComplete="current-password"
        placeholder="請輸入密碼"
        value={form.password}
        error={errors.password}
        onChange={(event) => setForm({ ...form, password: event.target.value })}
      />
      <Notice notice={notice} />
      <PrimaryButton loading={loading} icon={LogIn}>登入聯絡簿</PrimaryButton>
    </form>
  )
}

function StudentActivation({ onActivated }) {
  const [form, setForm] = useState({
    studentId: '',
    activationCode: '',
    password: '',
    confirmPassword: '',
  })
  const [errors, setErrors] = useState({})
  const [notice, setNotice] = useState(null)
  const [loading, setLoading] = useState(false)

  function update(field, value) {
    setForm((current) => ({ ...current, [field]: value }))
  }

  async function handleSubmit(event) {
    event.preventDefault()
    const nextErrors = validateStudentActivation(form)
    setErrors(nextErrors)
    setNotice(null)
    if (Object.keys(nextErrors).length) return

    setLoading(true)
    try {
      const data = await activateStudent(form)
      onActivated(data.profile)
    } catch (error) {
      setNotice({
        type: error.code === 'CONFIG_MISSING' ? 'setup' : 'error',
        message: error.message,
      })
    } finally {
      setLoading(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} noValidate>
      <div className="form-heading">
        <div className="form-icon activation-icon"><KeyRound aria-hidden="true" /></div>
        <div>
          <h2>第一次使用</h2>
          <p>已有英文單字帳號請輸入原密碼；尚無帳號則會同時建立兩套系統的共用帳號。</p>
        </div>
      </div>
      <div className="field-grid">
        <TextField
          id="activation-student-id"
          label="學生學號"
          inputMode="numeric"
          autoComplete="username"
          placeholder="請輸入學號"
          value={form.studentId}
          error={errors.studentId}
          onChange={(event) => update('studentId', event.target.value)}
        />
        <TextField
          id="activation-code"
          label="一次性啟用碼"
          autoCapitalize="characters"
          autoComplete="one-time-code"
          placeholder="例如：AB12CD"
          value={form.activationCode}
          error={errors.activationCode}
          onChange={(event) => update('activationCode', event.target.value)}
        />
      </div>
      <PasswordField
        id="activation-password"
        label="共用密碼"
        autoComplete="current-password"
        placeholder="請輸入英文單字系統密碼"
        hint="新帳號需至少 8 個字元並包含英文與數字；既有帳號沿用原密碼。"
        value={form.password}
        error={errors.password}
        onChange={(event) => update('password', event.target.value)}
      />
      <PasswordField
        id="activation-confirm-password"
        label="再次輸入共用密碼"
        autoComplete="current-password"
        placeholder="請再輸入一次"
        value={form.confirmPassword}
        error={errors.confirmPassword}
        onChange={(event) => update('confirmPassword', event.target.value)}
      />
      <Notice notice={notice} />
      <PrimaryButton loading={loading} icon={ShieldCheck}>完成啟用</PrimaryButton>
    </form>
  )
}

function StudentPasswordReset({ onReset }) {
  const [form, setForm] = useState({
    studentId: '',
    resetCode: '',
    password: '',
    confirmPassword: '',
  })
  const [errors, setErrors] = useState({})
  const [notice, setNotice] = useState(null)
  const [loading, setLoading] = useState(false)

  function update(field, value) {
    setForm((current) => ({ ...current, [field]: value }))
    setErrors((current) => ({ ...current, [field]: undefined }))
  }

  async function handleSubmit(event) {
    event.preventDefault()
    const nextErrors = validateStudentPasswordReset(form)
    setErrors(nextErrors)
    setNotice(null)
    if (Object.keys(nextErrors).length) return

    setLoading(true)
    try {
      const data = await resetStudentPassword(form)
      onReset(data.profile)
    } catch (error) {
      setNotice({
        type: error.code === 'CONFIG_MISSING' ? 'setup' : 'error',
        message: error.message,
      })
    } finally {
      setLoading(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} noValidate>
      <div className="form-heading">
        <div className="form-icon activation-icon"><KeyRound aria-hidden="true" /></div>
        <div>
          <h2>重新設定密碼</h2>
          <p>請輸入導師提供的重設碼，再自行建立新的共用密碼。</p>
        </div>
      </div>
      <div className="field-grid">
        <TextField
          id="reset-student-id"
          label="學生學號"
          inputMode="numeric"
          autoComplete="username"
          placeholder="請輸入學號"
          value={form.studentId}
          error={errors.studentId}
          onChange={(event) => update('studentId', event.target.value)}
        />
        <TextField
          id="password-reset-code"
          label="一次性密碼重設碼"
          autoCapitalize="characters"
          autoComplete="one-time-code"
          placeholder="例如：AB12CD34"
          value={form.resetCode}
          error={errors.resetCode}
          onChange={(event) => update('resetCode', event.target.value)}
        />
      </div>
      <PasswordField
        id="new-student-password"
        label="建立新密碼"
        autoComplete="new-password"
        placeholder="至少 8 個字元"
        hint="需同時包含英文字母與數字，並會同步成為各科學習系統的共用密碼。"
        value={form.password}
        error={errors.password}
        onChange={(event) => update('password', event.target.value)}
      />
      <PasswordField
        id="confirm-new-student-password"
        label="再次輸入新密碼"
        autoComplete="new-password"
        placeholder="請再輸入一次"
        value={form.confirmPassword}
        error={errors.confirmPassword}
        onChange={(event) => update('confirmPassword', event.target.value)}
      />
      <Notice notice={notice} />
      <PrimaryButton loading={loading} icon={ShieldCheck}>更新密碼並登入</PrimaryButton>
    </form>
  )
}

function TeacherLogin({ onSignedIn }) {
  const [form, setForm] = useState({ username: '', password: '' })
  const [errors, setErrors] = useState({})
  const [notice, setNotice] = useState(null)
  const [loading, setLoading] = useState(false)

  async function handleSubmit(event) {
    event.preventDefault()
    const nextErrors = validateLogin(form)
    setErrors(nextErrors)
    setNotice(null)
    if (Object.keys(nextErrors).length) return

    setLoading(true)
    try {
      const data = await loginAccount({ accountType: 'teacher', ...form })
      if (data?.profile?.approvalStatus === 'pending') {
        setNotice({ type: 'setup', message: '帳號仍在等待導師核准，目前不能查看班級資料。' })
      } else {
        onSignedIn(data?.profile || { displayName: '任課老師', role: 'teacher' })
      }
    } catch (error) {
      setNotice({
        type: error.code === 'CONFIG_MISSING' ? 'setup' : 'error',
        message: error.message,
      })
    } finally {
      setLoading(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} noValidate>
      <div className="form-heading">
        <div className="form-icon teacher-icon"><BookOpen aria-hidden="true" /></div>
        <div>
          <h2>教師登入</h2>
          <p>核准後，只能管理您被指派的任教科目。</p>
        </div>
      </div>
      <TextField
        id="teacher-login-id"
        label="教師帳號"
        autoComplete="username"
        placeholder="請輸入教師帳號"
        value={form.username}
        error={errors.username}
        onChange={(event) => setForm({ ...form, username: event.target.value })}
      />
      <PasswordField
        id="teacher-login-password"
        label="密碼"
        autoComplete="current-password"
        placeholder="請輸入密碼"
        value={form.password}
        error={errors.password}
        onChange={(event) => setForm({ ...form, password: event.target.value })}
      />
      <Notice notice={notice} />
      <PrimaryButton loading={loading} icon={LogIn}>教師登入</PrimaryButton>
    </form>
  )
}

function TeacherRegistration({ onRegistered }) {
  const [form, setForm] = useState({
    username: '',
    displayName: '',
    password: '',
    confirmPassword: '',
  })
  const [errors, setErrors] = useState({})
  const [notice, setNotice] = useState(null)
  const [loading, setLoading] = useState(false)

  function update(field, value) {
    setForm((current) => ({ ...current, [field]: value }))
  }

  async function handleSubmit(event) {
    event.preventDefault()
    const nextErrors = validateTeacherRegistration(form)
    setErrors(nextErrors)
    setNotice(null)
    if (Object.keys(nextErrors).length) return

    setLoading(true)
    try {
      await registerTeacher(form)
      onRegistered(form.displayName)
    } catch (error) {
      setNotice({
        type: error.code === 'CONFIG_MISSING' ? 'setup' : 'error',
        message: error.message,
      })
    } finally {
      setLoading(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} noValidate>
      <div className="form-heading">
        <div className="form-icon teacher-icon"><UserPlus aria-hidden="true" /></div>
        <div>
          <h2>建立教師帳號</h2>
          <p>送出後需由八年六班導師核准並設定任教科目。</p>
        </div>
      </div>
      <div className="field-grid">
        <TextField
          id="teacher-register-name"
          label="教師姓名"
          autoComplete="name"
          placeholder="例如：王老師"
          value={form.displayName}
          error={errors.displayName}
          onChange={(event) => update('displayName', event.target.value)}
        />
        <TextField
          id="teacher-register-id"
          label="自訂登入帳號"
          autoComplete="username"
          placeholder="例如：teacher.wang"
          hint="只能使用英文、數字、句點、底線或連字號。"
          value={form.username}
          error={errors.username}
          onChange={(event) => update('username', event.target.value)}
        />
      </div>
      <PasswordField
        id="teacher-register-password"
        label="建立密碼"
        autoComplete="new-password"
        placeholder="至少 8 個字元"
        hint="需同時包含英文字母與數字。"
        value={form.password}
        error={errors.password}
        onChange={(event) => update('password', event.target.value)}
      />
      <PasswordField
        id="teacher-register-confirm-password"
        label="再次輸入密碼"
        autoComplete="new-password"
        placeholder="請再輸入一次"
        value={form.confirmPassword}
        error={errors.confirmPassword}
        onChange={(event) => update('confirmPassword', event.target.value)}
      />
      <Notice notice={notice} />
      <PrimaryButton loading={loading} icon={UserPlus}>送出註冊申請</PrimaryButton>
    </form>
  )
}

function PendingCard({ name, onBack }) {
  return (
    <div className="pending-card">
      <div className="pending-illustration"><Clock3 aria-hidden="true" /></div>
      <p className="eyebrow">註冊申請已送出</p>
      <h2>{name || '老師'}，請等待導師核准</h2>
      <p>導師設定您的任教科目後，即可登入查看本科作業及繳交狀況。</p>
      <button className="secondary-button" type="button" onClick={onBack}>返回教師登入</button>
    </div>
  )
}

function AuthPanel({ onSignedIn }) {
  const [audience, setAudience] = useState('student')
  const [studentMode, setStudentMode] = useState('login')
  const [teacherMode, setTeacherMode] = useState('login')
  const [pendingTeacher, setPendingTeacher] = useState('')
  const [activationMessage, setActivationMessage] = useState('')

  function switchAudience(nextAudience) {
    setAudience(nextAudience)
    setActivationMessage('')
  }

  return (
    <section className="auth-card" aria-label="登入區">
      <div className="auth-card-topline">
        <ConnectionBadge />
        <span className="privacy-chip"><LockKeyhole aria-hidden="true" />個人資料分開顯示</span>
      </div>
      <div className="audience-tabs" role="tablist" aria-label="選擇登入身分">
        <button
          type="button"
          role="tab"
          aria-selected={audience === 'student'}
          className={audience === 'student' ? 'is-active' : ''}
          onClick={() => switchAudience('student')}
        >
          <Users aria-hidden="true" />學生／家長
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={audience === 'teacher'}
          className={audience === 'teacher' ? 'is-active' : ''}
          onClick={() => switchAudience('teacher')}
        >
          <BookOpen aria-hidden="true" />教師
        </button>
      </div>

      {activationMessage && <Notice notice={{ type: 'success', message: activationMessage }} />}

      {audience === 'student' && studentMode === 'login' && (
        <>
          <StudentLogin onSignedIn={onSignedIn} />
          <div className="auth-help-actions">
            <button className="text-button" type="button" onClick={() => setStudentMode('activate')}>
              第一次使用？使用啟用碼建立密碼
            </button>
            <button className="text-button" type="button" onClick={() => setStudentMode('reset')}>
              忘記密碼？使用導師提供的重設碼
            </button>
          </div>
        </>
      )}
      {audience === 'student' && studentMode === 'activate' && (
        <>
          <StudentActivation
            onActivated={onSignedIn}
          />
          <button className="text-button" type="button" onClick={() => setStudentMode('login')}>
            已經啟用？返回登入
          </button>
        </>
      )}
      {audience === 'student' && studentMode === 'reset' && (
        <>
          <StudentPasswordReset onReset={onSignedIn} />
          <button className="text-button" type="button" onClick={() => setStudentMode('login')}>
            返回學生／家長登入
          </button>
        </>
      )}

      {audience === 'teacher' && pendingTeacher && (
        <PendingCard
          name={pendingTeacher}
          onBack={() => {
            setPendingTeacher('')
            setTeacherMode('login')
          }}
        />
      )}
      {audience === 'teacher' && !pendingTeacher && teacherMode === 'login' && (
        <>
          <TeacherLogin onSignedIn={onSignedIn} />
          <button className="text-button" type="button" onClick={() => setTeacherMode('register')}>
            第一次使用？建立教師帳號
          </button>
        </>
      )}
      {audience === 'teacher' && !pendingTeacher && teacherMode === 'register' && (
        <>
          <TeacherRegistration onRegistered={setPendingTeacher} />
          <button className="text-button" type="button" onClick={() => setTeacherMode('login')}>
            已有帳號？返回教師登入
          </button>
        </>
      )}
    </section>
  )
}

function SignedInPlaceholder({ user, onExit }) {
  return (
    <main className="signed-in-shell">
      <section className="signed-in-card">
        <div className="signed-in-icon"><CheckCircle2 aria-hidden="true" /></div>
        <p className="eyebrow">登入流程測試成功</p>
        <h1>{user.displayName || user.display_name || '使用者'}，歡迎進入八年六班聯絡簿</h1>
        <p>第二階段先確認登入及權限入口，作業與公告首頁會在下一階段接上。</p>
        <div className="signed-in-actions">
          <button className="secondary-button" type="button" onClick={onExit}>登出並返回</button>
        </div>
      </section>
    </main>
  )
}

function HeroPreview() {
  return (
    <section className="hero-copy">
      <div className="school-mark"><span>806</span><Sparkles aria-hidden="true" /></div>
      <p className="eyebrow">115 學年度・八年六班</p>
      <h1>每天的作業與提醒，<br /><span>清楚放在同一個地方。</span></h1>
      <p className="hero-description">
        A、B 組作業各自呈現，共同作業不漏接；家長與學生只看到自己的學習紀錄。
      </p>

      <div className="assignment-stack" aria-label="作業卡片預覽">
        <article className="assignment-card common-card">
          <span className="card-label">共同作業</span>
          <strong>國文・完成閱讀學習單</strong>
          <small>明天上課前繳交</small>
        </article>
        <article className="assignment-card group-a-card">
          <span className="card-label">A 組</span>
          <strong>數學・習作第 12 頁</strong>
          <small>依自己的分組顯示</small>
        </article>
        <article className="assignment-card group-b-card">
          <span className="card-label">B 組</span>
          <strong>英語・單字練習 1～20</strong>
          <small>共同作業也會一起出現</small>
        </article>
      </div>

      <div className="feature-pills">
        <span><ClipboardCheck aria-hidden="true" />作業繳交追蹤</span>
        <span><ShieldCheck aria-hidden="true" />個人資料保護</span>
        <span><Clock3 aria-hidden="true" />補交提醒保留</span>
      </div>
    </section>
  )
}

export default function App() {
  const [currentUser, setCurrentUser] = useState(null)
  const [linkNotice, setLinkNotice] = useState('')

  useEffect(() => {
    if (!isSupabaseConfigured) return undefined

    let active = true
    restoreCurrentAccount()
      .then((profile) => {
        if (active && profile?.approvalStatus === 'approved') setCurrentUser(profile)
      })
      .catch(() => {
        // 連線失敗時仍顯示登入頁，讓使用者重新登入。
      })

    return () => {
      active = false
    }
  }, [])

  async function handleSignOut() {
    if (isSupabaseConfigured) {
      try {
        await signOut()
      } catch {
        // 即使遠端登出失敗，仍離開本機預覽畫面。
      }
    }
    setCurrentUser(null)
  }

  if (currentUser) {
    if (currentUser.role === 'admin') {
      return <AdminDashboard user={currentUser} onExit={handleSignOut} />
    }
    if (currentUser.role === 'student') {
      return <StudentDashboard onExit={handleSignOut} learningSystemUrl={learningSystemUrl} />
    }
    if (currentUser.role === 'teacher') {
      return <TeacherDashboard user={currentUser} onExit={handleSignOut} />
    }
    return <SignedInPlaceholder user={currentUser} onExit={handleSignOut} />
  }

  return (
    <div className="page-shell">
      <header className="site-header">
        <a className="brand" href="#top" aria-label="八年六班線上聯絡簿首頁">
          <span className="brand-icon"><BookOpen aria-hidden="true" /></span>
          <span><strong>八年六班</strong><small>線上聯絡簿</small></span>
        </a>
        <button
          className="vocab-link"
          type="button"
          onClick={() => {
            if (learningSystemUrl) window.location.href = learningSystemUrl
            else setLinkNotice('各科學習系統網址會在正式部署前設定。')
          }}
        >
          前往各科學習系統<ExternalLink aria-hidden="true" />
        </button>
      </header>

      {linkNotice && (
        <button className="floating-notice" type="button" onClick={() => setLinkNotice('')}>
          {linkNotice}
        </button>
      )}

      <main className="login-layout" id="top">
        <HeroPreview />
        <AuthPanel onSignedIn={setCurrentUser} />
      </main>

      <footer>
        <span>雲林縣立石榴國民中學・115 學年度八年六班</span>
        <span>重要資料需登入後才能查看</span>
      </footer>
    </div>
  )
}
