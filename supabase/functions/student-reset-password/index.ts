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
      return genericAuthError()
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
    if (consumeError || !result?.profile_id) return genericAuthError()

    const { error: updateError } = await admin.auth.admin.updateUserById(
      result.profile_id,
      { password },
    )
    if (updateError) {
      console.error('student-reset-password auth update failed', updateError.message)
      return jsonResponse({ error: '密碼更新失敗，請請導師重新產生重設碼。' }, 500)
    }

    const { data: signedIn, error: signInError } = await publicClient.auth.signInWithPassword({
      email: sharedAccountEmail(studentId),
      password,
    })
    if (signInError || !signedIn.session) return genericAuthError(500)

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
