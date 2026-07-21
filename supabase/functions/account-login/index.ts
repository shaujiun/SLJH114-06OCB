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
  canUseAccountLogin,
  normalizeLoginId,
  sharedAccountEmail,
  validateAccountPassword,
  validateStudentId,
  validateTeacherUsername,
} from '../_shared/security.ts'

Deno.serve(async (request) => {
  const preflight = handlePreflight(request)
  if (preflight) return preflight
  if (request.method !== 'POST') return methodNotAllowed()

  try {
    const body = await readJson(request)
    const accountType = body?.accountType === 'student'
      ? 'student'
      : body?.accountType === 'teacher'
        ? 'teacher'
        : null
    const username = normalizeLoginId(body?.username)
    const password = body?.password

    if (!accountType
      || !validateAccountPassword(password)
      || (accountType === 'student' && !validateStudentId(username))
      || (accountType === 'teacher' && !validateTeacherUsername(username))) {
      return genericAuthError()
    }

    const { env, admin, publicClient } = createFunctionClients()
    const allowed = await consumeRateLimit({
      admin,
      request,
      secret: env.rateLimitHmacSecret,
      action: 'account-login',
      accountKey: `${accountType}:${username}`,
      limit: 10,
      windowSeconds: 15 * 60,
    })
    if (!allowed) return rateLimitError()

    const email = sharedAccountEmail(username)
    const { data: authData, error: authError } = await publicClient.auth.signInWithPassword({
      email,
      password,
    })

    if (authError || !authData.user || !authData.session) {
      return genericAuthError(401)
    }

    const { data: profile, error: profileError } = await admin
      .from('contact_book_profiles')
      .select('display_name,user_type,approval_status,is_active')
      .eq('id', authData.user.id)
      .single()

    if (profileError
      || !profile
      || !canUseAccountLogin(accountType, profile.user_type)
      || !profile.is_active) {
      return genericAuthError(401)
    }

    if (profile.approval_status === 'pending') {
      return jsonResponse({
        profile: {
          displayName: profile.display_name,
          role: profile.user_type,
          approvalStatus: profile.approval_status,
        },
      })
    }

    if (profile.approval_status !== 'approved') {
      return genericAuthError(403)
    }

    return jsonResponse({
      session: {
        access_token: authData.session.access_token,
        refresh_token: authData.session.refresh_token,
      },
      profile: {
        displayName: profile.display_name,
        role: profile.user_type,
        approvalStatus: profile.approval_status,
      },
    })
  } catch (error) {
    console.error('account-login failed', error instanceof Error ? error.message : 'unknown')
    return genericAuthError(500)
  }
})
