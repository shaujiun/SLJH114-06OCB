param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[A-Za-z0-9._-]{4,32}$')]
  [string]$Username
)

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
  $env:ADMIN_USERNAME = $Username

  npm run bootstrap:admin
  if ($LASTEXITCODE -ne 0) {
    throw 'Administrator setup failed.'
  }

  Write-Host 'The first contact book administrator is ready.' -ForegroundColor Green
} finally {
  Remove-Item Env:SUPABASE_URL -ErrorAction SilentlyContinue
  Remove-Item Env:SUPABASE_SERVICE_ROLE_KEY -ErrorAction SilentlyContinue
  Remove-Item Env:ADMIN_USERNAME -ErrorAction SilentlyContinue
  $serviceRoleKey = $null
  $keys = $null
  $rawKeys = $null
}
