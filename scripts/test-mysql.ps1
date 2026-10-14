$ErrorActionPreference = 'Stop'
$labRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'start-lab.ps1') -DatabaseOnly
$credentials = Get-Content (Join-Path $labRoot '.cache\mysql\credentials.json') -Raw | ConvertFrom-Json
$env:DB_URL = 'jdbc:mysql://127.0.0.1:3307/securitydb_test'
$env:DB_USERNAME = $credentials.username
$env:DB_PASSWORD = $credentials.appPassword
if (!$env:JAVA_HOME) {
    $jdk = Get-ChildItem 'C:\Program Files\Java\jdk-*', 'C:\Program Files\Eclipse Adoptium\jdk-*' -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName 'bin\javac.exe') } | Select-Object -First 1
    if ($jdk) { $env:JAVA_HOME = $jdk.FullName }
}
Push-Location $labRoot
try {
    & '.\mvnw.cmd' --batch-mode '-Dlab.test.profile=mysql' verify
    exit $LASTEXITCODE
} finally { Pop-Location }
