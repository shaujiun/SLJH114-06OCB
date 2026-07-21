import { corsHeaders } from 'npm:@supabase/supabase-js@2.110.7/cors'

const responseHeaders = {
  ...corsHeaders,
  'Content-Type': 'application/json; charset=utf-8',
  'Cache-Control': 'no-store',
}

export function handlePreflight(request: Request) {
  if (request.method !== 'OPTIONS') return null
  return new Response(JSON.stringify({ ok: true }), { headers: responseHeaders })
}

export function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: responseHeaders,
  })
}

export function methodNotAllowed() {
  return jsonResponse({ error: '不支援的請求方式。' }, 405)
}

export function genericAuthError(status = 400) {
  return jsonResponse({ error: '帳號資料不正確，請重新確認。' }, status)
}

export function rateLimitError() {
  return jsonResponse({ error: '嘗試次數過多，請稍後再試。' }, 429)
}

export async function readJson(request: Request) {
  try {
    return await request.json()
  } catch {
    return null
  }
}
