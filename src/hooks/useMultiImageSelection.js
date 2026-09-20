import { useCallback, useEffect, useRef, useState } from 'react'

const MAX_IMAGE_SIZE = 5 * 1024 * 1024
const ALLOWED_IMAGE_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp'])

export default function useMultiImageSelection({ maxImages = 10, imageLabel = '圖片' } = {}) {
  const [newImages, setNewImages] = useState([])
  const latestImages = useRef([])

  useEffect(() => {
    latestImages.current = newImages
  }, [newImages])

  useEffect(() => () => {
    latestImages.current.forEach((image) => URL.revokeObjectURL(image.previewUrl))
  }, [])

  const clearNewImages = useCallback(() => {
    setNewImages((current) => {
      current.forEach((image) => URL.revokeObjectURL(image.previewUrl))
      return []
    })
  }, [])

  const addImageFiles = useCallback((fileList, existingCount = 0, defaultAltText = '') => {
    const files = Array.from(fileList || [])
    if (!files.length) return ''
    const invalidType = files.find((file) => !ALLOWED_IMAGE_TYPES.has(file.type))
    if (invalidType) return `${imageLabel}只接受 JPG、PNG 或 WebP。`
    const oversized = files.find((file) => file.size > MAX_IMAGE_SIZE)
    if (oversized) return `每張${imageLabel}不可超過 5 MB。`

    const remaining = Math.max(0, maxImages - existingCount - latestImages.current.length)
    if (files.length > remaining) {
      return `每篇最多可上傳 ${maxImages} 張圖片，目前還可加入 ${remaining} 張。`
    }
    setNewImages((current) => {
      return [
        ...current,
        ...files.map((file) => ({
          id: `${file.name}-${file.lastModified}-${Math.random().toString(16).slice(2)}`,
          file,
          altText: defaultAltText.trim(),
          previewUrl: URL.createObjectURL(file),
        })),
      ]
    })
    return ''
  }, [imageLabel, maxImages])

  const removeNewImage = useCallback((id) => {
    setNewImages((current) => current.filter((image) => {
      if (image.id !== id) return true
      URL.revokeObjectURL(image.previewUrl)
      return false
    }))
  }, [])

  const updateNewImageAltText = useCallback((id, altText) => {
    setNewImages((current) => current.map((image) => (
      image.id === id ? { ...image, altText } : image
    )))
  }, [])

  return {
    newImages,
    addImageFiles,
    removeNewImage,
    updateNewImageAltText,
    clearNewImages,
  }
}
