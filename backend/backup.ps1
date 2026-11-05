param(
    [string]$EnvFile = "$PSScriptRoot/.env.production",
    [string]$Project = 'tazekal-production',
    [string]$OutputDirectory = "$PSScriptRoot/backups"
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $EnvFile -PathType Leaf)) { throw 'Configuration file does not exist.' }
$composeFile = Join-Path $PSScriptRoot 'compose.production.yaml'
$container = & docker compose --env-file $EnvFile -p $Project -f $composeFile ps -q db
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($container)) { throw 'Database container is not running.' }
$container = $container.Trim()
$null = New-Item -ItemType Directory -Path $OutputDirectory -Force
$suffix = [guid]::NewGuid().ToString('N')
$filename = 'tazekal-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + $suffix + '.dump'
$destination = Join-Path (Resolve-Path -LiteralPath $OutputDirectory).Path $filename
$temporaryDump = '/tmp/' + $filename
try {
    & docker exec $container pg_dump -U tazekal -d tazekal -Fc -f $temporaryDump
    if ($LASTEXITCODE -ne 0) { throw 'Database backup failed.' }
    & docker cp "${container}:$temporaryDump" $destination
    if ($LASTEXITCODE -ne 0) { throw 'Backup could not be copied.' }
    if ((Get-Item -LiteralPath $destination).Length -eq 0) { throw 'Backup is empty.' }
    Write-Output "Backup saved: $destination"
} finally {
    & docker exec $container rm -f $temporaryDump
}
