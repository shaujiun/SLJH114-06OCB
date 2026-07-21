$ErrorActionPreference = 'Stop'

try {
  $rawKeys = npx supabase projects api-keys --project-ref bipvbfpviogptejqqkdk --reveal --output json --output-format text --agent no 2>$null
  if ($LASTEXITCODE -ne 0) {
    throw 'Unable to retrieve Supabase project credentials.'
  }

  $keys = $rawKeys | ConvertFrom-Json
  $serviceRoleKey = $keys |
    Where-Object { $_.type -eq 'legacy' -and $_.name -eq 'service_role' } |
    Select-Object -First 1 -ExpandProperty api_key

  if (-not $serviceRoleKey) {
    throw 'Supabase service role key was not found.'
  }

  $env:SUPABASE_URL = 'https://bipvbfpviogptejqqkdk.supabase.co'
  $env:SUPABASE_SERVICE_ROLE_KEY = $serviceRoleKey

  npm run backup:supabase
  if ($LASTEXITCODE -ne 0) {
    throw 'Backup failed.'
  }

  Write-Host 'Supabase read-only backup completed.' -ForegroundColor Green
} finally {
  Remove-Item Env:SUPABASE_URL -ErrorAction SilentlyContinue
  Remove-Item Env:SUPABASE_SERVICE_ROLE_KEY -ErrorAction SilentlyContinue
  $serviceRoleKey = $null
  $keys = $null
  $rawKeys = $null
}
