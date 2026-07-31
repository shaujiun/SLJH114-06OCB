import { createClient } from '@supabase/supabase-js'
import { mkdir, readFile, readdir, writeFile } from 'node:fs/promises'
import path from 'node:path'
import process from 'node:process'

const projectRoot = process.cwd()
const backupDirectory = path.join(projectRoot, 'backups')
const capturedAt = new Date()
const dateLabel = capturedAt.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}Z$/, 'Z')
const vocabularyTableNames = ['profiles', 'vocabulary', 'student_progress', 'mastered_words']

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

    if (error?.code === 'PGRST205' || error?.code === '42P01') return null
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

async function readContactBookSchema() {
  const migrationDirectory = path.join(projectRoot, 'supabase', 'migrations')
  const migrationNames = (await readdir(migrationDirectory))
    .filter((name) => name.endsWith('.sql'))
    .sort()
  const migrations = []
  const tableNames = new Set(vocabularyTableNames)

  for (const migrationName of migrationNames) {
    const migrationPath = path.join(migrationDirectory, migrationName)
    const sql = await readFile(migrationPath, 'utf8')
    migrations.push(`-- ===== ${migrationName} =====\n${sql.trim()}\n`)
    for (const match of sql.matchAll(/create\s+table\s+if\s+not\s+exists\s+public\.([a-zA-Z0-9_]+)/gi)) {
      tableNames.add(match[1])
    }
  }

  return {
    migrationSchema: migrations.join('\n'),
    tableNames: [...tableNames].sort(),
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

  const { migrationSchema, tableNames } = await readContactBookSchema()
  const data = { capturedAt: capturedAt.toISOString(), tables: {}, authUsers: [] }
  for (const tableName of tableNames) {
    const rows = await readAllRows(client, tableName)
    if (rows !== null) data.tables[tableName] = rows
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
  const vocabularySchema = await readFile(localSchemaPath, 'utf8')
  const localSchema = [
    '-- ===== English vocabulary base schema =====',
    vocabularySchema.trim(),
    '',
    '-- ===== Contact book and shared project migrations =====',
    migrationSchema.trim(),
    '',
  ].join('\n')

  const dataPath = path.join(backupDirectory, `shared-supabase-data-${dateLabel}.json`)
  const openApiPath = path.join(backupDirectory, `shared-supabase-openapi-${dateLabel}.json`)
  const schemaPath = path.join(backupDirectory, `shared-supabase-schema-${dateLabel}.sql`)

  await writeFile(dataPath, jsonText(data), { encoding: 'utf8', flag: 'wx' })
  await writeFile(openApiPath, jsonText(openApiSchema), { encoding: 'utf8', flag: 'wx' })
  await writeFile(schemaPath, localSchema, { encoding: 'utf8', flag: 'wx' })

  const counts = Object.fromEntries(
    Object.entries(data.tables).map(([tableName, rows]) => [tableName, rows.length]),
  )
  console.log(JSON.stringify({ dataPath, openApiPath, schemaPath, counts, authUsers: data.authUsers.length }))
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : 'Backup failed.')
  process.exitCode = 1
})
