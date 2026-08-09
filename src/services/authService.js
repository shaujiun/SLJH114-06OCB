import { requireSupabase } from '../lib/supabase.js'

const functionNames = {
  login: import.meta.env.VITE_ACCOUNT_LOGIN_FUNCTION || 'account-login',
  activateStudent: import.meta.env.VITE_STUDENT_ACTIVATION_FUNCTION || 'student-activate',
  resetStudentPassword: import.meta.env.VITE_STUDENT_PASSWORD_RESET_FUNCTION
    || 'student-reset-password',
  registerTeacher: import.meta.env.VITE_TEACHER_REGISTRATION_FUNCTION || 'teacher-register',
}

async function readFunctionError(error) {
  const context = error?.context
  if (context && typeof context.clone === 'function') {
    try {
      const payload = await context.clone().json()
      if (typeof payload?.error === 'string' && payload.error.trim()) {
        return payload.error.trim()
      }
    } catch {
      // The response may not be JSON. Fall back to the client error below.
    }
  }

  const message = error?.message?.trim()
  if (message && message !== 'Edge Function returned a non-2xx status code') {
    return message
  }
  return '系統目前無法完成操作，請稍後再試或通知導師。'
}

async function invoke(functionName, body) {
  const client = requireSupabase()
  const { data, error } = await client.functions.invoke(functionName, { body })

  if (error) {
    throw new Error(await readFunctionError(error))
  }

  if (data?.error) {
    throw new Error(data.error)
  }

  return data
}

async function applyReturnedSession(data) {
  if (!data?.session?.access_token || !data?.session?.refresh_token) {
    return
  }

  const client = requireSupabase()
  const { error } = await client.auth.setSession({
    access_token: data.session.access_token,
    refresh_token: data.session.refresh_token,
  })

  if (error) {
    throw new Error('登入憑證無法保存，請重新登入。')
  }
}

export async function loginAccount({ accountType, username, password }) {
  const data = await invoke(functionNames.login, {
    accountType,
    username: username.trim(),
    password,
  })

  await applyReturnedSession(data)
  return data
}

export async function activateStudent({ studentId, activationCode, password }) {
  const data = await invoke(functionNames.activateStudent, {
    studentId: studentId.trim(),
    activationCode: activationCode.trim(),
    password,
  })

  await applyReturnedSession(data)
  return data
}

export async function resetStudentPassword({ studentId, resetCode, password }) {
  const data = await invoke(functionNames.resetStudentPassword, {
    studentId: studentId.trim(),
    resetCode: resetCode.trim(),
    password,
  })

  await applyReturnedSession(data)
  return data
}

export function registerTeacher({ username, displayName, password }) {
  return invoke(functionNames.registerTeacher, {
    username: username.trim(),
    displayName: displayName.trim(),
    password,
  })
}

export async function signOut() {
  const client = requireSupabase()
  const { error } = await client.auth.signOut()
  if (error) throw error
}

export async function restoreCurrentAccount() {
  const client = requireSupabase()
  const { data: sessionData, error: sessionError } = await client.auth.getSession()

  if (sessionError) throw sessionError
  const userId = sessionData.session?.user?.id
  if (!userId) return null

  const { data: profile, error: profileError } = await client
    .from('contact_book_profiles')
    .select('display_name,user_type,approval_status,is_active')
    .eq('id', userId)
    .single()

  if (profileError) throw profileError
  if (!profile.is_active) return null

  return {
    displayName: profile.display_name,
    role: profile.user_type,
    approvalStatus: profile.approval_status,
  }
}
