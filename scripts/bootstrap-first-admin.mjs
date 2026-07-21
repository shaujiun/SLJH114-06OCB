import { createClient } from '@supabase/supabase-js'
import process from 'node:process'

function requiredEnvironment(name) {
  const value = process.env[name]?.trim()
  if (!value) throw new Error(`Missing required environment value: ${name}`)
  return value
}

function normalizeUsername(value) {
  return value.trim().replace(/\s+/g, '').toLowerCase()
}

async function main() {
  const supabaseUrl = requiredEnvironment('SUPABASE_URL')
  const serviceRoleKey = requiredEnvironment('SUPABASE_SERVICE_ROLE_KEY')
  const username = normalizeUsername(requiredEnvironment('ADMIN_USERNAME'))

  if (!/^[a-z0-9._-]{4,32}$/.test(username)) {
    throw new Error('The administrator username format is invalid.')
  }

  const client = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  })

  const { data: target, error: targetError } = await client
    .from('contact_book_profiles')
    .select('id,username,display_name,user_type,approval_status,is_active')
    .eq('username', username)
    .maybeSingle()

  if (targetError) throw new Error(`Unable to find the teacher profile: ${targetError.message}`)
  if (!target) {
    throw new Error('No matching teacher registration was found. Register on the website first.')
  }

  const { count: adminCount, error: adminCountError } = await client
    .from('contact_book_profiles')
    .select('id', { count: 'exact', head: true })
    .eq('user_type', 'admin')
    .eq('approval_status', 'approved')
    .eq('is_active', true)

  if (adminCountError) {
    throw new Error(`Unable to verify current administrators: ${adminCountError.message}`)
  }

  if ((adminCount ?? 0) > 0) {
    if (target.user_type === 'admin'
      && target.approval_status === 'approved'
      && target.is_active) {
      console.log(JSON.stringify({ ok: true, alreadyConfigured: true, username }))
      return
    }
    throw new Error('The first administrator has already been configured.')
  }

  if (target.user_type !== 'teacher' || target.approval_status !== 'pending') {
    throw new Error('The matching account is not a pending teacher registration.')
  }

  const approvedAt = new Date().toISOString()
  const { data: updated, error: updateError } = await client
    .from('contact_book_profiles')
    .update({
      user_type: 'admin',
      approval_status: 'approved',
      is_active: true,
      approved_by: target.id,
      approved_at: approvedAt,
    })
    .eq('id', target.id)
    .select('username,display_name,user_type,approval_status,is_active')
    .single()

  if (updateError) throw new Error(`Unable to configure the first administrator: ${updateError.message}`)
  if (updated.user_type !== 'admin'
    || updated.approval_status !== 'approved'
    || !updated.is_active) {
    throw new Error('The first administrator verification failed.')
  }

  console.log(JSON.stringify({
    ok: true,
    alreadyConfigured: false,
    username: updated.username,
    displayName: updated.display_name,
  }))
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : 'Administrator setup failed.')
  process.exitCode = 1
})
