import { useCallback, useEffect, useState } from 'react'
import {
  Award,
  CalendarDays,
  Eye,
  EyeOff,
  Medal,
  Pencil,
  RefreshCw,
  Save,
  Trash2,
  Trophy,
  X,
} from 'lucide-react'
import {
  createHonorEntries,
  deleteHonorGroup,
  loadAdminHonors,
  setHonorVisibility,
  updateHonorGroup,
} from '../services/honorService.js'

function todayString() {
  const now = new Date()
  return new Date(now.getTime() - now.getTimezoneOffset() * 60_000).toISOString().slice(0, 10)
}

const emptyForm = () => ({ studentIds: [], title: '', description: '', awardedOn: todayString() })

export default function HonorManagement({ dashboard, onNotice }) {
  const [honors, setHonors] = useState([])
  const [students, setStudents] = useState([])
  const [form, setForm] = useState(emptyForm)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [visibilityId, setVisibilityId] = useState('')
  const [deletingId, setDeletingId] = useState('')
  const [editingGroupId, setEditingGroupId] = useState('')

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const data = await loadAdminHonors({ classId: dashboard.classInfo.id })
      setHonors(data.honors)
      setStudents(data.students)
    } catch (error) {
      onNotice('error', error.message)
    } finally {
      setLoading(false)
    }
  }, [dashboard.classInfo.id, onNotice])

  useEffect(() => { load() }, [load])

  function toggleStudent(studentId) {
    setForm((current) => ({
      ...current,
      studentIds: current.studentIds.includes(studentId)
        ? current.studentIds.filter((id) => id !== studentId)
        : [...current.studentIds, studentId],
    }))
  }

  async function submit(event) {
    event.preventDefault()
    setSaving(true)
    try {
      if (editingGroupId) {
        await updateHonorGroup({ honorGroupId: editingGroupId, ...form })
      } else {
        await createHonorEntries({ classId: dashboard.classInfo.id, ...form })
      }
      const selectedNames = students
        .filter((item) => form.studentIds.includes(item.id))
        .map((item) => item.fullName)
      const title = form.title.trim()
      setForm(emptyForm())
      const wasEditing = Boolean(editingGroupId)
      setEditingGroupId('')
      await load()
      onNotice('success', wasEditing
        ? `已更新 ${selectedNames.join('、')}的「${title}」榮譽紀錄。`
        : `已新增 ${selectedNames.join('、')}的「${title}」榮譽紀錄。`)
    } catch (error) {
      onNotice('error', error.message)
    } finally {
      setSaving(false)
    }
  }

  function startEditing(item) {
    setEditingGroupId(item.honorGroupId)
    setForm({
      studentIds: [...item.studentIds],
      title: item.title,
      description: item.description,
      awardedOn: item.awardedOn,
    })
    document.querySelector('.honor-create-panel')?.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }

  function cancelEditing() {
    setEditingGroupId('')
    setForm(emptyForm())
  }

  async function toggleVisibility(item) {
    if (item.isVisible && !window.confirm(`確定要隱藏「${item.studentDisplayNames.join('、')}－${item.title}」嗎？`)) return
    setVisibilityId(item.id)
    try {
      await setHonorVisibility({ honorGroupId: item.honorGroupId, isVisible: !item.isVisible })
      await load()
      onNotice('success', item.isVisible ? '榮譽紀錄已隱藏。' : '榮譽紀錄已重新顯示。')
    } catch (error) {
      onNotice('error', error.message)
    } finally {
      setVisibilityId('')
    }
  }

  async function removeHonor(item) {
    const label = `${item.studentDisplayNames.join('、')}－${item.title}`
    if (!window.confirm(`確定要永久刪除「${label}」嗎？刪除後無法復原。`)) return
    setDeletingId(item.id)
    try {
      await deleteHonorGroup({ honorGroupId: item.honorGroupId })
      if (editingGroupId === item.honorGroupId) cancelEditing()
      await load()
      onNotice('success', `榮譽紀錄「${label}」已刪除。`)
    } catch (error) {
      onNotice('error', error.message)
    } finally {
      setDeletingId('')
    }
  }

  return (
    <section className="honor-management">
      <div className="student-page-heading">
        <div><p className="eyebrow">HONOR ROLL</p><h2>榮譽榜管理</h2><p>向全班公開學生姓名、榮譽事蹟與日期。</p></div>
      </div>

      <div className="honor-layout-grid">
        <form className="honor-create-panel" onSubmit={submit}>
          <div className="student-panel-title"><span>{editingGroupId ? <Pencil /> : <Trophy />}</span><div><h3>{editingGroupId ? '編輯榮譽紀錄' : '新增榮譽紀錄'}</h3><p>{editingGroupId ? '可修正學生名單、內容與日期。' : '不會顯示成績或缺交資料。'}</p></div></div>
          <fieldset className="honor-student-fieldset">
            <legend>獲獎學生（可複選）</legend>
            <div className="honor-student-picker-actions"><button type="button" onClick={() => setForm({ ...form, studentIds: students.map((student) => student.id) })}>全選</button><button type="button" onClick={() => setForm({ ...form, studentIds: [] })}>清除</button></div>
            <div className="honor-student-options">
              {students.map((student) => {
                const checked = form.studentIds.includes(student.id)
                return <label className={checked ? 'is-checked' : ''} key={student.id}><input type="checkbox" checked={checked} onChange={() => toggleStudent(student.id)} /><span>{student.seatNumber} 號　{student.fullName}</span></label>
              })}
            </div>
            <small>已選擇 {form.studentIds.length} 位學生</small>
          </fieldset>
          <label><span>榮譽名稱</span><input required maxLength="80" value={form.title} placeholder="例如：校內作文比賽第一名" onChange={(event) => setForm({ ...form, title: event.target.value })} /></label>
          <label><span>榮譽事蹟（選填）</span><textarea rows="5" maxLength="1000" value={form.description} placeholder="簡要說明獲獎事蹟" onChange={(event) => setForm({ ...form, description: event.target.value })} /></label>
          <label><span>榮譽日期</span><input required type="date" value={form.awardedOn} onChange={(event) => setForm({ ...form, awardedOn: event.target.value })} /></label>
          <div className="honor-form-actions">
            {editingGroupId && <button className="secondary-button" type="button" disabled={saving} onClick={cancelEditing}><X />取消編輯</button>}
            <button className="approve-button" type="submit" disabled={saving || !form.studentIds.length || !form.title.trim()}><Save />{saving ? '儲存中…' : editingGroupId ? '儲存榮譽變更' : '加入榮譽榜'}</button>
          </div>
        </form>

        <section className="honor-list-panel">
          <div className="student-list-heading"><div><span><Medal /></span><div><h3>榮譽紀錄</h3><p>隱藏後學生端將不再顯示。</p></div></div><button type="button" aria-label="重新整理榮譽紀錄" title="重新整理" disabled={loading} onClick={load}><RefreshCw className={loading ? 'is-spinning' : ''} /></button></div>
          {loading && <div className="admin-loading"><RefreshCw className="is-spinning" />正在讀取榮譽榜…</div>}
          {!loading && !honors.length && <div className="student-list-empty"><Award /><strong>尚無榮譽紀錄</strong><span>新增後會顯示在全班學生首頁。</span></div>}
          <div className="honor-admin-list">
            {honors.map((item) => (
              <article className={`${!item.isVisible ? 'is-hidden' : ''}${editingGroupId === item.honorGroupId ? ' is-editing' : ''}`} key={item.id}>
                <span className="honor-medal"><Medal /></span>
                <div className="honor-admin-body">
                  <div className="honor-student-names">{item.studentDisplayNames.map((name, index) => <span className="honor-student-name" key={item.studentIds[index]}>{name}</span>)}{!item.isVisible && <span className="honor-hidden-label">已隱藏</span>}</div>
                  <h3>{item.title}</h3>
                  {item.description && <p>{item.description}</p>}
                  <small><CalendarDays />{item.awardedOn}</small>
                </div>
                <div className="honor-card-actions">
                  <button type="button" disabled={saving} onClick={() => startEditing(item)}><Pencil />編輯</button>
                  <button type="button" disabled={visibilityId === item.id} onClick={() => toggleVisibility(item)}>{item.isVisible ? <EyeOff /> : <Eye />}{visibilityId === item.id ? '處理中…' : item.isVisible ? '隱藏' : '重新顯示'}</button>
                  <button className="is-danger" type="button" disabled={deletingId === item.id} onClick={() => removeHonor(item)}><Trash2 />{deletingId === item.id ? '刪除中…' : '刪除'}</button>
                </div>
              </article>
            ))}
          </div>
        </section>
      </div>
    </section>
  )
}
