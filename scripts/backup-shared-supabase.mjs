import { createClient } from '@supabase/supabase-js'
import { mkdir, readFile, writeFile } from 'node:fs/promises'
import path from 'node:path'
import process from 'node:process'

const projectRoot = process.cwd()
const backupDirectory = path.join(projectRoot, 'backups')
const dateLabel = new Date().toISOString().slice(0, 10)
const tableNames = ['profiles', 'vocabulary', 'student_progress', 'mastered_words']

function requiredEnvironment(name) {
  const value = process.env[name]?.trim()
  if (!value) throw new Error(`Missing required environment value: ${name}`)
  return value
}

function jsonText(value) {
  return `${JSON.stringify(value, null, 2)}\n`
}

async function readAllRows(client, tableName) {
  const pageSize = 1000
  const rows = []

  for (let from = 0; ; from += pageSize) {
    const { data, error } = await client
      .from(tableName)
      .select('*')
      .range(from, from + pageSize - 1)

    if (error) throw new Error(`Unable to back up ${tableName}: ${error.message}`)
    rows.push(...data)
    if (data.length < pageSize) return rows
  }
}

async function readAllAuthUsers(client) {
  const users = []
  const perPage = 1000

  for (let page = 1; ; page += 1) {
    const { data, error } = await client.auth.admin.listUsers({ page, perPage })
    if (error) throw new Error(`Unable to back up Auth users: ${error.message}`)

    users.push(...data.users.map((user) => ({
      id: user.id,
      email: user.email,
      created_at: user.created_at,
      updated_at: user.updated_at,
      last_sign_in_at: user.last_sign_in_at,
      app_metadata: user.app_metadata,
      user_metadata: user.user_metadata,
    })))

    if (data.users.length < perPage) return users
  }
}

async function main() {
  const supabaseUrl = requiredEnvironment('SUPABASE_URL')
  const serviceRoleKey = requiredEnvironment('SUPABASE_SERVICE_ROLE_KEY')
  const client = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  })

  await mkdir(backupDirectory, { recursive: true })

  const data = { capturedAt: new Date().toISOString(), tables: {}, authUsers: [] }
  for (const tableName of tableNames) {
    data.tables[tableName] = await readAllRows(client, tableName)
  }
  data.authUsers = await readAllAuthUsers(client)

  const openApiResponse = await fetch(`${supabaseUrl}/rest/v1/`, {
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      Accept: 'application/openapi+json',
    },
  })
  if (!openApiResponse.ok) {
    throw new Error(`Unable to back up REST schema: HTTP ${openApiResponse.status}`)
  }
  const openApiSchema = await openApiResponse.json()

  const localSchemaPath = path.resolve(
    projectRoot,
    '..',
    '英文單字系統',
    'supabase-schema.sql',
  )
  const localSchema = await readFile(localSchemaPath, 'utf8')

  const dataPath = path.join(backupDirectory, `english-vocab-data-${dateLabel}.json`)
  const openApiPath = path.join(backupDirectory, `english-vocab-openapi-${dateLabel}.json`)
  const schemaPath = path.join(backupDirectory, `english-vocab-schema-${dateLabel}.sql`)

  await writeFile(dataPath, jsonText(data), { encoding: 'utf8', flag: 'wx' })
  await writeFile(openApiPath, jsonText(openApiSchema), { encoding: 'utf8', flag: 'wx' })
  await writeFile(schemaPath, localSchema, { encoding: 'utf8', flag: 'wx' })

  const counts = Object.fromEntries(
    tableNames.map((tableName) => [tableName, data.tables[tableName].length]),
  )
  console.log(JSON.stringify({ dataPath, openApiPath, schemaPath, counts, authUsers: data.authUsers.length }))
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : 'Backup failed.')
  process.exitCode = 1
})
