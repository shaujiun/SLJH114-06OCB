import {
  BookOpenText,
  ExternalLink,
  Pin,
  PlayCircle,
} from 'lucide-react'

function formatDate(value) {
  if (!value) return ''
  return new Intl.DateTimeFormat('zh-TW', {
    year: 'numeric',
    month: 'numeric',
    day: 'numeric',
  }).format(new Date(value))
}

export default function LearningResourceCard({ resource, preview = false }) {
  const isVideo = resource.resourceType === 'video'
  const externalLabel = isVideo ? '前往觀看' : '閱讀原文'
  return (
    <article className={`learning-resource-card is-${resource.resourceType}${preview ? ' is-preview' : ''}`}>
      {resource.imageUrl && (
        <img
          className="learning-resource-cover"
          src={resource.imageUrl}
          alt={resource.imageAltText || resource.title}
        />
      )}
      <div className="learning-resource-card-body">
        <div className="learning-resource-card-meta">
          <span className="learning-resource-type">
            {isVideo ? <PlayCircle /> : <BookOpenText />}
            {isVideo ? '學習影片' : '學習方法'}
          </span>
          <span className="learning-resource-subject">{resource.subject?.name || '通用'}</span>
          <span className="learning-resource-audience">{resource.audienceLabel || '共同'}</span>
          {resource.isPinned && <span className="learning-resource-pin"><Pin />置頂</span>}
        </div>

        <h3>{resource.title || '尚未輸入標題'}</h3>
        {resource.summary && <p className="learning-resource-summary">{resource.summary}</p>}

        {isVideo && resource.embedUrl && (
          <div className={`learning-video-frame is-${resource.videoPlatform}`}>
            <iframe
              src={resource.embedUrl}
              title={resource.title}
              loading="lazy"
              allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
              allowFullScreen
              referrerPolicy="strict-origin-when-cross-origin"
            />
          </div>
        )}

        {!isVideo && resource.contentType === 'article' && (
          <details className="learning-inline-article" open={preview}>
            <summary>閱讀站內文章</summary>
            <div>{resource.articleBody}</div>
          </details>
        )}

        <div className="learning-resource-source">
          <span>
            來源：{resource.sourceName || resource.createdByDisplayName || '教師整理'}
          </span>
          {resource.sourceUrl && (
            <a href={resource.sourceUrl} target="_blank" rel="noreferrer">
              查看出處<ExternalLink />
            </a>
          )}
        </div>

        {resource.contentUrl && (
          <a
            className="learning-resource-external"
            href={resource.contentUrl}
            target="_blank"
            rel="noreferrer"
          >
            {externalLabel}<ExternalLink />
          </a>
        )}

        <footer>
          <span>{formatDate(resource.publishedAt)}</span>
          <span>由 {resource.createdByDisplayName || '老師'} 分享</span>
        </footer>
      </div>
    </article>
  )
}
