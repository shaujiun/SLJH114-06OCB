import { describe, expect, it } from 'vitest'
import {
  normalizeLoginId,
  validateLogin,
  validateExistingAccountPassword,
  validatePassword,
  validateStudentActivation,
  validateStudentPasswordReset,
  validateTeacherRegistration,
} from './validation.js'

describe('登入資料驗證', () => {
  it('移除學號中的空白', () => {
    expect(normalizeLoginId('  115 001 ')).toBe('115001')
  })

  it('拒絕空白登入資料', () => {
    expect(validateLogin({ username: '', password: '' })).toEqual({
      username: '請輸入帳號。',
      password: '請輸入密碼。',
    })
  })
})

describe('密碼規則', () => {
  it('要求至少八個字元並包含英文與數字', () => {
    expect(validatePassword('short')).toBe('密碼至少需要 8 個字元。')
    expect(validatePassword('abcdefgh')).toBe('密碼需同時包含英文字母與數字。')
    expect(validatePassword('abc12345')).toBe('')
  })

  it('既有英文單字帳號可沿用六字元以上的舊密碼', () => {
    expect(validateExistingAccountPassword('abc123')).toBe('')
    expect(validateExistingAccountPassword('12345')).toContain('至少需要 6 個字元')
  })
})

describe('啟用及教師註冊', () => {
  it('檢查學生兩次密碼是否一致', () => {
    const errors = validateStudentActivation({
      studentId: '115001',
      activationCode: 'CODE123',
      password: 'abc12345',
      confirmPassword: 'abc12346',
    })
    expect(errors.confirmPassword).toBe('兩次輸入的密碼不同。')
  })

  it('密碼重設要求正確學號、重設碼與新密碼', () => {
    expect(validateStudentPasswordReset({
      studentId: '900001',
      resetCode: 'ABCD2345',
      password: 'newpass1',
      confirmPassword: 'newpass1',
    })).toEqual({})

    expect(validateStudentPasswordReset({
      studentId: 'student',
      resetCode: '',
      password: 'short',
      confirmPassword: 'different',
    })).toEqual(expect.objectContaining({
      studentId: expect.any(String),
      resetCode: expect.any(String),
      password: expect.any(String),
      confirmPassword: expect.any(String),
    }))
  })

  it('教師帳號只接受安全字元', () => {
    const errors = validateTeacherRegistration({
      username: '王老師',
      displayName: '王老師',
      password: 'abc12345',
      confirmPassword: 'abc12345',
    })
    expect(errors.username).toContain('只能使用英文')
  })
})
