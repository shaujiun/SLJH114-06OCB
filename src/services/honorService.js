import { requireSupabase } from '../lib/supabase.js'
import { createClientId } from './announcementService.js'

const HONOR_BUCKET = 'contact-book-announcements'
const MAX_IMAGE_SIZE = 5 * 1024 * 1024
export const MAX_HONOR_IMAGES = 10
const ALLOWED_IMAGE_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp'])

function normalizeTitle(value) {
  return String(value || '').trim().replace(/\s+/g, ' ')
}

function extensionFor(file) {
  if (file.type === 'image/png') return 'png'
  if (file.type === 'image/webp') return 'webp'
  return 'jpg'
}

function normalizedImageFiles(imageFiles) {
  return Array.isArray(imageFiles) ? imageFiles.filter(Boolean) : []
}

function storedImages(row) {
  const paths = Array.isArray(row.image_paths) ? row.image_paths.filter(Boolean) : []
  const altTexts = Array.isArray(row.image_alt_texts) ? row.image_alt_texts : []
  return paths.map((path, index) => ({
    path,
    altText: String(altTexts[index] || '').trim() || row.title,
  }))
}

export function honorUploadErrorMessage(error) {
  const status = Number(error?.statusCode || error?.status || 0)
  const message = String(error?.message || error?.error || '').toLowerCase()
  if (status === 401 || status === 403 || message.includes('row-level security') || message.includes('unauthorized')) {
    return '榮譽照片上傳權限驗證失敗，請重新登入後再試。'
  }
  if (status === 413 || message.includes('maximum allowed size') || message.includes('too large')) {
    return '每張榮譽照片不可超過 5 MB。'
  }
  if (message.includes('mime type') || message.includes('content type')) {
    return '榮譽照片只接受 JPG、PNG 或 WebP。'
  }
  return '榮譽照片上傳失敗，請稍後再試。'
}

export function validateHonorInput({
  studentIds, title, description, awardedOn, imageFiles, existingImageCount = 0,
}) {
  const normalizedTitle = normalizeTitle(title)
  const normalizedDescription = String(description || '').trim()
  const uniqueStudentIds = [...new Set(studentIds || [])]
  if (!uniqueStudentIds.length) throw new Error('請至少選擇一位獲獎學生。')
  if (uniqueStudentIds.length > 50) throw new Error('單次最多可選擇 50 位學生。')
  if (!normalizedTitle || normalizedTitle.length > 80) throw new Error('榮譽名稱必須為 1 至 80 個字。')
  if (normalizedDescription.length > 1000) throw new Error('榮譽事蹟不可超過 1000 個字。')
  if (!/^\d{4}-\d{2}-\d{2}$/.test(awardedOn || '')) throw new Error('請設定榮譽日期。')
  const files = normalizedImageFiles(imageFiles)
  if (existingImageCount + files.length > MAX_HONOR_IMAGES) {
    throw new Error(`每則榮譽最多可上傳 ${MAX_HONOR_IMAGES} 張照片。`)
  }
  for (const file of files) {
    if (!ALLOWED_IMAGE_TYPES.has(file.type)) throw new Error('榮譽照片只接受 JPG、PNG 或 WebP。')
    if (file.size > MAX_IMAGE_SIZE) throw new Error('每張榮譽照片不可超過 5 MB。')
  }
  return { studentIds: uniqueStudentIds, title: normalizedTitle, description: normalizedDescription }
}

export function mapHonorRow(row, imageUrls = new Map(), failedPaths = new Set()) {
  const images = storedImages(row).map((image) => ({
    ...image,
    url: imageUrls.get(image.path) || null,
    error: failedPaths.has(image.path) ? '榮譽照片暫時無法讀取，請重新整理後再試。' : '',
  }))
  return {
    id: row.id,
    honorGroupId: row.honor_group_id || row.id,
    classId: row.class_id,
    studentId: row.student_id,
    studentDisplayName: row.student_display_name,
    title: row.title,
    description: row.description || '',
    images,
    awardedOn: row.awarded_on,
    isVisible: row.is_visible,
    createdAt: row.created_at,
  }
}

export function groupHonorRows(rows, imageUrls = new Map(), failedPaths = new Set()) {
  const groups = new Map()
  rows.map((row) => mapHonorRow(row, imageUrls, failedPaths)).forEach((item) => {
    const current = groups.get(item.honorGroupId)
    if (current) {
      current.entryIds.push(item.id)
      current.studentIds.push(item.studentId)
      current.studentDisplayNames.push(item.studentDisplayName)
      return
    }
    groups.set(item.honorGroupId, {
      ...item,
      id: item.honorGroupId,
      entryIds: [item.id],
      studentIds: [item.studentId],
      studentDisplayNames: [item.studentDisplayName],
    })
  })
  return [...groups.values()]
}

async function signedImageUrls(client, rows) {
  const paths = [...new Set((rows || []).flatMap((row) => storedImages(row).map((image) => image.path)))]
  if (!paths.length) return { urls: new Map(), failedPaths: new Set() }
  const { data, error } = await client.storage.from(HONOR_BUCKET).createSignedUrls(paths, 3600)
  if (error) return { urls: new Map(), failedPaths: new Set(paths) }
  const urls = new Map((data || [])
    .filter((item) => item.path && item.signedUrl && !item.error)
    .map((item) => [item.path, item.signedUrl]))
  return { urls, failedPaths: new Set(paths.filter((path) => !urls.has(path))) }
}

async function uploadHonorImages(client, { classId, groupPathId, imageFiles, imageAltTexts, title }) {
  const uploaded = []
  try {
    for (let index = 0; index < imageFiles.length; index += 1) {
      const file = imageFiles[index]
      const path = `${classId}/honors/${groupPathId}/${createClientId()}.${extensionFor(file)}`
      const { error } = await client.storage
        .from(HONOR_BUCKET)
        .upload(path, file, { contentType: file.type, upsert: false })
      if (error) throw new Error(honorUploadErrorMessage(error))
      uploaded.push({ path, altText: String(imageAltTexts[index] || '').trim() || title })
    }
    return uploaded
  } catch (error) {
    if (uploaded.length) await client.storage.from(HONOR_BUCKET).remove(uploaded.map((image) => image.path))
    throw error
  }
}

export async function createHonorEntries({
  classId, studentIds, title, description, awardedOn, imageFiles = [], imageAltTexts = [],
}) {
  const files = normalizedImageFiles(imageFiles)
  const validated = validateHonorInput({ studentIds, title, description, awardedOn, imageFiles: files })
  const client = requireSupabase()
  const images = await uploadHonorImages(client, {
    classId,
    groupPathId: createClientId(),
    imageFiles: files,
    imageAltTexts,
    title: validated.title,
  })
  const { data, error } = await client.rpc('admin_create_honor_entries', {
    p_class_id: classId,
    p_student_ids: validated.studentIds,
    p_title: validated.title,
    p_description: validated.description,
    p_awarded_on: awardedOn,
    p_image_paths: images.map((image) => image.path),
    p_image_alt_texts: images.map((image) => image.altText),
  })

  if (error) {
    if (images.length) await client.storage.from(HONOR_BUCKET).remove(images.map((image) => image.path))
    const message = error.message || ''
    if (message.includes('invalid_class_student')) throw new Error('找不到這位班級學生，請重新整理後再試。')
    if (message.includes('permission_denied')) throw new Error('目前帳號沒有建立榮譽榜的權限。')
    if (message.includes('invalid_honor_images')) throw new Error('榮譽照片資料不正確，請重新選擇後再試。')
    if (message.includes('invalid_honor')) throw new Error('榮譽內容格式不正確，請檢查後再試。')
    throw new Error('榮譽榜建立失敗，請稍後再試。')
  }
  return data
}

export async function updateHonorGroup({
  honorGroupId,
  classId,
  studentIds,
  title,
  description,
  awardedOn,
  imageFiles = [],
  imageAltTexts = [],
  existingImages = [],
  currentImagePaths = [],
}) {
  const files = normalizedImageFiles(imageFiles)
  const keptImages = existingImages.map((image) => ({
    path: image.path,
    altText: String(image.altText || '').trim() || title,
  }))
  const validated = validateHonorInput({
    studentIds,
    title,
    description,
    awardedOn,
    imageFiles: files,
    existingImageCount: keptImages.length,
  })
  const client = requireSupabase()
  const uploadedImages = await uploadHonorImages(client, {
    classId,
    groupPathId: honorGroupId,
    imageFiles: files,
    imageAltTexts,
    title: validated.title,
  })
  const images = [...keptImages, ...uploadedImages]
  const { data, error } = await client.rpc('admin_update_honor_group', {
    p_honor_group_id: honorGroupId,
    p_student_ids: validated.studentIds,
    p_title: validated.title,
    p_description: validated.description,
    p_awarded_on: awardedOn,
    p_image_paths: images.map((image) => image.path),
    p_image_alt_texts: images.map((image) => image.altText),
  })
  if (error) {
    if (uploadedImages.length) await client.storage.from(HONOR_BUCKET).remove(uploadedImages.map((image) => image.path))
    const message = error.message || ''
    if (message.includes('invalid_class_student')) throw new Error('獲獎學生名單已變更，請重新整理後再試。')
    if (message.includes('invalid_honor_entry')) throw new Error('找不到這筆榮譽紀錄，請重新整理。')
    if (message.includes('permission_denied')) throw new Error('目前帳號沒有編輯榮譽榜的權限。')
    if (message.includes('invalid_honor_images')) throw new Error('榮譽照片資料不正確，請重新選擇後再試。')
    if (message.includes('invalid_honor')) throw new Error('榮譽內容格式不正確，請檢查後再試。')
    throw new Error('榮譽紀錄更新失敗，請稍後再試。')
  }
  const keptPaths = new Set(keptImages.map((image) => image.path))
  const removedPaths = currentImagePaths.filter((path) => !keptPaths.has(path))
  if (removedPaths.length) await client.storage.from(HONOR_BUCKET).remove(removedPaths)
  return data
}

export async function loadAdminHonors({ classId }) {
  const client = requireSupabase()
  const [honorsResult, studentsResult] = await Promise.all([
    client
      .from('honor_entries')
      .select('id,honor_group_id,class_id,student_id,student_display_name,title,description,image_paths,image_alt_texts,awarded_on,is_visible,created_at')
      .eq('class_id', classId)
      .order('awarded_on', { ascending: false })
      .order('created_at', { ascending: false }),
    client
      .from('students')
      .select('id,seat_number,full_name')
      .eq('class_id', classId)
      .eq('is_active', true)
      .order('seat_number'),
  ])
  if (honorsResult.error) throw new Error('無法讀取榮譽榜。')
  if (studentsResult.error) throw new Error('無法讀取班級學生名單。')
  const honorRows = honorsResult.data || []
  const { urls, failedPaths } = await signedImageUrls(client, honorRows)
  return {
    honors: groupHonorRows(honorRows, urls, failedPaths),
    students: (studentsResult.data || []).map((student) => ({
      id: student.id,
      seatNumber: student.seat_number,
      fullName: student.full_name,
    })),
  }
}

export async function setHonorVisibility({ honorGroupId, isVisible }) {
  const client = requireSupabase()
  const { error } = await client.rpc('admin_set_honor_group_visibility', {
    p_honor_group_id: honorGroupId,
    p_is_visible: isVisible,
  })
  if (error) throw new Error(isVisible ? '榮譽榜重新顯示失敗。' : '榮譽榜隱藏失敗。')
}

export async function deleteHonorGroup({ honorGroupId, imagePaths = [] }) {
  const client = requireSupabase()
  const { data, error } = await client.rpc('admin_delete_honor_group', {
    p_honor_group_id: honorGroupId,
  })
  if (error) {
    const message = error.message || ''
    if (message.includes('invalid_honor_entry')) throw new Error('找不到這筆榮譽紀錄，請重新整理。')
    if (message.includes('permission_denied')) throw new Error('目前帳號沒有刪除榮譽榜的權限。')
    throw new Error('榮譽紀錄刪除失敗，請稍後再試。')
  }
  if (imagePaths.length) await client.storage.from(HONOR_BUCKET).remove(imagePaths)
  return data
}

export async function loadStudentHonors({ classId }) {
  const client = requireSupabase()
  const { data, error } = await client
    .from('honor_entries')
    .select('id,honor_group_id,class_id,student_id,student_display_name,title,description,image_paths,image_alt_texts,awarded_on,is_visible,created_at')
    .eq('class_id', classId)
    .eq('is_visible', true)
    .order('awarded_on', { ascending: false })
    .order('created_at', { ascending: false })
  if (error) throw new Error('無法讀取班級榮譽榜。')
  const rows = data || []
  const { urls, failedPaths } = await signedImageUrls(client, rows)
  return groupHonorRows(rows, urls, failedPaths)
}
