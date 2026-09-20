import { ImagePlus, Trash2 } from 'lucide-react'

function ImageEditorCard({ image, label, onRemove, onAltTextChange }) {
  return (
    <article className="multi-image-editor-card">
      {image.url
        ? <img src={image.url} alt={image.altText || label} />
        : <div className="multi-image-editor-placeholder"><ImagePlus /><span>{image.fileName || '圖片暫時無法預覽'}</span></div>}
      <label>
        <span>圖片說明（選填）</span>
        <input
          maxLength="120"
          value={image.altText || ''}
          placeholder={label}
          onChange={(event) => onAltTextChange(event.target.value)}
        />
      </label>
      <button type="button" onClick={onRemove}><Trash2 />移除</button>
    </article>
  )
}

export default function MultiImageField({
  label,
  existingImages,
  newImages,
  maxImages = 10,
  onAddFiles,
  onRemoveExisting,
  onExistingAltTextChange,
  onRemoveNew,
  onNewAltTextChange,
}) {
  const count = existingImages.length + newImages.length
  return (
    <section className="multi-image-field">
      <label className="announcement-image-field">
        <span><ImagePlus aria-hidden="true" />{label}（選填）</span>
        <input
          type="file"
          accept="image/jpeg,image/png,image/webp"
          multiple
          disabled={count >= maxImages}
          onChange={(event) => {
            onAddFiles(event.target.files)
            event.currentTarget.value = ''
          }}
        />
        <small>可一次選取多張；接受 JPG、PNG、WebP，每張上限 5 MB，每篇最多 {maxImages} 張。目前 {count}／{maxImages} 張。</small>
      </label>
      {count > 0 && (
        <div className="multi-image-editor-grid">
          {existingImages.map((image, index) => (
            <ImageEditorCard
              key={image.path}
              image={image}
              label={`${label} ${index + 1}`}
              onRemove={() => onRemoveExisting(image.path)}
              onAltTextChange={(altText) => onExistingAltTextChange(image.path, altText)}
            />
          ))}
          {newImages.map((image, index) => (
            <ImageEditorCard
              key={image.id}
              image={{ ...image, url: image.previewUrl, fileName: image.file.name }}
              label={`${label} ${existingImages.length + index + 1}`}
              onRemove={() => onRemoveNew(image.id)}
              onAltTextChange={(altText) => onNewAltTextChange(image.id, altText)}
            />
          ))}
        </div>
      )}
    </section>
  )
}
