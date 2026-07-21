import { createClient } from 'npm:@supabase/supabase-js@2.110.7'
import { createFunctionClients } from '../_shared/clients.ts'
import {
  handlePreflight,
  jsonResponse,
  methodNotAllowed,
  readJson,
} from '../_shared/http.ts'
import {
  activationCodeHash,
  generateActivationCode,
  normalizeLoginId,
  validateDisplayName,
  validateGroupCode,
  validateSeatNumber,
  validateStudentId,
  validateUuid,
} from '../_shared/security.ts'

function bearerToken(request: Request) {
  const authorization = request.headers.get('authorization')?.trim() || ''
  return authorization.replace(/^Bearer\s+/i, '')
}

Deno.serve(async (request) => {
  const preflight = handlePreflight(request)
  if (preflight) return preflight
  if (request.method !== 'POST') return methodNotAllowed()

  try {
    const token = bearerToken(request)
    if (!token) return jsonResponse({ error: '請先以管理員身分登入。' }, 401)

    const body = await readJson(request)
    const studentId = normalizeLoginId(body?.studentId)
    const seatNumber = Number(body?.seatNumber)
    const fullName = typeof body?.fullName === 'string' ? body.fullName.trim() : ''
    const mathGroup = body?.mathGroup
    const englishGroup = body?.englishGroup
    const classId = body?.classId
    const academicTermId = body?.academicTermId

    if (!validateStudentId(studentId)
      || !validateSeatNumber(seatNumber)
      || !validateDisplayName(fullName)
      || !validateGroupCode(mathGroup)
      || !validateGroupCode(englishGroup)
      || !validateUuid(classId)
      || !validateUuid(academicTermId)) {
      return jsonResponse({ error: '學生資料格式不正確，請重新確認。' }, 400)
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
      return jsonResponse({ error: '只有管理員可以建立學生。' }, 403)
    }

    const activationCode = generateActivationCode()
    const codeHash = await activationCodeHash(
      studentId,
      activationCode,
      env.activationCodeHmacSecret,
    )
    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString()

    const userClient = createClient(env.supabaseUrl, env.publicKey, {
      global: { headers: { Authorization: `Bearer ${token}` } },
      auth: {
        autoRefreshToken: false,
        persistSession: false,
        detectSessionInUrl: false,
      },
    })
    const { data: student, error: createError } = await userClient.rpc(
      'admin_create_student',
      {
        p_class_id: classId,
        p_academic_term_id: academicTermId,
        p_student_id_code: studentId,
        p_seat_number: seatNumber,
        p_full_name: fullName,
        p_math_group: mathGroup,
        p_english_group: englishGroup,
        p_code_hash: codeHash,
        p_expires_at: expiresAt,
      },
    )

    if (createError) {
      console.error('admin-create-student database error', createError.code)
      const status = createError.code === '23505' ? 409 : 400
      const message = status === 409
        ? '學號或座號已存在，請重新確認。'
        : '學生建立失敗，請重新確認班級與學期資料。'
      return jsonResponse({ error: message }, status)
    }

    return jsonResponse({
      ok: true,
      student,
      activation: {
        code: activationCode,
        expiresAt,
      },
    }, 201)
  } catch (error) {
    console.error('admin-create-student failed', error instanceof Error ? error.message : 'unknown')
    return jsonResponse({ error: '學生建立失敗，請稍後再試。' }, 500)
  }
})
