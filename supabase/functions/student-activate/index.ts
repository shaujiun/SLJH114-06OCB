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
  activationCodeHash,
  normalizeActivationCode,
  normalizeLoginId,
  sharedAccountEmail,
  validateAccountPassword,
  validateActivationCode,
  validatePassword,
  validateStudentId,
} from '../_shared/security.ts'

Deno.serve(async (request) => {
  const preflight = handlePreflight(request)
  if (preflight) return preflight
  if (request.method !== 'POST') return methodNotAllowed()

  let createdUserId: string | null = null

  try {
    const body = await readJson(request)
    const studentId = normalizeLoginId(body?.studentId)
    const activationCode = normalizeActivationCode(body?.activationCode)
    const password = body?.password

    if (!validateStudentId(studentId)
      || !validateActivationCode(activationCode)
      || !validateAccountPassword(password)) {
      return genericAuthError()
    }

    const { env, admin, publicClient } = createFunctionClients()
    const allowed = await consumeRateLimit({
      admin,
      request,
      secret: env.rateLimitHmacSecret,
      action: 'student-activate',
      accountKey: studentId,
      limit: 8,
      windowSeconds: 15 * 60,
    })
    if (!allowed) return rateLimitError()

    const codeHash = await activationCodeHash(
      studentId,
      activationCode,
      env.activationCodeHmacSecret,
    )

    const { data: student } = await admin
      .from('students')
      .select('id,profile_id,student_activation_codes!inner(id)')
      .eq('student_id_code', studentId)
      .eq('is_active', true)
      .is('profile_id', null)
      .eq('student_activation_codes.code_hash', codeHash)
      .is('student_activation_codes.used_at', null)
      .gt('student_activation_codes.expires_at', new Date().toISOString())
      .maybeSingle()

    if (!student) return genericAuthError()

    const email = sharedAccountEmail(studentId)
    const { data: existingAuth } = await publicClient.auth.signInWithPassword({ email, password })
    let profileId = existingAuth.user?.id ?? null

    if (!profileId) {
      if (!validatePassword(password)) {
        return jsonResponse({
          error: '若尚未建立英文單字帳號，密碼需至少 8 個字元，並同時包含英文字母與數字。',
        }, 400)
      }

      const { data: created, error: createError } = await admin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: {
          username: studentId,
          role: 'student',
          account_type: 'student',
          app_scope: 'vocab',
        },
      })

      if (createError || !created.user) return genericAuthError()
      createdUserId = created.user.id
      profileId = created.user.id
    }

    const { data: activation, error: activationError } = await admin.rpc(
      'complete_student_activation',
      {
        p_student_id_code: studentId,
        p_code_hash: codeHash,
        p_profile_id: profileId,
        p_username: studentId,
      },
    )

    if (activationError || !activation?.length) {
      if (createdUserId) {
        await admin.auth.admin.deleteUser(createdUserId)
        createdUserId = null
      }
      return genericAuthError()
    }

    const { data: signedIn, error: signInError } = await publicClient.auth.signInWithPassword({
      email,
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
        displayName: activation[0].display_name,
        role: 'student',
        approvalStatus: 'approved',
      },
    })
  } catch (error) {
    if (createdUserId) {
      try {
        const { admin } = createFunctionClients()
        await admin.auth.admin.deleteUser(createdUserId)
      } catch {
        console.error('student-activate cleanup failed')
      }
    }
    console.error('student-activate failed', error instanceof Error ? error.message : 'unknown')
    return genericAuthError(500)
  }
})
