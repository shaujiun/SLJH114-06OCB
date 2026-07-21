import process from 'node:process'
import { randomInt } from 'node:crypto'
import { readFile } from 'node:fs/promises'

const localEnvironment = Object.fromEntries(
  (await readFile('.env.local', 'utf8'))
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith('#') && line.includes('='))
    .map((line) => {
      const separator = line.indexOf('=')
      return [line.slice(0, separator), line.slice(separator + 1)]
    }),
)

const supabaseUrl = process.env.VITE_SUPABASE_URL?.trim()
  || localEnvironment.VITE_SUPABASE_URL?.trim()
const publishableKey = process.env.VITE_SUPABASE_PUBLISHABLE_KEY?.trim()
  || localEnvironment.VITE_SUPABASE_PUBLISHABLE_KEY?.trim()

if (!supabaseUrl || !publishableKey) {
  throw new Error('The frontend Supabase configuration is missing.')
}

const functionsUrl = `${supabaseUrl}/functions/v1`
const publicHeaders = {
  apikey: publishableKey,
  Authorization: `Bearer ${publishableKey}`,
}
const unusedStudentId = Array.from({ length: 20 }, () => randomInt(0, 10)).join('')

const tests = [
  {
    name: 'account-login',
    body: {
      accountType: 'student',
      username: unusedStudentId,
      password: 'SmokeTest1',
    },
    expectedStatus: 401,
  },
  {
    name: 'student-activate',
    body: {
      studentId: unusedStudentId,
      activationCode: 'SMOKE1',
      password: 'SmokeTest1',
    },
    expectedStatus: 400,
  },
  {
    name: 'student-reset-password',
    body: {
      studentId: unusedStudentId,
      resetCode: 'RESET234',
      password: 'SmokeTest1',
    },
    expectedStatus: 400,
  },
  {
    name: 'teacher-register',
    body: {},
    expectedStatus: 400,
  },
]

for (const test of tests) {
  const preflight = await fetch(`${functionsUrl}/${test.name}`, {
    method: 'OPTIONS',
    headers: { Origin: 'http://127.0.0.1:4173' },
  })
  if (!preflight.ok || !preflight.headers.get('access-control-allow-origin')) {
    throw new Error(`${test.name} failed the CORS preflight check.`)
  }

  const response = await fetch(`${functionsUrl}/${test.name}`, {
    method: 'POST',
    headers: { ...publicHeaders, 'Content-Type': 'application/json' },
    body: JSON.stringify(test.body),
  })
  const responseBody = await response.json().catch(() => null)

  if (response.status !== test.expectedStatus || typeof responseBody?.error !== 'string') {
    throw new Error(
      `${test.name} returned unexpected response: HTTP ${response.status}`,
    )
  }

  console.log(`${test.name}: HTTP ${response.status}, CORS ok`)
}

const protectedResponse = await fetch(`${functionsUrl}/admin-create-student`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: '{}',
})
if (protectedResponse.status !== 401) {
  throw new Error(
    `admin-create-student accepted an unauthenticated request: HTTP ${protectedResponse.status}`,
  )
}
console.log('admin-create-student: HTTP 401 without authentication, protected')

const regenerateResponse = await fetch(`${functionsUrl}/admin-regenerate-activation`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: '{}',
})
if (regenerateResponse.status !== 401) {
  throw new Error(
    `admin-regenerate-activation accepted an unauthenticated request: HTTP ${regenerateResponse.status}`,
  )
}
console.log('admin-regenerate-activation: HTTP 401 without authentication, protected')

const passwordResetResponse = await fetch(`${functionsUrl}/admin-create-password-reset`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: '{}',
})
if (passwordResetResponse.status !== 401) {
  throw new Error(
    `admin-create-password-reset accepted an unauthenticated request: HTTP ${passwordResetResponse.status}`,
  )
}
console.log('admin-create-password-reset: HTTP 401 without authentication, protected')
