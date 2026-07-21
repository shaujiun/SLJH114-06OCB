import { createClient } from 'npm:@supabase/supabase-js@2.110.7'
import { getFunctionEnv } from './env.ts'

export function createFunctionClients() {
  const env = getFunctionEnv()
  const authOptions = {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  }

  return {
    env,
    admin: createClient(env.supabaseUrl, env.serviceRoleKey, authOptions),
    publicClient: createClient(env.supabaseUrl, env.publicKey, authOptions),
  }
}
