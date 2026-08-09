import { createFunctionClients } from '../_shared/clients.ts'
import {
  genericAuthError,
  handlePreflight,
  jsonResponse,
  methodNotAllowed,
  rateLimitError,
  readJson,
} from '../_shared/http.ts'
import { consumeRateLimit } from '../_shared/rateLimit.ts'
import {
  normalizeActivationCode,
  normalizeLoginId,
  passwordResetCodeHash,
  sharedAccountEmail,
  validateActivationCode,
  validatePassword,
  validateStudentId,
} from '../_shared/security.ts'

Deno.serve(async (request) => {
  const preflight = handlePreflight(request)
  if (preflight) return preflight
  if (request.method !== 'POST') return methodNotAllowed()

  try {
    const body = await readJson(request)
    const studentId = normalizeLoginId(body?.studentId)
    const resetCode = normalizeActivationCode(body?.resetCode)
    const password = body?.password
    if (!validateStudentId(studentId)
      || !validateActivationCode(resetCode)
      || !validatePassword(password)) {
      return jsonResponse({
        error: '請確認學號與重設碼；新密碼須至少 8 個字元，並同時包含英文字母與數字。',
      }, 400)
    }

    const { env, admin, publicClient } = createFunctionClients()
    const allowed = await consumeRateLimit({
      admin,
      request,
      secret: env.rateLimitHmacSecret,
      action: 'student-reset-password',
      accountKey: studentId,
      limit: 8,
      windowSeconds: 15 * 60,
    })
    if (!allowed) return rateLimitError()

    const codeHash = await passwordResetCodeHash(
      studentId,
      resetCode,
      env.activationCodeHmacSecret,
    )
    const { data: reset, error: consumeError } = await admin.rpc(
      'consume_student_password_reset',
      { p_student_id_code: studentId, p_code_hash: codeHash },
    )
    const result = reset?.[0]
    if (consumeError || !result?.profile_id) {
      if (consumeError) {
        console.error('student-reset-password reset validation failed', consumeError.message)
      }
      return jsonResponse({
        error: '重設碼不正確、已使用或已超過 24 小時，請導師重新產生一組重設碼。',
      }, 400)
    }

    const { error: updateError } = await admin.auth.admin.updateUserById(
      result.profile_id,
      { password },
    )
    if (updateError) {
      console.error('student-reset-password auth update failed', updateError.message)
      return jsonResponse({ error: '密碼更新失敗，請導師重新產生一組重設碼後再試。' }, 500)
    }

    const { data: signedIn, error: signInError } = await publicClient.auth.signInWithPassword({
      email: sharedAccountEmail(studentId),
      password,
    })
    if (signInError || !signedIn.session) {
      console.error(
        'student-reset-password automatic sign-in failed',
        signInError?.message || 'session_missing',
      )
      return jsonResponse({
        error: '新密碼已設定完成，但自動登入失敗；請返回登入頁，使用學號與新密碼登入。',
      }, 409)
    }

    return jsonResponse({
      ok: true,
      session: {
        access_token: signedIn.session.access_token,
        refresh_token: signedIn.session.refresh_token,
      },
      profile: {
        displayName: result.display_name,
        role: 'student',
        approvalStatus: 'approved',
      },
    })
  } catch (error) {
    console.error('student-reset-password failed', error instanceof Error ? error.message : 'unknown')
    return genericAuthError(500)
  }
})
