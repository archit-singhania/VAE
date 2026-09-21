param(
  [string]$OutputDirectory = "./backups",
  [Parameter(Mandatory = $true)][string]$RestoreDatabaseUrl
)

$ErrorActionPreference = "Stop"
if (-not $env:AEVRA_DATABASE_URL) {
  throw "Set AEVRA_DATABASE_URL before running the backup verification job."
}

$backupScript = Join-Path $PSScriptRoot "backup-postgres.ps1"
& $backupScript -OutputDirectory $OutputDirectory
if ($LASTEXITCODE -ne 0) { throw "The backup command failed." }

$latest = Get-ChildItem -LiteralPath $OutputDirectory -Filter "aevra-*.dump" |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1
if ($null -eq $latest) { throw "No backup archive was created." }

$restoreUrl = $RestoreDatabaseUrl -replace '^postgresql\+psycopg://', 'postgresql://'
& pg_restore --exit-on-error --single-transaction --no-owner --dbname=$restoreUrl $latest.FullName
if ($LASTEXITCODE -ne 0) {
  throw "Restore verification failed. Do not promote this backup."
}
Write-Output "Backup and restore verification succeeded: $($latest.FullName)"
