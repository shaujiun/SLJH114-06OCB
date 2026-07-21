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
  normalizeLoginId,
  sharedAccountEmail,
  validateDisplayName,
  validatePassword,
  validateTeacherUsername,
} from '../_shared/security.ts'

Deno.serve(async (request) => {
  const preflight = handlePreflight(request)
  if (preflight) return preflight
  if (request.method !== 'POST') return methodNotAllowed()

  let createdUserId: string | null = null

  try {
    const body = await readJson(request)
    const username = normalizeLoginId(body?.username)
    const displayName = typeof body?.displayName === 'string' ? body.displayName.trim() : ''
    const password = body?.password

    if (!validateTeacherUsername(username)
      || !validateDisplayName(displayName)
      || !validatePassword(password)) {
      return genericAuthError()
    }

    const { env, admin, publicClient } = createFunctionClients()
    const allowed = await consumeRateLimit({
      admin,
      request,
      secret: env.rateLimitHmacSecret,
      action: 'teacher-register',
      accountKey: 'teacher-registration',
      limit: 5,
      windowSeconds: 60 * 60,
    })
    if (!allowed) return rateLimitError()

    const email = sharedAccountEmail(username)
    const { data: existingAuth } = await publicClient.auth.signInWithPassword({ email, password })
    let profileId = existingAuth.user?.id ?? null

    if (!profileId) {
      const { data: created, error: createError } = await admin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: {
          username,
          role: 'student',
          account_type: 'teacher',
          app_scope: 'vocab',
        },
      })

      if (createError || !created.user) return genericAuthError()
      createdUserId = created.user.id
      profileId = created.user.id
    }

    const { error: profileError } = await admin.rpc('register_pending_teacher', {
      p_profile_id: profileId,
      p_username: username,
      p_display_name: displayName,
    })

    if (profileError) {
      if (createdUserId) {
        await admin.auth.admin.deleteUser(createdUserId)
        createdUserId = null
      }
      return genericAuthError()
    }

    return jsonResponse({
      ok: true,
      profile: {
        displayName,
        role: 'teacher',
        approvalStatus: 'pending',
      },
    })
  } catch (error) {
    if (createdUserId) {
      try {
        const { admin } = createFunctionClients()
        await admin.auth.admin.deleteUser(createdUserId)
      } catch {
        console.error('teacher-register cleanup failed')
      }
    }
    console.error('teacher-register failed', error instanceof Error ? error.message : 'unknown')
    return genericAuthError(500)
  }
})
