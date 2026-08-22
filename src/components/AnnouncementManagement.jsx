import { useCallback, useEffect, useRef, useState } from 'react'
import {
  BellRing,
  CalendarClock,
  Eye,
  EyeOff,
  ImagePlus,
  Megaphone,
  Pencil,
  RefreshCw,
  Save,
  Send,
  Trash2,
  Users,
  X,
} from 'lucide-react'
import {
  createAnnouncement,
  deactivateAnnouncement,
  loadAdminAnnouncements,
  updateAnnouncement,
} from '../services/announcementService.js'

function formatDateTime(value) {
  if (!value) return '未設定'
  return new Intl.DateTimeFormat('zh-TW', {
    month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hour12: false,
  }).format(new Date(value))
}

function toDateTimeLocal(value) {
  if (!value) return ''
  const date = new Date(value)
  if (!Number.isFinite(date.getTime())) return ''
  const localDate = new Date(date.getTime() - date.getTimezoneOffset() * 60 * 1000)
  return localDate.toISOString().slice(0, 16)
}

const emptyForm = {
  scope: 'class',
  title: '',
  content: '',
  expiresAt: '',
  imageAltText: '',
}

export default function AnnouncementManagement({ dashboard, onNotice }) {
  const [announcements, setAnnouncements] = useState([])
  const [form, setForm] = useState(emptyForm)
  const [imageFile, setImageFile] = useState(null)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [deactivatingId, setDeactivatingId] = useState('')
  const [editingAnnouncement, setEditingAnnouncement] = useState(null)
  const [removeExistingImage, setRemoveExistingImage] = useState(false)
  const fileInputRef = useRef(null)
  const formPanelRef = useRef(null)

  const load = useCallback(async () => {
    setLoading(true)
    try {
      setAnnouncements(await loadAdminAnnouncements({ classId: dashboard.classInfo.id }))
    } catch (error) {
      onNotice('error', error.message)
    } finally {
      setLoading(false)
    }
  }, [dashboard.classInfo.id, onNotice])

  useEffect(() => { load() }, [load])

  function resetForm() {
    setEditingAnnouncement(null)
    setRemoveExistingImage(false)
    setForm(emptyForm)
    setImageFile(null)
    if (fileInputRef.current) fileInputRef.current.value = ''
  }

  function startEditing(item) {
    setEditingAnnouncement(item)
    setRemoveExistingImage(false)
    setImageFile(null)
    if (fileInputRef.current) fileInputRef.current.value = ''
    setForm({
      scope: item.scope,
      title: item.title,
      content: item.content,
      expiresAt: toDateTimeLocal(item.expiresAt),
      imageAltText: item.imageAltText || item.title,
    })
    formPanelRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }

  async function submit(event) {
    event.preventDefault()
    setSaving(true)
    try {
      if (editingAnnouncement) {
        await updateAnnouncement({
          announcementId: editingAnnouncement.id,
          classId: dashboard.classInfo.id,
          ...form,
          imageFile,
          existingImagePath: editingAnnouncement.imagePath,
          previousExpiresAt: editingAnnouncement.expiresAt,
          removeImage: removeExistingImage,
        })
      } else {
        await createAnnouncement({ classId: dashboard.classInfo.id, ...form, imageFile })
      }
      const noticeTitle = form.title.trim()
      const wasEditing = Boolean(editingAnnouncement)
      resetForm()
      await load()
      onNotice('success', `公告「${noticeTitle}」已${wasEditing ? '更新' : '發布'}。`)
    } catch (error) {
      onNotice('error', error.message)
    } finally {
      setSaving(false)
    }
  }

  async function deactivate(item) {
    if (!window.confirm(`確定要下架公告「${item.title}」嗎？`)) return
    setDeactivatingId(item.id)
    try {
      await deactivateAnnouncement(item.id)
      if (editingAnnouncement?.id === item.id) resetForm()
      await load()
      onNotice('success', `公告「${item.title}」已下架。`)
    } catch (error) {
      onNotice('error', error.message)
    } finally {
      setDeactivatingId('')
    }
  }

  return (
    <section className="announcement-management">
      <div className="student-page-heading">
        <div>
          <p className="eyebrow">ANNOUNCEMENTS</p>
          <h2>公告管理</h2>
          <p>發布全校或班級公告，並查看學生已讀狀況。</p>
        </div>
      </div>

      <div className="announcement-layout-grid">
        <form ref={formPanelRef} className={`announcement-create-panel${editingAnnouncement ? ' is-editing' : ''}`} onSubmit={submit}>
          <div className="student-panel-title">
            <span><Megaphone aria-hidden="true" /></span>
            <div><h3>{editingAnnouncement ? '編輯公告' : '建立公告'}</h3><p>{editingAnnouncement ? '修改後會更新原公告，已讀紀錄會保留。' : '標題與公告類型為必填。'}</p></div>
          </div>

          <label><span>公告類型</span><select value={form.scope} onChange={(event) => setForm({ ...form, scope: event.target.value })}><option value="class">班級公告</option><option value="school">全校公告</option></select></label>
          <label><span>公告標題</span><input required maxLength="80" value={form.title} placeholder="請輸入公告標題" onChange={(event) => setForm({ ...form, title: event.target.value })} /></label>
          <label><span>公告內容</span><textarea rows="5" maxLength="2000" value={form.content} placeholder="請輸入公告內容" onChange={(event) => setForm({ ...form, content: event.target.value })} /></label>
          <label><span>到期時間（選填）</span><input type="datetime-local" value={form.expiresAt} onChange={(event) => setForm({ ...form, expiresAt: event.target.value })} /></label>

          <label className="announcement-image-field">
            <span><ImagePlus aria-hidden="true" />公告圖片（選填）</span>
            <input ref={fileInputRef} type="file" accept="image/jpeg,image/png,image/webp" onChange={(event) => { setImageFile(event.target.files?.[0] || null); setRemoveExistingImage(false) }} />
            <small>接受 JPG、PNG、WebP，檔案上限 5 MB。</small>
          </label>
          {editingAnnouncement?.imagePath && !imageFile && (
            <div className={`announcement-existing-image${removeExistingImage ? ' is-removing' : ''}`}>
              {editingAnnouncement.imageUrl && !removeExistingImage && <img src={editingAnnouncement.imageUrl} alt={editingAnnouncement.imageAltText} />}
              <div>
                <strong>{removeExistingImage ? '儲存後將移除原圖片' : '目前公告圖片'}</strong>
                <button type="button" onClick={() => setRemoveExistingImage((value) => !value)}>
                  {removeExistingImage ? <><X />取消移除</> : <><Trash2 />移除圖片</>}
                </button>
              </div>
            </div>
          )}
          {(imageFile || (editingAnnouncement?.imagePath && !removeExistingImage)) && <label><span>圖片說明（選填）</span><input maxLength="100" value={form.imageAltText} placeholder="例如：校外教學通知單" onChange={(event) => setForm({ ...form, imageAltText: event.target.value })} /></label>}

          <div className="announcement-form-actions">
            <button className="approve-button" type="submit" disabled={saving || !form.title.trim()}>{editingAnnouncement ? <Save aria-hidden="true" /> : <Send aria-hidden="true" />}{saving ? '儲存中…' : editingAnnouncement ? '儲存修改' : '發布公告'}</button>
            {editingAnnouncement && <button className="announcement-edit-cancel" type="button" disabled={saving} onClick={resetForm}><X aria-hidden="true" />取消編輯</button>}
          </div>
        </form>

        <section className="announcement-list-panel">
          <div className="student-list-heading">
            <div><span><BellRing aria-hidden="true" /></span><div><h3>公告清單</h3><p>已讀統計以目前在班學生計算。</p></div></div>
            <button type="button" aria-label="重新整理公告清單" title="重新整理" disabled={loading} onClick={load}><RefreshCw className={loading ? 'is-spinning' : ''} aria-hidden="true" /></button>
          </div>

          {loading && <div className="admin-loading"><RefreshCw className="is-spinning" />正在讀取公告…</div>}
          {!loading && !announcements.length && <div className="student-list-empty"><Megaphone /><strong>尚未發布公告</strong><span>第一則公告發布後會顯示在這裡。</span></div>}

          <div className="announcement-admin-list">
            {announcements.map((item) => (
              <article className={!item.isActive ? 'is-inactive' : ''} key={item.id}>
                {item.imageUrl && <img src={item.imageUrl} alt={item.imageAltText} />}
                {item.imageError && <p className="private-image-error">{item.imageError}</p>}
                <div className="announcement-admin-body">
                  <div className="announcement-admin-topline">
                    <span className={`announcement-scope is-${item.scope}`}>{item.scope === 'school' ? '全校公告' : '班級公告'}</span>
                    <div className="announcement-admin-dates"><span><CalendarClock />發布：{formatDateTime(item.publishedAt)}</span><span>到期：{formatDateTime(item.expiresAt)}</span>{!item.isActive && <span className="announcement-inactive">已下架</span>}</div>
                  </div>
                  <h3>{item.title}</h3>
                  {item.content && <p>{item.content}</p>}
                  <div className="announcement-read-summary"><span><Eye />已讀 {item.readStudents.length} 人</span><span><EyeOff />未讀 {item.unreadStudents.length} 人</span></div>
                  <details className="announcement-read-details">
                    <summary><Users />查看已讀與未讀名單</summary>
                    <div><strong>已讀</strong><p>{item.readStudents.length ? item.readStudents.map((student) => `${student.seatNumber} 號 ${student.fullName}`).join('、') : '尚無學生已讀'}</p></div>
                    <div><strong>未讀</strong><p>{item.unreadStudents.length ? item.unreadStudents.map((student) => `${student.seatNumber} 號 ${student.fullName}`).join('、') : '全班皆已讀'}</p></div>
                  </details>
                  <div className="announcement-admin-actions">
                    <button className="announcement-edit-button" type="button" disabled={saving} onClick={() => startEditing(item)}><Pencil />編輯公告</button>
                    {item.isActive && <button className="announcement-deactivate-button" type="button" disabled={deactivatingId === item.id} onClick={() => deactivate(item)}><EyeOff />{deactivatingId === item.id ? '下架中…' : '下架公告'}</button>}
                  </div>
                </div>
              </article>
            ))}
          </div>
        </section>
      </div>
    </section>
  )
}
