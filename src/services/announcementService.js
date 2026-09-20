import { requireSupabase } from '../lib/supabase.js'

const ANNOUNCEMENT_BUCKET = 'contact-book-announcements'
const MAX_IMAGE_SIZE = 5 * 1024 * 1024
export const MAX_ANNOUNCEMENT_IMAGES = 10
const ALLOWED_IMAGE_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp'])

export function announcementUploadErrorMessage(error) {
  const status = Number(error?.statusCode || error?.status || 0)
  const message = String(error?.message || error?.error || '').toLowerCase()
  if (
    status === 401
    || status === 403
    || message.includes('row-level security')
    || message.includes('unauthorized')
  ) {
    return '公告圖片上傳權限驗證失敗，請重新登入後再試。'
  }
  if (status === 413 || message.includes('maximum allowed size') || message.includes('too large')) {
    return '公告圖片不可超過 5 MB。'
  }
  if (message.includes('mime type') || message.includes('content type')) {
    return '公告圖片只接受 JPG、PNG 或 WebP。'
  }
  return '公告圖片上傳失敗，請稍後再試。'
}

function extensionFor(file) {
  if (file.type === 'image/png') return 'png'
  if (file.type === 'image/webp') return 'webp'
  return 'jpg'
}

function normalizeText(value) {
  return String(value || '').trim()
}

export function createClientId(cryptoApi = globalThis.crypto) {
  if (typeof cryptoApi?.randomUUID === 'function') return cryptoApi.randomUUID()

  const bytes = new Uint8Array(16)
  if (typeof cryptoApi?.getRandomValues === 'function') {
    cryptoApi.getRandomValues(bytes)
  } else {
    for (let index = 0; index < bytes.length; index += 1) {
      bytes[index] = Math.floor(Math.random() * 256)
    }
  }

  bytes[6] = (bytes[6] & 0x0f) | 0x40
  bytes[8] = (bytes[8] & 0x3f) | 0x80
  const value = Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0')).join('')
  return `${value.slice(0, 8)}-${value.slice(8, 12)}-${value.slice(12, 16)}-${value.slice(16, 20)}-${value.slice(20)}`
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

export function validateAnnouncementInput({
  scope,
  title,
  content,
  expiresAt,
  imageFiles,
  imageFile,
  existingImageCount = 0,
  allowPastExpiry = false,
}) {
  const normalizedTitle = normalizeText(title)
  const normalizedContent = normalizeText(content)
  if (!['school', 'class'].includes(scope)) throw new Error('請選擇公告類型。')
  if (!normalizedTitle || normalizedTitle.length > 80) throw new Error('公告標題必須為 1 至 80 個字。')
  if (normalizedContent.length > 2000) throw new Error('公告內容不可超過 2000 個字。')
  if (expiresAt) {
    const expiresTime = new Date(expiresAt).getTime()
    if (!Number.isFinite(expiresTime)) throw new Error('公告到期時間格式不正確。')
    if (!allowPastExpiry && expiresTime <= Date.now()) throw new Error('公告到期時間必須晚於現在。')
  }
  const files = normalizedImageFiles(imageFiles, imageFile)
  if (existingImageCount + files.length > MAX_ANNOUNCEMENT_IMAGES) {
    throw new Error(`每篇公告最多可上傳 ${MAX_ANNOUNCEMENT_IMAGES} 張圖片。`)
  }
  for (const file of files) {
    if (!ALLOWED_IMAGE_TYPES.has(file.type)) throw new Error('公告圖片只接受 JPG、PNG 或 WebP。')
    if (file.size > MAX_IMAGE_SIZE) throw new Error('每張公告圖片不可超過 5 MB。')
  }
  return { title: normalizedTitle, content: normalizedContent }
}

export function mapAnnouncementRow(row, imageUrls = new Map(), failedPaths = new Set()) {
  const urlMap = imageUrls instanceof Map ? imageUrls : new Map()
  const failedSet = failedPaths instanceof Set ? failedPaths : new Set()
  const legacyUrl = typeof imageUrls === 'string' ? imageUrls : null
  const legacyError = typeof failedPaths === 'string' ? failedPaths : ''
  const images = storedImages(row).map((image) => ({
    ...image,
    url: urlMap.get(image.path) || legacyUrl || null,
    error: failedSet.has(image.path)
      ? '公告圖片暫時無法讀取，請重新整理後再試。'
      : legacyError,
  }))
  const firstImage = images[0] || null
  return {
    id: row.id,
    classId: row.class_id,
    scope: row.scope,
    title: row.title,
    content: row.content || '',
    images,
    imagePath: firstImage?.path || null,
    imageAltText: firstImage?.altText || row.title,
    imageUrl: firstImage?.url || null,
    imageError: firstImage?.error || '',
    publishedAt: row.published_at,
    expiresAt: row.expires_at,
    isActive: row.is_active,
  }
}

async function signedImageUrls(client, rows) {
  const paths = [...new Set(rows.flatMap((row) => storedImages(row).map((image) => image.path)))]
  if (!paths.length) return { urls: new Map(), failedPaths: new Set() }
  const { data, error } = await client.storage.from(ANNOUNCEMENT_BUCKET).createSignedUrls(paths, 3600)
  if (error) return { urls: new Map(), failedPaths: new Set(paths) }
  const urls = new Map((data || [])
    .filter((item) => item.path && item.signedUrl && !item.error)
    .map((item) => [item.path, item.signedUrl]))
  return {
    urls,
    failedPaths: new Set(paths.filter((path) => !urls.has(path))),
  }
}

async function uploadAnnouncementImages(client, { classId, announcementId, imageFiles, imageAltTexts, title }) {
  const uploaded = []
  try {
    for (let index = 0; index < imageFiles.length; index += 1) {
      const file = imageFiles[index]
      const path = `${classId}/${announcementId}/${createClientId()}.${extensionFor(file)}`
      const { error } = await client.storage
        .from(ANNOUNCEMENT_BUCKET)
        .upload(path, file, { contentType: file.type, upsert: false })
      if (error) throw new Error(announcementUploadErrorMessage(error))
      uploaded.push({ path, altText: normalizeText(imageAltTexts[index]) || title })
    }
    return uploaded
  } catch (error) {
    if (uploaded.length) {
      await client.storage.from(ANNOUNCEMENT_BUCKET).remove(uploaded.map((image) => image.path))
    }
    throw error
  }
}

export async function createAnnouncement({
  classId, scope, title, content, expiresAt, imageFiles, imageFile, imageAltTexts = [], imageAltText,
}) {
  const files = normalizedImageFiles(imageFiles, imageFile)
  const altTexts = imageAltTexts.length ? imageAltTexts : files.map(() => imageAltText || '')
  const validated = validateAnnouncementInput({ scope, title, content, expiresAt, imageFiles: files })
  const client = requireSupabase()
  const { data: userData, error: userError } = await client.auth.getUser()
  if (userError || !userData.user) throw new Error('登入狀態已失效，請重新登入。')

  const announcementId = createClientId()
  const images = await uploadAnnouncementImages(client, {
    classId, announcementId, imageFiles: files, imageAltTexts: altTexts, title: validated.title,
  })
  const firstImage = images[0] || null

  const { data, error } = await client
    .from('announcements')
    .insert({
      id: announcementId,
      class_id: classId,
      scope,
      title: validated.title,
      content: validated.content || null,
      image_path: firstImage?.path || null,
      image_alt_text: firstImage?.altText || null,
      image_paths: images.map((image) => image.path),
      image_alt_texts: images.map((image) => image.altText),
      expires_at: expiresAt ? new Date(expiresAt).toISOString() : null,
      published_by: userData.user.id,
    })
    .select('id')
    .single()

  if (error) {
    if (images.length) await client.storage.from(ANNOUNCEMENT_BUCKET).remove(images.map((image) => image.path))
    throw new Error('公告發布失敗，請稍後再試。')
  }
  return data
}

export async function updateAnnouncement({
  announcementId,
  classId,
  scope,
  title,
  content,
  expiresAt,
  imageFiles,
  imageFile,
  imageAltTexts = [],
  imageAltText,
  existingImages,
  currentImagePaths,
  existingImagePath,
  previousExpiresAt,
  removeImage = false,
}) {
  const files = normalizedImageFiles(imageFiles, imageFile)
  const keptImages = Array.isArray(existingImages)
    ? existingImages.map((image) => ({ path: image.path, altText: normalizeText(image.altText) || title }))
    : removeImage || !existingImagePath
      ? []
      : [{ path: existingImagePath, altText: normalizeText(imageAltText) || title }]
  const previousPaths = Array.isArray(currentImagePaths)
    ? currentImagePaths.filter(Boolean)
    : existingImagePath ? [existingImagePath] : []
  const altTexts = imageAltTexts.length ? imageAltTexts : files.map(() => imageAltText || '')
  const nextExpiryTime = expiresAt ? new Date(expiresAt).getTime() : null
  const previousExpiryTime = previousExpiresAt ? new Date(previousExpiresAt).getTime() : null
  const allowPastExpiry = Number.isFinite(nextExpiryTime)
    && Number.isFinite(previousExpiryTime)
    && nextExpiryTime === previousExpiryTime
  const validated = validateAnnouncementInput({
    scope,
    title,
    content,
    expiresAt,
    imageFiles: files,
    existingImageCount: keptImages.length,
    allowPastExpiry,
  })
  const client = requireSupabase()
  const { data: userData, error: userError } = await client.auth.getUser()
  if (userError || !userData.user) throw new Error('登入狀態已失效，請重新登入。')

  const uploadedImages = await uploadAnnouncementImages(client, {
    classId, announcementId, imageFiles: files, imageAltTexts: altTexts, title: validated.title,
  })
  const images = [...keptImages, ...uploadedImages]
  const firstImage = images[0] || null

  const { data, error } = await client
    .from('announcements')
    .update({
      scope,
      title: validated.title,
      content: validated.content || null,
      image_path: firstImage?.path || null,
      image_alt_text: firstImage?.altText || null,
      image_paths: images.map((image) => image.path),
      image_alt_texts: images.map((image) => image.altText),
      expires_at: expiresAt ? new Date(expiresAt).toISOString() : null,
      published_by: userData.user.id,
    })
    .eq('id', announcementId)
    .eq('class_id', classId)
    .select('id')
    .single()

  if (error) {
    if (uploadedImages.length) await client.storage.from(ANNOUNCEMENT_BUCKET).remove(uploadedImages.map((image) => image.path))
    throw new Error('公告更新失敗，請稍後再試。')
  }

  const keptPaths = new Set(keptImages.map((image) => image.path))
  const removedPaths = previousPaths.filter((path) => !keptPaths.has(path))
  if (removedPaths.length) {
    await client.storage.from(ANNOUNCEMENT_BUCKET).remove(removedPaths)
  }
  return data
}

export async function loadAdminAnnouncements({ classId }) {
  const client = requireSupabase()
  const [announcementsResult, studentsResult] = await Promise.all([
    client
      .from('announcements')
      .select('id,class_id,scope,title,content,image_path,image_alt_text,image_paths,image_alt_texts,published_at,expires_at,is_active')
      .eq('class_id', classId)
      .order('published_at', { ascending: false }),
    client
      .from('students')
      .select('id,seat_number,full_name')
      .eq('class_id', classId)
      .eq('is_active', true)
      .order('seat_number'),
  ])
  if (announcementsResult.error) throw new Error('無法讀取公告清單。')
  if (studentsResult.error) throw new Error('無法讀取公告已讀名單。')

  const rows = announcementsResult.data || []
  const students = studentsResult.data || []
  const ids = rows.map((row) => row.id)
  let reads = []
  if (ids.length) {
    const { data, error } = await client
      .from('announcement_reads')
      .select('announcement_id,student_id,read_at')
      .in('announcement_id', ids)
    if (error) throw new Error('無法讀取公告已讀統計。')
    reads = data || []
  }

  const { urls: imageUrls, failedPaths } = await signedImageUrls(client, rows)
  return rows.map((row) => {
    const readMap = new Map(
      reads.filter((item) => item.announcement_id === row.id).map((item) => [item.student_id, item.read_at]),
    )
    return {
      ...mapAnnouncementRow(
        row,
        imageUrls,
        failedPaths,
      ),
      readStudents: students.filter((student) => readMap.has(student.id)).map((student) => ({
        id: student.id,
        seatNumber: student.seat_number,
        fullName: student.full_name,
        readAt: readMap.get(student.id),
      })),
      unreadStudents: students.filter((student) => !readMap.has(student.id)).map((student) => ({
        id: student.id,
        seatNumber: student.seat_number,
        fullName: student.full_name,
      })),
    }
  })
}

export async function deactivateAnnouncement(announcementId) {
  const client = requireSupabase()
  const { error } = await client.from('announcements').update({ is_active: false }).eq('id', announcementId)
  if (error) throw new Error('公告下架失敗，請稍後再試。')
}

export async function loadStudentAnnouncements({ classId, studentId }) {
  const client = requireSupabase()
  const now = new Date().toISOString()
  const [announcementsResult, readsResult] = await Promise.all([
    client
      .from('announcements')
      .select('id,class_id,scope,title,content,image_path,image_alt_text,image_paths,image_alt_texts,published_at,expires_at,is_active')
      .eq('class_id', classId)
      .eq('is_active', true)
      .order('published_at', { ascending: false }),
    client
      .from('announcement_reads')
      .select('announcement_id,read_at')
      .eq('student_id', studentId),
  ])
  if (announcementsResult.error) throw new Error('無法讀取班級公告。')
  if (readsResult.error) throw new Error('無法讀取公告已讀狀態。')
  const rows = (announcementsResult.data || []).filter((row) => (
    !row.expires_at || new Date(row.expires_at).getTime() > new Date(now).getTime()
  ))
  const readMap = new Map((readsResult.data || []).map((item) => [item.announcement_id, item.read_at]))
  const { urls: imageUrls, failedPaths } = await signedImageUrls(client, rows)
  return rows.map((row) => ({
    ...mapAnnouncementRow(
      row,
      imageUrls,
      failedPaths,
    ),
    readAt: readMap.get(row.id) || null,
  }))
}

export async function markAnnouncementRead({ announcementId, studentId }) {
  const client = requireSupabase()
  const { error } = await client.from('announcement_reads').insert({
    announcement_id: announcementId,
    student_id: studentId,
  })
  if (error && error.code !== '23505') throw new Error('已讀狀態儲存失敗，請稍後再試。')
  return new Date().toISOString()
}
