export function normalizeLoginId(value) {
  return value.trim().replace(/\s+/g, '')
}

export function validateLogin({ username, password }) {
  const errors = {}
  const normalizedUsername = normalizeLoginId(username)

  if (!normalizedUsername) errors.username = '請輸入帳號。'
  if (!password) errors.password = '請輸入密碼。'

  return errors
}

export function validatePassword(password) {
  if (password.length < 8) return '密碼至少需要 8 個字元。'
  if (!/[A-Za-z]/.test(password) || !/\d/.test(password)) {
    return '密碼需同時包含英文字母與數字。'
  }
  return ''
}

export function validateExistingAccountPassword(password) {
  if (password.length < 6) return '密碼至少需要 6 個字元。'
  return ''
}

export function validateStudentActivation(form) {
  const errors = {}
  if (!normalizeLoginId(form.studentId)) errors.studentId = '請輸入學號。'
  if (!form.activationCode.trim()) errors.activationCode = '請輸入一次性啟用碼。'

  const passwordError = validateExistingAccountPassword(form.password)
  if (passwordError) errors.password = passwordError
  if (form.password !== form.confirmPassword) errors.confirmPassword = '兩次輸入的密碼不同。'

  return errors
}

export function validateStudentPasswordReset(form) {
  const errors = {}
  if (!/^\d{4,20}$/.test(form.studentId.trim())) errors.studentId = '請輸入正確的學生學號。'
  if (!/^[A-Za-z0-9\s-]{6,20}$/.test(form.resetCode.trim())) errors.resetCode = '請輸入導師提供的重設碼。'
  const passwordError = validatePassword(form.password)
  if (passwordError) errors.password = passwordError
  if (form.password !== form.confirmPassword) errors.confirmPassword = '兩次輸入的密碼不同。'
  return errors
}

export function validateTeacherRegistration(form) {
  const errors = {}
  const username = normalizeLoginId(form.username)

  if (username.length < 4) errors.username = '教師帳號至少需要 4 個字元。'
  if (!/^[A-Za-z0-9._-]+$/.test(username)) {
    errors.username = '教師帳號只能使用英文、數字、句點、底線或連字號。'
  }
  if (!form.displayName.trim()) errors.displayName = '請輸入教師姓名。'

  const passwordError = validatePassword(form.password)
  if (passwordError) errors.password = passwordError
  if (form.password !== form.confirmPassword) errors.confirmPassword = '兩次輸入的密碼不同。'

  return errors
}
