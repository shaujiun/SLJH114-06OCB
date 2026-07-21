import { describe, expect, it } from 'vitest'
import {
  activationCodeHash,
  canUseAccountLogin,
  generateActivationCode,
  normalizeActivationCode,
  normalizeLoginId,
  passwordResetCodeHash,
  sharedAccountEmail,
  validateAccountPassword,
  validateGroupCode,
  validatePassword,
  validateSeatNumber,
  validateStudentId,
  validateTeacherUsername,
  validateUuid,
} from './security.ts'

describe('Edge Function 帳號正規化', () => {
  it('學號移除空白並轉小寫', () => {
    expect(normalizeLoginId(' 115 001 ')).toBe('115001')
  })

  it('啟用碼忽略空白與連字號', () => {
    expect(normalizeActivationCode(' ab-12 cd ')).toBe('AB12CD')
  })
})

describe('Edge Function 輸入限制', () => {
  it('只接受合理的數字學號', () => {
    expect(validateStudentId('115001')).toBe(true)
    expect(validateStudentId('student01')).toBe(false)
  })

  it('只接受安全的教師帳號', () => {
    expect(validateTeacherUsername('teacher.wang')).toBe(true)
    expect(validateTeacherUsername('王老師')).toBe(false)
  })

  it('密碼至少八字元且包含英文與數字', () => {
    expect(validatePassword('abc12345')).toBe(true)
    expect(validatePassword('abcdefgh')).toBe(false)
  })

  it('既有英文單字帳號仍接受原本的六字元密碼規則', () => {
    expect(validateAccountPassword('abc123')).toBe(true)
    expect(validateAccountPassword('12345')).toBe(false)
  })
})

describe('共用 Auth 帳號', () => {
  it('使用與英文單字系統相同的 Auth 電子郵件別名', () => {
    expect(sharedAccountEmail(' 115 001 ')).toBe('115001@vocab-explorer.app')
    expect(sharedAccountEmail('Teacher.Wang')).toBe('teacher.wang@vocab-explorer.app')
  })

  it('不同啟用碼產生不同雜湊', async () => {
    const first = await activationCodeHash('115001', 'ABC123', 'test-secret')
    const second = await activationCodeHash('115001', 'ABC124', 'test-secret')
    expect(first).not.toBe(second)
  })

  it('密碼重設碼與啟用碼使用不同的雜湊用途', async () => {
    const activation = await activationCodeHash('115001', 'ABC123', 'test-secret')
    const passwordReset = await passwordResetCodeHash('115001', 'ABC123', 'test-secret')
    expect(passwordReset).not.toBe(activation)
  })
})

describe('登入入口角色', () => {
  it('教師入口允許教師與管理員登入', () => {
    expect(canUseAccountLogin('teacher', 'teacher')).toBe(true)
    expect(canUseAccountLogin('teacher', 'admin')).toBe(true)
  })

  it('學生入口只允許學生登入', () => {
    expect(canUseAccountLogin('student', 'student')).toBe(true)
    expect(canUseAccountLogin('student', 'teacher')).toBe(false)
    expect(canUseAccountLogin('student', 'admin')).toBe(false)
  })
})

describe('學生建檔安全輸入', () => {
  it('座號只接受 1 到 99 的整數', () => {
    expect(validateSeatNumber(1)).toBe(true)
    expect(validateSeatNumber(99)).toBe(true)
    expect(validateSeatNumber(0)).toBe(false)
    expect(validateSeatNumber(1.5)).toBe(false)
  })

  it('分組只接受 A 或 B', () => {
    expect(validateGroupCode('A')).toBe(true)
    expect(validateGroupCode('B')).toBe(true)
    expect(validateGroupCode('共同')).toBe(false)
  })

  it('識別碼必須是 UUID', () => {
    expect(validateUuid('0f7a9e4a-5e75-4af1-b503-4e59ebae6289')).toBe(true)
    expect(validateUuid('not-a-uuid')).toBe(false)
  })

  it('產生不含易混淆字元的八碼啟用碼', () => {
    expect(generateActivationCode()).toMatch(/^[A-HJ-NP-Z2-9]{8}$/)
  })
})
