import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import {
  ArrowDown,
  ArrowUp,
  BookOpenText,
  Eye,
  EyeOff,
  ImagePlus,
  Pencil,
  Pin,
  PlayCircle,
  RefreshCw,
  RotateCcw,
  Save,
  Trash2,
  X,
} from 'lucide-react'
import {
  deleteLearningResource,
  loadManagedLearningResources,
  saveLearningResource,
  saveLearningResourceOrder,
  setLearningResourceActive,
  videoEmbedInfo,
} from '../services/learningResourceService.js'
import LearningResourceCard from './LearningResourceCard.jsx'
import { learningResourceAudienceOptionsForSubject } from '../lib/learningResourceAudiences.js'

function localDateTimeString(value = new Date()) {
  const date = value instanceof Date ? value : new Date(value)
  const local = new Date(date.getTime() - date.getTimezoneOffset() * 60_000)
  return local.toISOString().slice(0, 16)
}

function emptyForm(defaultSubjectId = '') {
  return {
    resourceType: 'method',
    contentType: 'external',
    classSubjectId: defaultSubjectId,
    audienceScope: 'common',
    title: '',
    summary: '',
    articleBody: '',
    contentUrl: '',
    sourceName: '',
    sourceUrl: '',
    imageAltText: '',
    publishedAt: localDateTimeString(),
    isPinned: false,
  }
}

function formatDate(value) {
  return new Intl.DateTimeFormat('zh-TW', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).format(new Date(value))
}

export default function LearningResourceManagement({
  dashboard,
  onNotice,
  teacherMode = false,
}) {
  const defaultSubjectId = teacherMode ? dashboard.classSubjects[0]?.id || '' : ''
  const [resources, setResources] = useState([])
  const [form, setForm] = useState(() => emptyForm(defaultSubjectId))
  const [editing, setEditing] = useState(null)
  const [imageFile, setImageFile] = useState(null)
  const [imagePreview, setImagePreview] = useState('')
  const [removeImage, setRemoveImage] = useState(false)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [workingId, setWorkingId] = useState('')
  const fileInputRef = useRef(null)

  const load = useCallback(async () => {
    setLoading(true)
    try {
      setResources(await loadManagedLearningResources({
        classId: dashboard.classInfo.id,
        ownOnly: teacherMode,
      }))
    } catch (error) {
      onNotice('error', error.message)
    } finally {
      setLoading(false)
    }
  }, [dashboard.classInfo.id, onNotice, teacherMode])

  useEffect(() => { load() }, [load])

  useEffect(() => {
    if (!imageFile) {
      setImagePreview('')
      return undefined
    }
    const previewUrl = URL.createObjectURL(imageFile)
    setImagePreview(previewUrl)
    return () => URL.revokeObjectURL(previewUrl)
  }, [imageFile])

  function resetForm() {
    setForm(emptyForm(defaultSubjectId))
    setEditing(null)
    setImageFile(null)
    setImagePreview('')
    setRemoveImage(false)
    if (fileInputRef.current) fileInputRef.current.value = ''
  }

  async function submit(event) {
    event.preventDefault()
    if (teacherMode && !form.classSubjectId) {
      onNotice('error', '任課老師必須選擇獲授權的科目。')
      return
    }
    setSaving(true)
    try {
      await saveLearningResource({
        id: editing?.id,
        classId: dashboard.classInfo.id,
        ...form,
        contentType: form.resourceType === 'video' ? 'video' : form.contentType,
        imageFile,
        currentImagePath: editing?.imagePath,
        removeImage,
        sortOrder: editing?.sortOrder || 0,
      })
      const title = form.title.trim()
      resetForm()
      await load()
      onNotice('success', editing ? `學習資源「${title}」已更新。` : `學習資源「${title}」已發布。`)
    } catch (error) {
      onNotice('error', error.message)
    } finally {
      setSaving(false)
    }
  }

  function edit(resource) {
    setEditing(resource)
    setForm({
      resourceType: resource.resourceType,
      contentType: resource.contentType,
      classSubjectId: resource.classSubjectId || '',
      audienceScope: resource.audienceScope,
      title: resource.title,
      summary: resource.summary,
      articleBody: resource.articleBody,
      contentUrl: resource.contentUrl,
      sourceName: resource.sourceName,
      sourceUrl: resource.sourceUrl,
      imageAltText: resource.imageAltText,
      publishedAt: localDateTimeString(resource.publishedAt),
      isPinned: resource.isPinned,
    })
    setImageFile(null)
    setRemoveImage(false)
    if (fileInputRef.current) fileInputRef.current.value = ''
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  async function toggleActive(resource) {
    setWorkingId(resource.id)
    try {
      await setLearningResourceActive({
        resourceId: resource.id,
        isActive: !resource.isActive,
      })
      await load()
      onNotice('success', resource.isActive ? '學習資源已下架。' : '學習資源已恢復。')
    } catch (error) {
      onNotice('error', error.message)
    } finally {
      setWorkingId('')
    }
  }

  async function remove(resource) {
    if (!window.confirm(`確定永久刪除「${resource.title}」嗎？此操作無法復原。`)) return
    setWorkingId(resource.id)
    try {
      await deleteLearningResource(resource)
      if (editing?.id === resource.id) resetForm()
      await load()
      onNotice('success', `學習資源「${resource.title}」已刪除。`)
    } catch (error) {
      onNotice('error', error.message)
    } finally {
      setWorkingId('')
    }
  }

  async function move(resource, offset) {
    const sameGroup = resources.filter(
      (item) => item.resourceType === resource.resourceType && item.isPinned === resource.isPinned,
    )
    const index = sameGroup.findIndex((item) => item.id === resource.id)
    const target = index + offset
    if (index < 0 || target < 0 || target >= sameGroup.length) return
    const reordered = [...sameGroup]
    ;[reordered[index], reordered[target]] = [reordered[target], reordered[index]]
    setWorkingId(resource.id)
    try {
      await saveLearningResourceOrder(reordered.map((item) => item.id))
      await load()
      onNotice('success', '學習資源順序已更新。')
    } catch (error) {
      onNotice('error', error.message)
    } finally {
      setWorkingId('')
    }
  }

  const selectedSubject = dashboard.classSubjects.find(
    (subject) => subject.id === form.classSubjectId,
  ) || null
  const audienceOptions = useMemo(
    () => learningResourceAudienceOptionsForSubject(selectedSubject?.code),
    [selectedSubject?.code],
  )

  function changeSubject(classSubjectId) {
    const subject = dashboard.classSubjects.find((item) => item.id === classSubjectId)
    const nextAudienceOptions = learningResourceAudienceOptionsForSubject(subject?.code)
    setForm((current) => ({
      ...current,
      classSubjectId,
      audienceScope: nextAudienceOptions.some((option) => option.value === current.audienceScope)
        ? current.audienceScope
        : 'common',
    }))
  }

  const previewResource = useMemo(() => {
    const embed = form.resourceType === 'video'
      ? videoEmbedInfo(form.contentUrl)
      : { platform: null, embedUrl: null }
    return {
      resourceType: form.resourceType,
      contentType: form.resourceType === 'video' ? 'video' : form.contentType,
      audienceScope: form.audienceScope,
      audienceLabel: audienceOptions.find((option) => option.value === form.audienceScope)?.shortLabel || '共同',
      title: form.title,
      summary: form.summary,
      articleBody: form.articleBody,
      contentUrl: form.contentUrl,
      sourceName: form.sourceName,
      sourceUrl: form.sourceUrl,
      imageUrl: imagePreview || (!removeImage ? editing?.imageUrl : ''),
      imageAltText: form.imageAltText || form.title,
      publishedAt: form.publishedAt,
      isPinned: form.isPinned,
      subject: dashboard.classSubjects.find((subject) => subject.id === form.classSubjectId) || null,
      createdByDisplayName: teacherMode ? '任課老師' : '導師',
      videoPlatform: embed.platform,
      embedUrl: embed.embedUrl,
    }
  }, [audienceOptions, dashboard.classSubjects, editing, form, imagePreview, removeImage, teacherMode])

  return (
    <section className="learning-resource-management">
      <div className="student-page-heading">
        <div>
          <p className="eyebrow">LEARNING RESOURCES</p>
          <h2>學習資源管理</h2>
          <p>{teacherMode ? '發布獲授權科目的方法與影片，只能管理自己建立的內容。' : '發布通用或各科學習方法與影片，並管理全部教師內容。'}</p>
        </div>
      </div>

      <div className="learning-management-layout">
        <form className="learning-resource-form" onSubmit={submit}>
          <div className="student-panel-title">
            <span>{form.resourceType === 'video' ? <PlayCircle /> : <BookOpenText />}</span>
            <div><h3>{editing ? '編輯學習資源' : '建立學習資源'}</h3><p>網址與文章內容不會執行外部程式碼。</p></div>
          </div>

          <div className="learning-resource-form-grid">
            <label><span>資源類型</span><select value={form.resourceType} onChange={(event) => setForm((current) => ({ ...current, resourceType: event.target.value, contentType: event.target.value === 'video' ? 'video' : 'external' }))}><option value="method">學習方法</option><option value="video">學習影片</option></select></label>
            <label><span>科目</span><select required={teacherMode} value={form.classSubjectId} onChange={(event) => changeSubject(event.target.value)}>{!teacherMode && <option value="">通用</option>}{dashboard.classSubjects.map((subject) => <option value={subject.id} key={subject.id}>{subject.name}</option>)}</select></label>
            <label><span>顯示對象</span><select value={form.audienceScope} onChange={(event) => setForm({ ...form, audienceScope: event.target.value })}>{audienceOptions.map((option) => <option value={option.value} key={option.value}>{option.label}</option>)}</select><small>學生只會看到共同內容及符合本人分組的內容。</small></label>
            {form.resourceType === 'method' && <label><span>呈現方式</span><select value={form.contentType} onChange={(event) => setForm({ ...form, contentType: event.target.value })}><option value="external">外部文章連結</option><option value="article">站內文章</option></select></label>}
            <label><span>發布日期</span><input required type="datetime-local" value={form.publishedAt} onChange={(event) => setForm({ ...form, publishedAt: event.target.value })} /></label>
          </div>

          <label><span>標題</span><input required maxLength="120" value={form.title} placeholder="例如：考前一週如何安排複習" onChange={(event) => setForm({ ...form, title: event.target.value })} /></label>
          <label><span>內容簡介（選填）</span><textarea rows="3" maxLength="1000" value={form.summary} placeholder="簡短說明這份資源適合什麼情況" onChange={(event) => setForm({ ...form, summary: event.target.value })} /></label>

          {form.resourceType === 'method' && form.contentType === 'article'
            ? <label><span>站內文章內容</span><textarea required rows="12" maxLength="20000" value={form.articleBody} placeholder="可使用分段與條列方式輸入文章內容" onChange={(event) => setForm({ ...form, articleBody: event.target.value })} /></label>
            : <label><span>{form.resourceType === 'video' ? '影片網址' : '文章網址'}</span><input required type="url" value={form.contentUrl} placeholder={form.resourceType === 'video' ? 'https://www.youtube.com/watch?v=…' : 'https://…'} onChange={(event) => setForm({ ...form, contentUrl: event.target.value })} /></label>}

          <div className="learning-resource-form-grid">
            <label><span>作者／頻道／來源{form.contentType === 'article' ? '' : '（選填）'}</span><input required={form.contentType === 'article'} maxLength="100" value={form.sourceName} placeholder="例如：陳老師整理" onChange={(event) => setForm({ ...form, sourceName: event.target.value })} /></label>
            <label><span>原始出處網址（選填）</span><input type="url" value={form.sourceUrl} placeholder="https://…" onChange={(event) => setForm({ ...form, sourceUrl: event.target.value })} /></label>
          </div>

          <label className="announcement-image-field">
            <span><ImagePlus />封面圖片（選填）</span>
            <input ref={fileInputRef} type="file" accept="image/jpeg,image/png,image/webp" onChange={(event) => { setImageFile(event.target.files?.[0] || null); setRemoveImage(false) }} />
            <small>接受 JPG、PNG、WebP，檔案上限 5 MB。</small>
          </label>
          {(imageFile || (editing?.imagePath && !removeImage)) && <label><span>圖片說明（選填）</span><input maxLength="120" value={form.imageAltText} onChange={(event) => setForm({ ...form, imageAltText: event.target.value })} /></label>}
          {editing?.imagePath && !imageFile && <label className="learning-resource-checkbox"><input type="checkbox" checked={removeImage} onChange={(event) => setRemoveImage(event.target.checked)} /><span>移除原有封面圖片</span></label>}
          <label className="learning-resource-checkbox"><input type="checkbox" checked={form.isPinned} onChange={(event) => setForm({ ...form, isPinned: event.target.checked })} /><span><Pin />置頂顯示</span></label>

          <div className="learning-resource-form-actions">
            {editing && <button className="secondary-button" type="button" disabled={saving} onClick={resetForm}><X />取消編輯</button>}
            <button className="approve-button" type="submit" disabled={saving || !form.title.trim()}><Save />{saving ? '儲存中…' : editing ? '儲存變更' : '發布學習資源'}</button>
          </div>
        </form>

        <section className="learning-resource-preview">
          <div className="student-list-heading"><div><span><Eye /></span><div><h3>學生畫面預覽</h3><p>實際內容會依學生螢幕寬度調整。</p></div></div></div>
          {form.title.trim()
            ? <LearningResourceCard resource={previewResource} preview />
            : <div className="student-list-empty"><BookOpenText /><strong>輸入標題後顯示預覽</strong></div>}
        </section>
      </div>

      <section className="learning-resource-admin-list-panel">
        <div className="student-list-heading">
          <div><span><BookOpenText /></span><div><h3>已建立資源</h3><p>{teacherMode ? '只顯示您建立的內容。' : '包含導師及任課老師建立的內容。'}</p></div></div>
          <button type="button" aria-label="重新整理學習資源" onClick={load} disabled={loading}><RefreshCw className={loading ? 'is-spinning' : ''} /></button>
        </div>
        {loading && <div className="admin-loading"><RefreshCw className="is-spinning" />正在讀取學習資源…</div>}
        {!loading && !resources.length && <div className="student-list-empty"><BookOpenText /><strong>尚未建立學習資源</strong><span>發布後會顯示在學生的「學習資源」頁面。</span></div>}
        <div className="learning-resource-admin-list">
          {resources.map((resource) => {
            const sameGroup = resources.filter(
              (item) => item.resourceType === resource.resourceType && item.isPinned === resource.isPinned,
            )
            const index = sameGroup.findIndex((item) => item.id === resource.id)
            return (
              <article className={!resource.isActive ? 'is-inactive' : ''} key={resource.id}>
                <div className="learning-resource-admin-meta">
                  <span>{resource.resourceType === 'video' ? '學習影片' : '學習方法'}</span>
                  <span>{resource.subject?.name || '通用'}</span>
                  <span>{resource.audienceLabel}</span>
                  {resource.isPinned && <span><Pin />置頂</span>}
                  {!resource.isActive && <span>已下架</span>}
                </div>
                <h3>{resource.title}</h3>
                <p>{resource.summary || '未填寫內容簡介'}</p>
                <small>{formatDate(resource.publishedAt)}・{resource.createdByDisplayName}</small>
                <div className="learning-resource-admin-actions">
                  <button type="button" title="上移" aria-label={`${resource.title}上移`} disabled={workingId || index === 0} onClick={() => move(resource, -1)}><ArrowUp /></button>
                  <button type="button" title="下移" aria-label={`${resource.title}下移`} disabled={workingId || index === sameGroup.length - 1} onClick={() => move(resource, 1)}><ArrowDown /></button>
                  <button type="button" disabled={workingId} onClick={() => edit(resource)}><Pencil />編輯</button>
                  <button type="button" disabled={workingId} onClick={() => toggleActive(resource)}>{resource.isActive ? <EyeOff /> : <RotateCcw />}{resource.isActive ? '下架' : '恢復'}</button>
                  <button className="is-danger" type="button" disabled={workingId} onClick={() => remove(resource)}><Trash2 />刪除</button>
                </div>
              </article>
            )
          })}
        </div>
      </section>
    </section>
  )
}
