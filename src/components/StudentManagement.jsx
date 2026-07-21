import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  CheckCircle2,
  Clipboard,
  KeyRound,
  Plus,
  RefreshCw,
  RotateCcw,
  Save,
  Settings2,
  UserPlus,
  Users,
} from 'lucide-react'
import {
  createStudentPasswordReset,
  createStudent,
  loadStudents,
  regenerateStudentActivation,
  updateStudentSettings,
} from '../services/adminService.js'

const initialForm = {
  studentId: '',
  seatNumber: '',
  fullName: '',
  mathGroup: 'A',
  englishGroup: 'A',
}

function validate(form) {
  const errors = {}
  if (!/^\d{4,20}$/.test(form.studentId.trim())) errors.studentId = '學號需為 4～20 位數字。'
  const seatNumber = Number(form.seatNumber)
  if (!Number.isInteger(seatNumber) || seatNumber < 1 || seatNumber > 99) {
    errors.seatNumber = '座號需為 1～99 的整數。'
  }
  if (form.fullName.trim().length < 2 || form.fullName.trim().length > 50) {
    errors.fullName = '姓名需為 2～50 個字元。'
  }
  return errors
}

function FieldError({ message }) {
  return message ? <span className="student-field-error">{message}</span> : null
}

export default function StudentManagement({ dashboard, onCountChange }) {
  const [termId, setTermId] = useState(dashboard.terms[0]?.id || '')
  const [students, setStudents] = useState([])
  const [form, setForm] = useState(initialForm)
  const [errors, setErrors] = useState({})
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [notice, setNotice] = useState(null)
  const [activation, setActivation] = useState(null)
  const [editingStudent, setEditingStudent] = useState(null)
  const [editForm, setEditForm] = useState(null)
  const [updating, setUpdating] = useState(false)

  const selectedTerm = useMemo(
    () => dashboard.terms.find((term) => term.id === termId),
    [dashboard.terms, termId],
  )

  const load = useCallback(async () => {
    if (!termId) return
    setLoading(true)
    try {
      const data = await loadStudents({
        classId: dashboard.classInfo.id,
        academicTermId: termId,
      })
      setStudents(data)
      onCountChange?.(data.length)
      setNotice(null)
    } catch (error) {
      setNotice({ type: 'error', message: error.message })
    } finally {
      setLoading(false)
    }
  }, [dashboard.classInfo.id, onCountChange, termId])

  useEffect(() => {
    load()
  }, [load])

  function update(field, value) {
    setForm((current) => ({ ...current, [field]: value }))
    setErrors((current) => ({ ...current, [field]: undefined }))
  }

  async function handleSubmit(event) {
    event.preventDefault()
    const nextErrors = validate(form)
    setErrors(nextErrors)
    setNotice(null)
    if (Object.keys(nextErrors).length) return

    setSaving(true)
    try {
      const result = await createStudent({
        ...form,
        classId: dashboard.classInfo.id,
        academicTermId: termId,
      })
      setActivation({
        kind: 'activation',
        fullName: result.student.fullName,
        studentId: result.student.studentIdCode,
        code: result.activation.code,
        expiresAt: result.activation.expiresAt,
      })
      setForm(initialForm)
      await load()
      setNotice({ type: 'success', message: `${result.student.fullName} 已建立完成。` })
    } catch (error) {
      setNotice({ type: 'error', message: error.message })
    } finally {
      setSaving(false)
    }
  }

  async function copyActivation() {
    if (!activation) return
    const codeLabel = activation.kind === 'password-reset' ? '一次性密碼重設碼' : '一次性啟用碼'
    const text = `學號：${activation.studentId}\n${codeLabel}：${activation.code}`
    try {
      await navigator.clipboard.writeText(text)
      setNotice({ type: 'success', message: '學號與啟用碼已複製。' })
    } catch {
      setNotice({ type: 'error', message: '瀏覽器無法自動複製，請手動記下啟用碼。' })
    }
  }

  function startEditing(student) {
    setEditingStudent(student)
    setEditForm({
      mathGroup: student.mathGroup,
      englishGroup: student.englishGroup,
      isHomeworkLeader: student.isHomeworkLeader,
      helperAssignments: student.helperAssignments,
    })
    setActivation(null)
    setNotice(null)
  }

  function toggleHelperSubject(subjectId) {
    setEditForm((current) => {
      const selected = current.helperAssignments.some((item) => item.classSubjectId === subjectId)
      return {
        ...current,
        helperAssignments: selected
          ? current.helperAssignments.filter((item) => item.classSubjectId !== subjectId)
          : [...current.helperAssignments, { classSubjectId: subjectId, targetGroupCode: null }],
      }
    })
  }

  function setGroupedHelperSubject(subjectId, targetGroupCode) {
    setEditForm((current) => ({
      ...current,
      helperAssignments: [
        ...current.helperAssignments.filter((item) => item.classSubjectId !== subjectId),
        ...(targetGroupCode ? [{ classSubjectId: subjectId, targetGroupCode }] : []),
      ],
    }))
  }

  async function saveSettings() {
    if (!editingStudent || !editForm) return
    setUpdating(true)
    setNotice(null)
    try {
      await updateStudentSettings({
        studentId: editingStudent.id,
        academicTermId: termId,
        ...editForm,
      })
      await load()
      setEditingStudent(null)
      setEditForm(null)
      setNotice({ type: 'success', message: `${editingStudent.fullName} 的分組與小老師設定已更新。` })
    } catch (error) {
      setNotice({ type: 'error', message: error.message })
    } finally {
      setUpdating(false)
    }
  }

  async function regenerateActivation() {
    if (!editingStudent || editingStudent.activated) return
    const confirmed = window.confirm('重新產生後，先前記下的啟用碼會立即失效。確定繼續嗎？')
    if (!confirmed) return

    setUpdating(true)
    setNotice(null)
    try {
      const result = await regenerateStudentActivation({
        studentId: editingStudent.id,
        studentIdCode: editingStudent.studentId,
      })
      setActivation({
        kind: 'activation',
        fullName: editingStudent.fullName,
        studentId: editingStudent.studentId,
        code: result.activation.code,
        expiresAt: result.activation.expiresAt,
      })
      setNotice({ type: 'success', message: '新啟用碼已產生，舊碼已失效。' })
    } catch (error) {
      setNotice({ type: 'error', message: error.message })
    } finally {
      setUpdating(false)
    }
  }

  async function createPasswordReset() {
    if (!editingStudent || !editingStudent.activated) return
    const confirmed = window.confirm('產生新重設碼後，先前的重設碼會失效；學生目前的密碼在完成重設前仍可使用。確定繼續嗎？')
    if (!confirmed) return

    setUpdating(true)
    setNotice(null)
    try {
      const result = await createStudentPasswordReset({
        studentId: editingStudent.id,
        studentIdCode: editingStudent.studentId,
      })
      setActivation({
        kind: 'password-reset',
        fullName: editingStudent.fullName,
        studentId: editingStudent.studentId,
        code: result.passwordReset.code,
        expiresAt: result.passwordReset.expiresAt,
      })
      setNotice({ type: 'success', message: '密碼重設碼已產生，有效期限為 24 小時。' })
    } catch (error) {
      setNotice({ type: 'error', message: error.message })
    } finally {
      setUpdating(false)
    }
  }

  return (
    <section className="student-management">
      <div className="student-page-heading">
        <div>
          <p className="eyebrow">STUDENTS & GROUPS</p>
          <h2>學生與分組</h2>
          <p>數學與英語分開設定，其他科目自動視為共同作業。</p>
        </div>
        <label className="term-picker">
          <span>查看學期</span>
          <select value={termId} onChange={(event) => { setTermId(event.target.value); setEditingStudent(null); setActivation(null) }}>
            {dashboard.terms.map((term) => (
              <option value={term.id} key={term.id}>第 {term.semester} 學期</option>
            ))}
          </select>
        </label>
      </div>

      {notice && <div className={`admin-notice is-${notice.type}`}>{notice.message}</div>}

      {activation && (
        <div className="activation-result">
          <span className="activation-result-icon"><KeyRound aria-hidden="true" /></span>
          <div>
            <p>{activation.kind === 'password-reset' ? '請交給學生於登入頁自行設定新密碼，關閉後不再顯示明碼' : '請立即交給學生，關閉後不再顯示明碼'}</p>
            <h3>{activation.fullName}・學號 {activation.studentId}</h3>
            <strong>{activation.code}</strong>
          </div>
          <button type="button" onClick={copyActivation}><Clipboard aria-hidden="true" />複製</button>
          <button className="activation-close" type="button" onClick={() => setActivation(null)}>我已記下</button>
        </div>
      )}

      {editingStudent && editForm && (
        <section className="student-settings-panel">
          <div className="student-settings-heading">
            <div><span><Settings2 aria-hidden="true" /></span><div><h3>{editingStudent.seatNumber} 號・{editingStudent.fullName}</h3><p>第 {selectedTerm?.semester} 學期設定</p></div></div>
            <button type="button" onClick={() => setEditingStudent(null)}>關閉</button>
          </div>

          <div className="student-settings-grid">
            <label><span>數學分組</span><select value={editForm.mathGroup} onChange={(event) => setEditForm({ ...editForm, mathGroup: event.target.value })}><option value="A">數學 A 組</option><option value="B">數學 B 組</option></select></label>
            <label><span>英語分組</span><select value={editForm.englishGroup} onChange={(event) => setEditForm({ ...editForm, englishGroup: event.target.value })}><option value="A">英語 A 組</option><option value="B">英語 B 組</option></select></label>
            <label className="homework-leader-toggle">
              <input type="checkbox" checked={editForm.isHomeworkLeader} onChange={(event) => setEditForm({ ...editForm, isHomeworkLeader: event.target.checked })} />
              <span><strong>全班作業長</strong><small>可協助輸入各科作業內容</small></span>
            </label>
          </div>

          <fieldset className="helper-subject-fieldset">
            <legend>各科小老師</legend>
            <div className="helper-group-selects">
              {dashboard.classSubjects.filter((subject) => ['math', 'english'].includes(subject.code)).map((subject) => {
                const assignment = editForm.helperAssignments.find((item) => item.classSubjectId === subject.id)
                return <label key={subject.id}><span>{subject.name}分組小老師</span><select value={assignment?.targetGroupCode || ''} onChange={(event) => setGroupedHelperSubject(subject.id, event.target.value)}><option value="">未設定</option><option value="A">{subject.name} A 組小老師</option><option value="B">{subject.name} B 組小老師</option></select></label>
              })}
            </div>
            <div className="subject-options">
              {dashboard.classSubjects.filter((subject) => !['math', 'english'].includes(subject.code)).map((subject) => {
                const checked = editForm.helperAssignments.some((item) => item.classSubjectId === subject.id)
                return <label className={checked ? 'is-checked' : ''} key={subject.id}><input type="checkbox" checked={checked} onChange={() => toggleHelperSubject(subject.id)} /><span>{checked && <CheckCircle2 aria-hidden="true" />}{subject.name}</span></label>
              })}
            </div>
          </fieldset>

          <div className="student-settings-actions">
            {!editingStudent.activated && <button className="regenerate-button" type="button" disabled={updating} onClick={regenerateActivation}><RotateCcw aria-hidden="true" />重新產生啟用碼</button>}
            {editingStudent.activated && <button className="regenerate-button" type="button" disabled={updating} onClick={createPasswordReset}><KeyRound aria-hidden="true" />產生密碼重設碼</button>}
            <button className="approve-button" type="button" disabled={updating} onClick={saveSettings}><Save aria-hidden="true" />{updating ? '儲存中…' : '儲存本學期設定'}</button>
          </div>
        </section>
      )}

      <div className="student-layout-grid">
        <form className="student-create-panel" onSubmit={handleSubmit} noValidate>
          <div className="student-panel-title">
            <span><UserPlus aria-hidden="true" /></span>
            <div><h3>新增一位學生</h3><p>建立後產生一次性啟用碼</p></div>
          </div>

          <div className="student-form-grid">
            <label>
              <span>座號</span>
              <input type="number" min="1" max="99" value={form.seatNumber} onChange={(event) => update('seatNumber', event.target.value)} placeholder="例如：1" />
              <FieldError message={errors.seatNumber} />
            </label>
            <label>
              <span>學生學號</span>
              <input inputMode="numeric" value={form.studentId} onChange={(event) => update('studentId', event.target.value)} placeholder="請輸入學號" />
              <FieldError message={errors.studentId} />
            </label>
          </div>

          <label className="student-wide-field">
            <span>學生姓名</span>
            <input value={form.fullName} onChange={(event) => update('fullName', event.target.value)} placeholder="請輸入姓名" />
            <FieldError message={errors.fullName} />
          </label>

          <div className="student-form-grid group-select-grid">
            <label>
              <span>數學分組</span>
              <select value={form.mathGroup} onChange={(event) => update('mathGroup', event.target.value)}>
                <option value="A">數學 A 組</option>
                <option value="B">數學 B 組</option>
              </select>
            </label>
            <label>
              <span>英語分組</span>
              <select value={form.englishGroup} onChange={(event) => update('englishGroup', event.target.value)}>
                <option value="A">英語 A 組</option>
                <option value="B">英語 B 組</option>
              </select>
            </label>
          </div>

          <div className="student-form-note">
            分組套用至第 {selectedTerm?.semester || '－'} 學期；不同學期可重新調整。
          </div>

          <button className="approve-button" type="submit" disabled={saving || !termId}>
            <Plus aria-hidden="true" />{saving ? '建立中…' : '建立學生並產生啟用碼'}
          </button>
        </form>

        <section className="student-list-panel">
          <div className="student-list-heading">
            <div><span><Users aria-hidden="true" /></span><div><h3>學生名單</h3><p>共 {students.length} 人</p></div></div>
            <button type="button" aria-label="重新整理學生名單" onClick={load}><RefreshCw aria-hidden="true" /></button>
          </div>

          {loading && <div className="student-list-empty"><RefreshCw className="is-spinning" aria-hidden="true" />讀取中…</div>}
          {!loading && !students.length && (
            <div className="student-list-empty"><Users aria-hidden="true" /><strong>尚未建立學生</strong><span>可先手動建立一位，之後再加入批次匯入。</span></div>
          )}
          {!loading && students.length > 0 && (
            <div className="student-table-wrap">
              <table>
                <thead><tr><th>座號</th><th>姓名／學號</th><th>數學</th><th>英語</th><th>幹部</th><th>帳號</th><th></th></tr></thead>
                <tbody>
                  {students.map((student) => (
                    <tr key={student.id}>
                      <td><strong>{student.seatNumber}</strong></td>
                      <td><span>{student.fullName}</span><small>{student.studentId}</small></td>
                      <td><span className={`group-badge is-${student.mathGroup.toLowerCase()}`}>{student.mathGroup}</span></td>
                      <td><span className={`group-badge is-${student.englishGroup.toLowerCase()}`}>{student.englishGroup}</span></td>
                      <td>{student.isHomeworkLeader || student.helperAssignments.length ? <span className="helper-count">{student.isHomeworkLeader ? '作業長' : `${student.helperAssignments.length} 項`}</span> : '－'}</td>
                      <td>{student.activated ? <span className="activation-status is-done"><CheckCircle2 aria-hidden="true" />已啟用</span> : <span className="activation-status">未啟用</span>}</td>
                      <td><button className="student-settings-button" type="button" onClick={() => startEditing(student)}><Settings2 aria-hidden="true" />設定</button></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>
      </div>
    </section>
  )
}
