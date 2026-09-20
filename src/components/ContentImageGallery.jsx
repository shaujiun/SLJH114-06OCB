export default function ContentImageGallery({ images = [], className = '' }) {
  const visibleImages = images.filter((image) => image.url)
  const errors = images.filter((image) => image.error)
  return (
    <>
      {visibleImages.length > 0 && (
        <div className={`content-image-gallery is-count-${Math.min(visibleImages.length, 4)} ${className}`.trim()}>
          {visibleImages.map((image, index) => (
            <a
              href={image.url}
              target="_blank"
              rel="noreferrer"
              title="開啟原尺寸圖片"
              key={image.path || `${image.url}-${index}`}
            >
              <img src={image.url} alt={image.altText || `附圖 ${index + 1}`} loading="lazy" />
            </a>
          ))}
        </div>
      )}
      {errors.length > 0 && <p className="private-image-error">有 {errors.length} 張圖片暫時無法讀取，請重新整理後再試。</p>}
    </>
  )
}
