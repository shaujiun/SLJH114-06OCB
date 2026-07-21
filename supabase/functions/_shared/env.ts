function required(name: string) {
  const value = Deno.env.get(name)?.trim()
  if (!value) throw new Error(`Missing required secret: ${name}`)
  return value
}

export function getFunctionEnv() {
  return {
    supabaseUrl: required('SUPABASE_URL'),
    serviceRoleKey: required('SUPABASE_SERVICE_ROLE_KEY'),
    publicKey: Deno.env.get('SUPABASE_ANON_KEY')?.trim()
      || required('SB_PUBLISHABLE_KEY'),
    activationCodeHmacSecret: required('ACTIVATION_CODE_HMAC_SECRET'),
    rateLimitHmacSecret: required('RATE_LIMIT_HMAC_SECRET'),
  }
}
