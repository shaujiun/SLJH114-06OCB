import type { SupabaseClient } from 'npm:@supabase/supabase-js@2.110.7'
import { hmacHex } from './security.ts'

function requestIp(request: Request) {
  const forwarded = request.headers.get('x-forwarded-for')?.split(',')[0]?.trim()
  return forwarded || request.headers.get('cf-connecting-ip')?.trim() || 'unknown'
}

export async function consumeRateLimit({
  admin,
  request,
  secret,
  action,
  accountKey,
  limit,
  windowSeconds,
}: {
  admin: SupabaseClient
  request: Request
  secret: string
  action: string
  accountKey: string
  limit: number
  windowSeconds: number
}) {
  const keyHash = await hmacHex(
    secret,
    `${action}:${requestIp(request)}:${accountKey}`,
  )
  const { data, error } = await admin.rpc('consume_auth_rate_limit', {
    p_key_hash: keyHash,
    p_action: action,
    p_limit: limit,
    p_window_seconds: windowSeconds,
  })

  if (error) throw error
  return data === true
}
