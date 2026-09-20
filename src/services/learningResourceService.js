import { requireSupabase } from '../lib/supabase.js'
import {
  isValidLearningResourceAudience,
  learningResourceAudienceLabel,
  normalizeLearningResourceAudience,
} from '../lib/learningResourceAudiences.js'
import { createClientId } from './announcementService.js'

const RESOURCE_BUCKET = 'contact-book-learning-resources'
const MAX_IMAGE_SIZE = 5 * 1024 * 1024
export const MAX_LEARNING_RESOURCE_IMAGES = 10
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

function normalizedImageFiles(imageFiles, imageFile) {
  if (Array.isArray(imageFiles)) return imageFiles.filter(Boolean)
  return imageFile ? [imageFile] : []
}

function storedImages(row) {
  const paths = Array.isArray(row.image_paths) && row.image_paths.length
    ? row.image_paths.filter(Boolean)
    : row.image_path ? [row.image_path] : []
  const altTexts = Array.isArray(row.image_alt_texts) ? row.image_alt_texts : []
  return paths.map((path, index) => ({
    path,
    altText: normalizeText(altTexts[index]) || (index === 0 ? normalizeText(row.image_alt_text) : '') || row.title,
  }))
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
    return '學習資源圖片上傳權限驗證失敗，請通知系統管理員。'
  }
  if (status === 413 || message.includes('maximum allowed size') || message.includes('too large')) {
    return '每張學習資源圖片不可超過 5 MB。'
  }
  if (message.includes('mime type') || message.includes('content type')) {
    return '學習資源圖片只接受 JPG、PNG 或 WebP。'
  }
  return '學習資源圖片上傳失敗，請稍後再試。'
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
  imageFiles,
  imageFile,
  existingImageCount = 0,
  audienceScope = 'common',
}) {
  const normalizedTitle = normalizeText(title)
  const normalizedSummary = normalizeText(summary)
  const normalizedArticle = normalizeText(articleBody)
  const normalizedSource = normalizeText(sourceName)
  const normalizedAudience = normalizeText(audienceScope).toLowerCase()
  if (!['method', 'video'].includes(resourceType)) throw new Error('請選擇學習資源類型。')
  const expectedTypes = resourceType === 'video' ? ['video'] : ['external', 'article']
  if (!expectedTypes.includes(contentType)) throw new Error('請選擇正確的內容形式。')
  if (!isValidLearningResourceAudience(normalizedAudience)) throw new Error('請選擇正確的顯示對象。')
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
  const files = normalizedImageFiles(imageFiles, imageFile)
  if (existingImageCount + files.length > MAX_LEARNING_RESOURCE_IMAGES) {
    throw new Error(`每篇學習資源最多可上傳 ${MAX_LEARNING_RESOURCE_IMAGES} 張圖片。`)
  }
  for (const file of files) {
    if (!ALLOWED_IMAGE_TYPES.has(file.type)) throw new Error('學習資源圖片只接受 JPG、PNG 或 WebP。')
    if (file.size > MAX_IMAGE_SIZE) throw new Error('每張學習資源圖片不可超過 5 MB。')
  }
  return {
    title: normalizedTitle,
    summary: normalizedSummary,
    articleBody: normalizedArticle,
    contentUrl: normalizedContentUrl,
    sourceName: normalizedSource,
    sourceUrl: normalizedSourceUrl,
    publishedAt: publishedDate.toISOString(),
    audienceScope: normalizedAudience,
  }
}

export function mapLearningResourceRow(row, imageUrls = new Map(), failedPaths = new Set()) {
  const classSubject = relation(row.class_subjects)
  const subject = relation(classSubject?.subjects)
  const creator = relation(row.contact_book_profiles)
  const embed = row.resource_type === 'video'
    ? videoEmbedInfo(row.content_url)
    : { platform: null, embedUrl: null }
  const urlMap = imageUrls instanceof Map ? imageUrls : new Map()
  const failedSet = failedPaths instanceof Set ? failedPaths : new Set()
  const legacyUrl = typeof imageUrls === 'string' ? imageUrls : null
  const legacyError = typeof failedPaths === 'string' ? failedPaths : ''
  const images = storedImages(row).map((image) => ({
    ...image,
    url: urlMap.get(image.path) || legacyUrl || null,
    error: failedSet.has(image.path)
      ? '學習資源圖片暫時無法讀取，請重新整理後再試。'
      : legacyError,
  }))
  const firstImage = images[0] || null
  return {
    id: row.id,
    classId: row.class_id,
    classSubjectId: row.class_subject_id,
    resourceType: row.resource_type,
    contentType: row.content_type,
    audienceScope: normalizeLearningResourceAudience(row.audience_scope),
    audienceLabel: learningResourceAudienceLabel(row.audience_scope, { short: true }),
    title: row.title,
    summary: row.summary || '',
    articleBody: row.article_body || '',
    contentUrl: row.content_url || '',
    sourceName: row.source_name || '',
    sourceUrl: row.source_url || '',
    images,
    imagePath: firstImage?.path || null,
    imageAltText: firstImage?.altText || row.title,
    imageUrl: firstImage?.url || null,
    imageError: firstImage?.error || '',
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
  const paths = [...new Set((rows || []).flatMap((row) => storedImages(row).map((image) => image.path)))]
  if (!paths.length) return { urls: new Map(), failedPaths: new Set() }
  const { data, error } = await client.storage.from(RESOURCE_BUCKET).createSignedUrls(paths, 3600)
  if (error) return { urls: new Map(), failedPaths: new Set(paths) }
  const urls = new Map((data || [])
    .filter((item) => item.path && item.signedUrl && !item.error)
    .map((item) => [item.path, item.signedUrl]))
  return {
    urls,
    failedPaths: new Set(paths.filter((path) => !urls.has(path))),
  }
}

async function uploadLearningResourceImages(client, {
  classId, userId, resourceId, imageFiles, imageAltTexts, title,
}) {
  const uploaded = []
  try {
    for (let index = 0; index < imageFiles.length; index += 1) {
      const file = imageFiles[index]
      const path = `${classId}/${userId}/${resourceId}/${createClientId()}.${extensionFor(file)}`
      const { error } = await client.storage
        .from(RESOURCE_BUCKET)
        .upload(path, file, { contentType: file.type, upsert: false })
      if (error) throw new Error(learningResourceUploadErrorMessage(error))
      uploaded.push({ path, altText: normalizeText(imageAltTexts[index]) || title })
    }
    return uploaded
  } catch (error) {
    if (uploaded.length) {
      await client.storage.from(RESOURCE_BUCKET).remove(uploaded.map((image) => image.path))
    }
    throw error
  }
}

const resourceSelect = `
  id,
  class_id,
  class_subject_id,
  resource_type,
  content_type,
  audience_scope,
  title,
  summary,
  article_body,
  content_url,
  source_name,
  source_url,
  image_path,
  image_alt_text,
  image_paths,
  image_alt_texts,
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
  const { urls: imageUrls, failedPaths } = await signedImageUrls(client, rows)
  return rows.map((row) => mapLearningResourceRow(row, imageUrls, failedPaths))
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
  imageFiles,
  imageFile,
  imageAltTexts = [],
  imageAltText,
  audienceScope = 'common',
  existingImages,
  currentImagePaths,
  currentImagePath,
  removeImage = false,
  publishedAt,
  isPinned,
  sortOrder = 0,
}) {
  const files = normalizedImageFiles(imageFiles, imageFile)
  const keptImages = Array.isArray(existingImages)
    ? existingImages.map((image) => ({ path: image.path, altText: normalizeText(image.altText) || title }))
    : removeImage || !currentImagePath
      ? []
      : [{ path: currentImagePath, altText: normalizeText(imageAltText) || title }]
  const previousPaths = Array.isArray(currentImagePaths)
    ? currentImagePaths.filter(Boolean)
    : currentImagePath ? [currentImagePath] : []
  const altTexts = imageAltTexts.length ? imageAltTexts : files.map(() => imageAltText || '')
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
    imageFiles: files,
    existingImageCount: keptImages.length,
    audienceScope,
  })
  const client = requireSupabase()
  const { data: userData, error: userError } = await client.auth.getUser()
  const userId = userData?.user?.id
  if (userError || !userId) throw new Error('登入狀態已失效，請重新登入。')

  const resourceId = id || createClientId()
  const uploadedImages = await uploadLearningResourceImages(client, {
    classId, userId, resourceId, imageFiles: files, imageAltTexts: altTexts, title: validated.title,
  })
  const images = [...keptImages, ...uploadedImages]
  const firstImage = images[0] || null

  const values = {
    class_id: classId,
    class_subject_id: classSubjectId || null,
    resource_type: resourceType,
    content_type: resourceType === 'video' ? 'video' : contentType,
    audience_scope: validated.audienceScope,
    title: validated.title,
    summary: validated.summary || null,
    article_body: contentType === 'article' ? validated.articleBody : null,
    content_url: contentType === 'article' ? null : validated.contentUrl,
    source_name: validated.sourceName || null,
    source_url: validated.sourceUrl || null,
    image_path: firstImage?.path || null,
    image_alt_text: firstImage?.altText || null,
    image_paths: images.map((image) => image.path),
    image_alt_texts: images.map((image) => image.altText),
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
    if (uploadedImages.length) await client.storage.from(RESOURCE_BUCKET).remove(uploadedImages.map((image) => image.path))
    const message = result.error.message || ''
    if (message.includes('row-level security') || result.error.code === '42501') {
      throw new Error('目前帳號沒有管理這個科目學習資源的權限。')
    }
    throw new Error(id ? '學習資源更新失敗，請稍後再試。' : '學習資源發布失敗，請稍後再試。')
  }

  const keptPaths = new Set(keptImages.map((image) => image.path))
  const removedPaths = previousPaths.filter((path) => !keptPaths.has(path))
  if (removedPaths.length) {
    await client.storage.from(RESOURCE_BUCKET).remove(removedPaths)
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
  const imagePaths = Array.isArray(resource.images)
    ? resource.images.map((image) => image.path).filter(Boolean)
    : resource.imagePath ? [resource.imagePath] : []
  if (imagePaths.length) {
    await client.storage.from(RESOURCE_BUCKET).remove(imagePaths)
  }
}

export async function saveLearningResourceOrder(resourceIds) {
  const client = requireSupabase()
  const { error } = await client.rpc('save_learning_resource_order', {
    p_resource_ids: resourceIds,
  })
  if (error) throw new Error('學習資源順序儲存失敗，請稍後再試。')
}
