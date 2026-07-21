import { beforeEach, describe, expect, it, vi } from 'vitest'
import { requireSupabase } from '../lib/supabase.js'
import {
  createClientId,
  mapAnnouncementRow,
  markAnnouncementRead,
  validateAnnouncementInput,
} from './announcementService.js'

vi.mock('../lib/supabase.js', () => ({
  requireSupabase: vi.fn(),
}))

describe('createClientId', () => {
  it('uses randomUUID when the browser provides it', () => {
    expect(createClientId({ randomUUID: () => 'native-uuid' })).toBe('native-uuid')
  })

  it('creates a UUID when randomUUID is unavailable on an HTTP mobile connection', () => {
    const cryptoApi = {
      getRandomValues: (bytes) => {
        bytes.set(Array.from({ length: 16 }, (_, index) => index))
        return bytes
      },
    }
    expect(createClientId(cryptoApi)).toBe('00010203-0405-4607-8809-0a0b0c0d0e0f')
  })

  it('still creates a valid UUID when the crypto API is entirely unavailable', () => {
    expect(createClientId(null)).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/)
  })
})

describe('公告資料驗證', () => {
  it('接受合法的班級公告並整理空白', () => {
    expect(validateAnnouncementInput({
      scope: 'class',
      title: '  班親會通知  ',
      content: '  請家長準時出席。  ',
      expiresAt: '',
      imageFile: null,
    })).toEqual({ title: '班親會通知', content: '請家長準時出席。' })
  })

  it('拒絕過大或格式不合的圖片', () => {
    expect(() => validateAnnouncementInput({
      scope: 'school', title: '通知', content: '', expiresAt: '',
      imageFile: { type: 'application/pdf', size: 100 },
    })).toThrow('公告圖片只接受 JPG、PNG 或 WebP。')

    expect(() => validateAnnouncementInput({
      scope: 'school', title: '通知', content: '', expiresAt: '',
      imageFile: { type: 'image/png', size: 5 * 1024 * 1024 + 1 },
    })).toThrow('公告圖片不可超過 5 MB。')
  })

  it('保留公告範圍、圖片與到期資料', () => {
    expect(mapAnnouncementRow({
      id: 'announcement-id', class_id: 'class-id', scope: 'school', title: '校慶',
      content: null, image_path: 'class-id/a/photo.webp', image_alt_text: null,
      published_at: '2026-08-10T00:00:00Z', expires_at: '2026-08-20T00:00:00Z', is_active: true,
    }, 'signed-url')).toMatchObject({
      id: 'announcement-id', scope: 'school', title: '校慶', content: '',
      imageUrl: 'signed-url', imageAltText: '校慶', isActive: true,
    })
  })
})

describe('公告已讀', () => {
  const insert = vi.fn()

  beforeEach(() => {
    insert.mockReset()
    requireSupabase.mockReturnValue({ from: vi.fn(() => ({ insert })) })
  })

  it('儲存學生的已讀紀錄', async () => {
    insert.mockResolvedValue({ error: null })
    await markAnnouncementRead({ announcementId: 'announcement-id', studentId: 'student-id' })
    expect(insert).toHaveBeenCalledWith({
      announcement_id: 'announcement-id',
      student_id: 'student-id',
    })
  })
})
