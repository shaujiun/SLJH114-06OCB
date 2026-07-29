import { requireSupabase } from '../lib/supabase.js'
import { createClientId } from './announcementService.js'

const RESOURCE_BUCKET = 'contact-book-learning-resources'
const MAX_IMAGE_SIZE = 5 * 1024 * 1024
const ALLOWED_IMAGE_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp'])

function relation(value) {
  return Array.isArray(value) ? value[0] : value
}

function normalizeText(value) {
  return String(value || '').trim()
}

function extensionFor(file) {
  if (file.type === 'image/png') return 'png'
  if (file.type === 'image/webp') return 'webp'
  return 'jpg'
}

export function learningResourceUploadErrorMessage(error) {
  const status = Number(error?.statusCode || error?.status || 0)
  const message = String(error?.message || error?.error || '').toLowerCase()
  if (
    status === 401
    || status === 403
    || message.includes('row-level security')
    || message.includes('unauthorized')
  ) {
    return '封面圖片上傳權限驗證失敗，請通知系統管理員。'
  }
  if (status === 413 || message.includes('maximum allowed size') || message.includes('too large')) {
    return '封面圖片不可超過 5 MB。'
  }
  if (message.includes('mime type') || message.includes('content type')) {
    return '封面圖片只接受 JPG、PNG 或 WebP。'
  }
  return '封面圖片上傳失敗，請稍後再試。'
}

export function normalizeHttpUrl(value, { required = false } = {}) {
  const normalized = normalizeText(value)
  if (!normalized && !required) return ''
  let parsed
  try {
    parsed = new URL(normalized)
  } catch {
    throw new Error('網址格式不正確，請貼上完整的 http 或 https 網址。')
  }
  if (!['http:', 'https:'].includes(parsed.protocol)) {
    throw new Error('網址只接受 http 或 https。')
  }
  return parsed.toString()
}

export function videoEmbedInfo(value) {
  let url
  try {
    url = new URL(normalizeText(value))
  } catch {
    return { platform: 'external', embedUrl: null }
  }
  const host = url.hostname.replace(/^www\./, '').toLowerCase()

  if (host === 'youtu.be') {
    const id = url.pathname.split('/').filter(Boolean)[0]
    if (/^[\w-]{6,20}$/.test(id || '')) {
      return {
        platform: 'youtube',
        embedUrl: `https://www.youtube-nocookie.com/embed/${id}`,
      }
    }
  }

  if (host === 'youtube.com' || host === 'm.youtube.com') {
    const segments = url.pathname.split('/').filter(Boolean)
    const id = url.pathname === '/watch'
      ? url.searchParams.get('v')
      : ['shorts', 'embed', 'live'].includes(segments[0]) ? segments[1] : null
    if (/^[\w-]{6,20}$/.test(id || '')) {
      return {
        platform: 'youtube',
        embedUrl: `https://www.youtube-nocookie.com/embed/${id}`,
      }
    }
  }

  if (host === 'vimeo.com' || host === 'player.vimeo.com') {
    const id = url.pathname.split('/').filter(Boolean).find((part) => /^\d+$/.test(part))
    if (id) {
      return {
        platform: 'vimeo',
        embedUrl: `https://player.vimeo.com/video/${id}`,
      }
    }
  }

  if (host === 'instagram.com') {
    const match = url.pathname.match(/^\/(p|reel|tv)\/([^/]+)/)
    if (match) {
      return {
        platform: 'instagram',
        embedUrl: `https://www.instagram.com/${match[1]}/${match[2]}/embed/`,
      }
    }
  }

  if (host === 'facebook.com' || host === 'm.facebook.com' || host === 'fb.watch') {
    return {
      platform: 'facebook',
      embedUrl: `https://www.facebook.com/plugins/video.php?href=${encodeURIComponent(url.toString())}&show_text=false`,
    }
  }

  return { platform: 'external', embedUrl: null }
}

export function validateLearningResourceInput({
  resourceType,
  contentType,
  title,
  summary,
  articleBody,
  contentUrl,
  sourceName,
  sourceUrl,
  publishedAt,
  imageFile,
}) {
  const normalizedTitle = normalizeText(title)
  const normalizedSummary = normalizeText(summary)
  const normalizedArticle = normalizeText(articleBody)
  const normalizedSource = normalizeText(sourceName)
  if (!['method', 'video'].includes(resourceType)) throw new Error('請選擇學習資源類型。')
  const expectedTypes = resourceType === 'video' ? ['video'] : ['external', 'article']
  if (!expectedTypes.includes(contentType)) throw new Error('請選擇正確的內容形式。')
  if (!normalizedTitle || normalizedTitle.length > 120) throw new Error('標題必須為 1 至 120 個字。')
  if (normalizedSummary.length > 1000) throw new Error('內容簡介不可超過 1000 個字。')
  if (normalizedArticle.length > 20000) throw new Error('站內文章不可超過 20000 個字。')
  if (contentType === 'article' && !normalizedArticle) throw new Error('請輸入站內文章內容。')
  if (contentType === 'article' && !normalizedSource) throw new Error('站內文章必須填寫作者或資料來源。')
  const normalizedContentUrl = contentType === 'article'
    ? ''
    : normalizeHttpUrl(contentUrl, { required: true })
  const normalizedSourceUrl = normalizeHttpUrl(sourceUrl)
  const publishedDate = new Date(publishedAt)
  if (!publishedAt || Number.isNaN(publishedDate.getTime())) throw new Error('請設定正確的發布日期。')
  if (imageFile) {
    if (!ALLOWED_IMAGE_TYPES.has(imageFile.type)) throw new Error('封面圖片只接受 JPG、PNG 或 WebP。')
    if (imageFile.size > MAX_IMAGE_SIZE) throw new Error('封面圖片不可超過 5 MB。')
  }
  return {
    title: normalizedTitle,
    summary: normalizedSummary,
    articleBody: normalizedArticle,
    contentUrl: normalizedContentUrl,
    sourceName: normalizedSource,
    sourceUrl: normalizedSourceUrl,
    publishedAt: publishedDate.toISOString(),
  }
}

export function mapLearningResourceRow(row, imageUrl = null) {
  const classSubject = relation(row.class_subjects)
  const subject = relation(classSubject?.subjects)
  const creator = relation(row.contact_book_profiles)
  const embed = row.resource_type === 'video'
    ? videoEmbedInfo(row.content_url)
    : { platform: null, embedUrl: null }
  return {
    id: row.id,
    classId: row.class_id,
    classSubjectId: row.class_subject_id,
    resourceType: row.resource_type,
    contentType: row.content_type,
    title: row.title,
    summary: row.summary || '',
    articleBody: row.article_body || '',
    contentUrl: row.content_url || '',
    sourceName: row.source_name || '',
    sourceUrl: row.source_url || '',
    imagePath: row.image_path,
    imageAltText: row.image_alt_text || row.title,
    imageUrl,
    publishedAt: row.published_at,
    isPinned: row.is_pinned,
    sortOrder: row.sort_order,
    isActive: row.is_active,
    createdBy: row.created_by,
    createdByDisplayName: creator?.display_name || '老師',
    subject: classSubject?.id ? {
      id: classSubject.id,
      code: subject?.code,
      name: subject?.name,
    } : null,
    videoPlatform: embed.platform,
    embedUrl: embed.embedUrl,
  }
}

async function signedImageUrls(client, rows) {
  const paths = [...new Set((rows || []).map((row) => row.image_path).filter(Boolean))]
  if (!paths.length) return new Map()
  const { data, error } = await client.storage.from(RESOURCE_BUCKET).createSignedUrls(paths, 3600)
  if (error) return new Map()
  return new Map((data || []).map((item) => [item.path, item.signedUrl]))
}

const resourceSelect = `
  id,
  class_id,
  class_subject_id,
  resource_type,
  content_type,
  title,
  summary,
  article_body,
  content_url,
  source_name,
  source_url,
  image_path,
  image_alt_text,
  published_at,
  is_pinned,
  sort_order,
  is_active,
  created_by,
  class_subjects(id,subjects(id,code,name)),
  contact_book_profiles!learning_resources_created_by_fkey(display_name)
`

async function loadResourceRows(query) {
  const client = requireSupabase()
  const { data, error } = await query
  if (error) throw new Error('無法讀取學習資源，請重新整理後再試。')
  const rows = data || []
  const imageUrls = await signedImageUrls(client, rows)
  return rows.map((row) => mapLearningResourceRow(
    row,
    imageUrls.get(row.image_path) || null,
  ))
}

export async function loadManagedLearningResources({ classId, ownOnly = false }) {
  const client = requireSupabase()
  let query = client
    .from('learning_resources')
    .select(resourceSelect)
    .eq('class_id', classId)
    .order('is_pinned', { ascending: false })
    .order('sort_order')
    .order('published_at', { ascending: false })
  if (ownOnly) {
    const { data: userData, error: userError } = await client.auth.getUser()
    if (userError || !userData.user) throw new Error('登入狀態已失效，請重新登入。')
    query = query.eq('created_by', userData.user.id)
  }
  return loadResourceRows(query)
}

export async function loadStudentLearningResources({ classId }) {
  const client = requireSupabase()
  return loadResourceRows(
    client
      .from('learning_resources')
      .select(resourceSelect)
      .eq('class_id', classId)
      .eq('is_active', true)
      .lte('published_at', new Date().toISOString())
      .order('is_pinned', { ascending: false })
      .order('sort_order')
      .order('published_at', { ascending: false }),
  )
}

export async function saveLearningResource({
  id,
  classId,
  classSubjectId,
  resourceType,
  contentType,
  title,
  summary,
  articleBody,
  contentUrl,
  sourceName,
  sourceUrl,
  imageFile,
  imageAltText,
  currentImagePath,
  removeImage = false,
  publishedAt,
  isPinned,
  sortOrder = 0,
}) {
  const validated = validateLearningResourceInput({
    resourceType,
    contentType,
    title,
    summary,
    articleBody,
    contentUrl,
    sourceName,
    sourceUrl,
    publishedAt,
    imageFile,
  })
  const client = requireSupabase()
  const { data: userData, error: userError } = await client.auth.getUser()
  const userId = userData?.user?.id
  if (userError || !userId) throw new Error('登入狀態已失效，請重新登入。')

  const resourceId = id || createClientId()
  let nextImagePath = removeImage ? null : currentImagePath || null
  let uploadedImagePath = null
  if (imageFile) {
    uploadedImagePath = `${classId}/${userId}/${resourceId}/${createClientId()}.${extensionFor(imageFile)}`
    const { error: uploadError } = await client.storage
      .from(RESOURCE_BUCKET)
      .upload(uploadedImagePath, imageFile, {
        contentType: imageFile.type,
        upsert: false,
      })
    if (uploadError) throw new Error(learningResourceUploadErrorMessage(uploadError))
    nextImagePath = uploadedImagePath
  }

  const values = {
    class_id: classId,
    class_subject_id: classSubjectId || null,
    resource_type: resourceType,
    content_type: resourceType === 'video' ? 'video' : contentType,
    title: validated.title,
    summary: validated.summary || null,
    article_body: contentType === 'article' ? validated.articleBody : null,
    content_url: contentType === 'article' ? null : validated.contentUrl,
    source_name: validated.sourceName || null,
    source_url: validated.sourceUrl || null,
    image_path: nextImagePath,
    image_alt_text: nextImagePath ? normalizeText(imageAltText) || validated.title : null,
    published_at: validated.publishedAt,
    is_pinned: Boolean(isPinned),
    sort_order: Number.isInteger(sortOrder) ? sortOrder : 0,
    updated_by: userId,
  }

  const result = id
    ? await client.from('learning_resources').update(values).eq('id', id).select('id').single()
    : await client.from('learning_resources').insert({
      id: resourceId,
      ...values,
      created_by: userId,
    }).select('id').single()

  if (result.error) {
    if (uploadedImagePath) await client.storage.from(RESOURCE_BUCKET).remove([uploadedImagePath])
    const message = result.error.message || ''
    if (message.includes('row-level security') || result.error.code === '42501') {
      throw new Error('目前帳號沒有管理這個科目學習資源的權限。')
    }
    throw new Error(id ? '學習資源更新失敗，請稍後再試。' : '學習資源發布失敗，請稍後再試。')
  }

  if (
    currentImagePath
    && currentImagePath !== nextImagePath
  ) {
    await client.storage.from(RESOURCE_BUCKET).remove([currentImagePath])
  }
  return result.data
}

export async function setLearningResourceActive({ resourceId, isActive }) {
  const client = requireSupabase()
  const { data: userData, error: userError } = await client.auth.getUser()
  if (userError || !userData.user) throw new Error('登入狀態已失效，請重新登入。')
  const { error } = await client
    .from('learning_resources')
    .update({ is_active: isActive, updated_by: userData.user.id })
    .eq('id', resourceId)
  if (error) throw new Error(isActive ? '學習資源恢復失敗。' : '學習資源下架失敗。')
}

export async function deleteLearningResource(resource) {
  const client = requireSupabase()
  const { error } = await client.from('learning_resources').delete().eq('id', resource.id)
  if (error) throw new Error('學習資源刪除失敗，請稍後再試。')
  if (resource.imagePath) {
    await client.storage.from(RESOURCE_BUCKET).remove([resource.imagePath])
  }
}

export async function saveLearningResourceOrder(resourceIds) {
  const client = requireSupabase()
  const { error } = await client.rpc('save_learning_resource_order', {
    p_resource_ids: resourceIds,
  })
  if (error) throw new Error('學習資源順序儲存失敗，請稍後再試。')
}
