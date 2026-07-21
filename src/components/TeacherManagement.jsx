import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  Ban,
  Check,
  CheckCircle2,
  RefreshCw,
  Save,
  UserCog,
  UserCheck,
} from 'lucide-react'
import {
  loadApprovedTeachers,
  setTeacherActive,
  updateTeacherSubjects,
} from '../services/teacherService.js'

function normalizeSubjectIds(ids) {
  return [...(ids || [])].sort()
}

function isSameSelection(left, right) {
  return JSON.stringify(normalizeSubjectIds(left)) === JSON.stringify(normalizeSubjectIds(right))
}

export default function TeacherManagement({ dashboard, onNotice }) {
  const [teachers, setTeachers] = useState([])
  const [drafts, setDrafts] = useState({})
  const [loading, setLoading] = useState(true)
  const [savingId, setSavingId] = useState('')

  const subjectNames = useMemo(
    () => new Map(dashboard.classSubjects.map((subject) => [subject.id, subject.name])),
    [dashboard.classSubjects],
  )

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const data = await loadApprovedTeachers({ classId: dashboard.classInfo.id })
      setTeachers(data)
      setDrafts(Object.fromEntries(data.map((teacher) => [teacher.id, [...teacher.classSubjectIds]])))
    } catch (error) {
      onNotice('error', error.message)
    } finally {
      setLoading(false)
    }
  }, [dashboard.classInfo.id, onNotice])

  useEffect(() => { load() }, [load])

  function toggleSubject(teacherId, subjectId) {
    setDrafts((current) => {
      const next = new Set(current[teacherId] || [])
      if (next.has(subjectId)) next.delete(subjectId)
      else next.add(subjectId)
      return { ...current, [teacherId]: [...next] }
    })
  }

  async function save(teacher) {
    const classSubjectIds = drafts[teacher.id] || []
    if (!classSubjectIds.length) {
      onNotice('error', `${teacher.displayName} 老師至少需要保留一個任教科目。`)
      return
    }

    setSavingId(teacher.id)
    try {
      await updateTeacherSubjects({
        profileId: teacher.id,
        classId: dashboard.classInfo.id,
        classSubjectIds,
      })
      await load()
      const selectedNames = classSubjectIds.map((id) => subjectNames.get(id)).filter(Boolean)
      onNotice('success', `${teacher.displayName} 老師的任教科目已更新為：${selectedNames.join('、')}。`)
    } catch (error) {
      onNotice('error', error.message)
    } finally {
      setSavingId('')
    }
  }

  async function toggleTeacherActive(teacher) {
    const nextActive = !teacher.isActive
    const action = nextActive ? '重新啟用' : '停用'
    const detail = nextActive
      ? '重新啟用後，這位老師會恢復原本的任教科目權限。'
      : '停用後，這位老師將無法登入或操作作業；原任教科目設定會保留。'
    if (!window.confirm(`確定要${action}${teacher.displayName}老師的帳號嗎？\n\n${detail}`)) return

    setSavingId(teacher.id)
    try {
      await setTeacherActive({
        profileId: teacher.id,
        classId: dashboard.classInfo.id,
        isActive: nextActive,
      })
      await load()
      onNotice('success', `${teacher.displayName}老師的帳號已${action}。`)
    } catch (error) {
      onNotice('error', error.message)
    } finally {
      setSavingId('')
    }
  }

  return (
    <section className="teacher-management">
      <div className="student-page-heading teacher-page-heading">
        <div>
          <p className="eyebrow">TEACHER &amp; PERMISSIONS</p>
          <h2>教師與權限管理</h2>
          <p>調整已核准任課老師的任教科目，也可暫時停用或重新啟用帳號。</p>
        </div>
        <button className="teacher-refresh-button" type="button" aria-label="重新整理教師清單" title="重新整理" disabled={loading} onClick={load}>
          <RefreshCw className={loading ? 'is-spinning' : ''} aria-hidden="true" />
        </button>
      </div>

      {loading && <div className="admin-loading"><RefreshCw className="is-spinning" aria-hidden="true" />正在讀取教師資料…</div>}

      {!loading && !teachers.length && (
        <div className="teacher-empty-state">
          <span><UserCog aria-hidden="true" /></span>
          <div><strong>目前沒有已核准的任課老師</strong><p>老師註冊並由您在後台總覽核准後，會顯示在這裡。</p></div>
        </div>
      )}

      {!loading && teachers.length > 0 && (
        <div className="approved-teacher-list">
          {teachers.map((teacher) => {
            const selectedIds = drafts[teacher.id] || []
            const dirty = !isSameSelection(selectedIds, teacher.classSubjectIds)
            return (
              <article className={`approved-teacher-card${teacher.isActive ? '' : ' is-inactive'}`} key={teacher.id}>
                <div className="approved-teacher-heading">
                  <div className="teacher-identity">
                    <span>{teacher.displayName.slice(0, 1)}</span>
                    <div><strong>{teacher.displayName}老師</strong><small>帳號：{teacher.username}</small></div>
                  </div>
                  <span className={`teacher-approved-pill${teacher.isActive ? '' : ' is-inactive'}`}>
                    {teacher.isActive ? <CheckCircle2 aria-hidden="true" /> : <Ban aria-hidden="true" />}
                    {teacher.isActive ? '使用中' : '已停用'}
                  </span>
                </div>

                <fieldset>
                  <legend>可管理的任教科目（可複選）</legend>
                  <div className="subject-options">
                    {dashboard.classSubjects.map((subject) => {
                      const checked = selectedIds.includes(subject.id)
                      return (
                        <label className={checked ? 'is-checked' : ''} key={subject.id}>
                          <input type="checkbox" checked={checked} disabled={!teacher.isActive || savingId === teacher.id} onChange={() => toggleSubject(teacher.id, subject.id)} />
                          <span>{checked && <Check aria-hidden="true" />}{subject.name}</span>
                        </label>
                      )
                    })}
                  </div>
                </fieldset>

                <div className="teacher-card-actions">
                  <span>{selectedIds.length ? `已選擇 ${selectedIds.length} 個科目` : '請至少選擇一個科目'}</span>
                  <div className="teacher-card-buttons">
                    <button className={`teacher-status-button${teacher.isActive ? ' is-suspend' : ' is-restore'}`} type="button" disabled={savingId === teacher.id} onClick={() => toggleTeacherActive(teacher)}>
                      {teacher.isActive ? <Ban aria-hidden="true" /> : <UserCheck aria-hidden="true" />}
                      {savingId === teacher.id ? '處理中…' : teacher.isActive ? '停用帳號' : '重新啟用'}
                    </button>
                    <button type="button" disabled={!teacher.isActive || !dirty || !selectedIds.length || savingId === teacher.id} onClick={() => save(teacher)}>
                    <Save aria-hidden="true" />{savingId === teacher.id ? '儲存中…' : dirty ? '儲存變更' : '已是最新設定'}
                    </button>
                  </div>
                </div>
              </article>
            )
          })}
        </div>
      )}
    </section>
  )
}
