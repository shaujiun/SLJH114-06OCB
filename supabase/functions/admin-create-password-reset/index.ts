import { createClient } from 'npm:@supabase/supabase-js@2.110.7'
import { createFunctionClients } from '../_shared/clients.ts'
import { handlePreflight, jsonResponse, methodNotAllowed, readJson } from '../_shared/http.ts'
import {
  generateActivationCode,
  passwordResetCodeHash,
  validateStudentId,
  validateUuid,
} from '../_shared/security.ts'

function bearerToken(request: Request) {
  return (request.headers.get('authorization')?.trim() || '').replace(/^Bearer\s+/i, '')
}

Deno.serve(async (request) => {
  const preflight = handlePreflight(request)
  if (preflight) return preflight
  if (request.method !== 'POST') return methodNotAllowed()

  try {
    const token = bearerToken(request)
    if (!token) return jsonResponse({ error: '請先以管理員身分登入。' }, 401)

    const body = await readJson(request)
    const studentId = body?.studentId
    const studentIdCode = typeof body?.studentIdCode === 'string'
      ? body.studentIdCode.trim()
      : ''
    if (!validateUuid(studentId) || !validateStudentId(studentIdCode)) {
      return jsonResponse({ error: '學生資料格式不正確。' }, 400)
    }

    const { env, admin, publicClient } = createFunctionClients()
    const { data: userData, error: userError } = await publicClient.auth.getUser(token)
    if (userError || !userData.user) {
      return jsonResponse({ error: '登入狀態已失效，請重新登入。' }, 401)
    }

    const { data: profile, error: profileError } = await admin
      .from('contact_book_profiles')
      .select('user_type,approval_status,is_active')
      .eq('id', userData.user.id)
      .single()
    if (profileError
      || profile?.user_type !== 'admin'
      || profile.approval_status !== 'approved'
      || !profile.is_active) {
      return jsonResponse({ error: '只有管理員可以產生密碼重設碼。' }, 403)
    }

    const resetCode = generateActivationCode()
    const codeHash = await passwordResetCodeHash(
      studentIdCode,
      resetCode,
      env.activationCodeHmacSecret,
    )
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
    const userClient = createClient(env.supabaseUrl, env.publicKey, {
      global: { headers: { Authorization: `Bearer ${token}` } },
      auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false },
    })
    const { data: student, error: resetError } = await userClient.rpc(
      'admin_replace_student_password_reset',
      {
        p_student_id: studentId,
        p_code_hash: codeHash,
        p_expires_at: expiresAt,
      },
    )

    if (resetError) {
      const message = resetError.message?.includes('student_not_activated')
        ? '學生帳號尚未啟用，請改用一次性啟用碼。'
        : '無法產生密碼重設碼，請稍後再試。'
      return jsonResponse({ error: message }, 400)
    }

    return jsonResponse({
      ok: true,
      student,
      passwordReset: { code: resetCode, expiresAt },
    })
  } catch (error) {
    console.error('admin-create-password-reset failed', error instanceof Error ? error.message : 'unknown')
    return jsonResponse({ error: '無法產生密碼重設碼，請稍後再試。' }, 500)
  }
})
