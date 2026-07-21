const encoder = new TextEncoder()
const activationAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'

export function normalizeLoginId(value: unknown) {
  if (typeof value !== 'string') return ''
  return value.trim().replace(/\s+/g, '').toLowerCase()
}

export function normalizeActivationCode(value: unknown) {
  if (typeof value !== 'string') return ''
  return value.trim().replace(/[\s-]+/g, '').toUpperCase()
}

export function validatePassword(value: unknown) {
  return typeof value === 'string'
    && value.length >= 8
    && value.length <= 128
    && /[A-Za-z]/.test(value)
    && /\d/.test(value)
}

export function validateAccountPassword(value: unknown) {
  return typeof value === 'string'
    && value.length >= 6
    && value.length <= 128
}

export function validateStudentId(value: string) {
  return /^\d{4,20}$/.test(value)
}

export function validateActivationCode(value: string) {
  return /^[A-Z0-9]{6,20}$/.test(value)
}

export function validateTeacherUsername(value: string) {
  return /^[a-z0-9._-]{4,32}$/.test(value)
}

export function validateDisplayName(value: unknown) {
  return typeof value === 'string'
    && value.trim().length >= 2
    && value.trim().length <= 50
}

export function validateSeatNumber(value: unknown) {
  return Number.isInteger(value) && Number(value) >= 1 && Number(value) <= 99
}

export function validateGroupCode(value: unknown) {
  return value === 'A' || value === 'B'
}

export function validateUuid(value: unknown) {
  return typeof value === 'string'
    && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)
}

export function generateActivationCode(length = 8) {
  const bytes = new Uint8Array(length)
  crypto.getRandomValues(bytes)
  return Array.from(bytes, (byte) => activationAlphabet[byte % activationAlphabet.length]).join('')
}

export function canUseAccountLogin(
  requestedAccountType: 'student' | 'teacher',
  profileUserType: string,
) {
  if (requestedAccountType === 'student') return profileUserType === 'student'
  return profileUserType === 'teacher' || profileUserType === 'admin'
}

export async function hmacHex(secret: string, value: string) {
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const signature = await crypto.subtle.sign('HMAC', key, encoder.encode(value))
  return Array.from(new Uint8Array(signature))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('')
}

export function sharedAccountEmail(username: string) {
  const localPart = normalizeLoginId(username).replace(/[^a-z0-9._-]/g, '_')
  return `${localPart}@vocab-explorer.app`
}

export function activationCodeHash(studentId: string, activationCode: string, secret: string) {
  return hmacHex(
    secret,
    `activation:${normalizeLoginId(studentId)}:${normalizeActivationCode(activationCode)}`,
  )
}

export function passwordResetCodeHash(studentId: string, resetCode: string, secret: string) {
  return hmacHex(
    secret,
    `password-reset:${normalizeLoginId(studentId)}:${normalizeActivationCode(resetCode)}`,
  )
}
