import { describe, expect, it } from 'vitest'
import {
  learningResourceUploadErrorMessage,
  mapLearningResourceRow,
  normalizeHttpUrl,
  validateLearningResourceInput,
  videoEmbedInfo,
} from './learningResourceService.js'

describe('學習資源網址', () => {
  it('只接受 http 與 https 網址', () => {
    expect(normalizeHttpUrl('https://example.com/article')).toBe('https://example.com/article')
    expect(() => normalizeHttpUrl('javascript:alert(1)', { required: true })).toThrow('只接受 http 或 https')
  })

  it('辨識 YouTube、Vimeo、Instagram 與 Facebook 內嵌網址', () => {
    expect(videoEmbedInfo('https://youtu.be/abcdefghijk')).toEqual({
      platform: 'youtube',
      embedUrl: 'https://www.youtube-nocookie.com/embed/abcdefghijk',
    })
    expect(videoEmbedInfo('https://vimeo.com/123456')).toEqual({
      platform: 'vimeo',
      embedUrl: 'https://player.vimeo.com/video/123456',
    })
    expect(videoEmbedInfo('https://www.instagram.com/reel/ABC123/')).toEqual({
      platform: 'instagram',
      embedUrl: 'https://www.instagram.com/reel/ABC123/embed/',
    })
    expect(videoEmbedInfo('https://www.facebook.com/example/videos/123')).toMatchObject({
      platform: 'facebook',
    })
  })

  it('不支援的平台保留外部連結但不建立 iframe', () => {
    expect(videoEmbedInfo('https://example.com/video')).toEqual({
      platform: 'external',
      embedUrl: null,
    })
  })
})

describe('學習資源輸入', () => {
  const base = {
    resourceType: 'method',
    contentType: 'external',
    title: '有效讀書方法',
    summary: '',
    articleBody: '',
    contentUrl: 'https://example.com/method',
    sourceName: '學習網站',
    sourceUrl: '',
    publishedAt: '2026-07-28T08:00',
    imageFile: null,
    audienceScope: 'common',
  }

  it('站內文章必須包含文章與來源', () => {
    expect(() => validateLearningResourceInput({
      ...base,
      contentType: 'article',
      contentUrl: '',
      articleBody: '先設定每天可以完成的小目標。',
      sourceName: '',
    })).toThrow('必須填寫作者或資料來源')
  })

  it('影片必須提供完整網址', () => {
    expect(() => validateLearningResourceInput({
      ...base,
      resourceType: 'video',
      contentType: 'video',
      contentUrl: '',
    })).toThrow('網址格式不正確')
  })

  it('接受安全的外部文章資料', () => {
    expect(validateLearningResourceInput(base)).toMatchObject({
      title: '有效讀書方法',
      contentUrl: 'https://example.com/method',
      audienceScope: 'common',
    })
  })

  it('拒絕未知的學生顯示對象', () => {
    expect(() => validateLearningResourceInput({
      ...base,
      audienceScope: 'all_a',
    })).toThrow('顯示對象')
  })
})

describe('學習資源封面讀取', () => {
  it('保留封面讀取失敗訊息，不會誤認成沒有封面', () => {
    expect(mapLearningResourceRow({
      id: 'resource-id',
      resource_type: 'method',
      title: '學習方法',
      image_path: 'class-id/user-id/resource-id/cover.jpg',
    }, null, '封面讀取失敗')).toMatchObject({
      imagePath: 'class-id/user-id/resource-id/cover.jpg',
      imageUrl: null,
      imageError: '封面讀取失敗',
    })
  })
})

describe('學習資源封面上傳錯誤', () => {
  it('權限失敗時不誤指為圖片格式問題', () => {
    expect(learningResourceUploadErrorMessage({
      statusCode: 403,
      message: 'new row violates row-level security policy',
    })).toBe('封面圖片上傳權限驗證失敗，請通知系統管理員。')
  })

  it('分別說明圖片過大與格式不符', () => {
    expect(learningResourceUploadErrorMessage({
      statusCode: 413,
      message: 'The object exceeded the maximum allowed size',
    })).toBe('封面圖片不可超過 5 MB。')
    expect(learningResourceUploadErrorMessage({
      statusCode: 400,
      message: 'mime type image/gif is not supported',
    })).toBe('封面圖片只接受 JPG、PNG 或 WebP。')
  })
})
