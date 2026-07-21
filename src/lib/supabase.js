import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL?.trim()
const supabasePublishableKey = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY?.trim()

export const isSupabaseConfigured = Boolean(
  supabaseUrl
    && supabasePublishableKey
    && !supabaseUrl.includes('your-project')
    && !supabasePublishableKey.includes('your-publishable-key'),
)

export const supabase = isSupabaseConfigured
  ? createClient(supabaseUrl, supabasePublishableKey, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true,
      },
    })
  : null

export function requireSupabase() {
  if (!supabase) {
    const error = new Error('Supabase 尚未連接，請先完成第二階段的專案設定。')
    error.code = 'CONFIG_MISSING'
    throw error
  }

  return supabase
}
