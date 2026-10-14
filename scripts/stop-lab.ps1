$ErrorActionPreference = 'Stop'
$labRoot = Split-Path -Parent $PSScriptRoot
$runtime = Join-Path $labRoot '.cache\mysql'
$statePath = Join-Path $runtime 'app.json'
if (Test-Path -LiteralPath $statePath) {
    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    $process = Get-Process -Id $state.processId -ErrorAction SilentlyContinue
    if ($process -and $process.StartTime.ToUniversalTime().ToString('o') -eq $state.startTime) {
        Stop-Process -Id $process.Id
        Write-Host 'Aplicacion detenida.'
    }
}
$admin = Join-Path $runtime 'mysql-8.4.11-winx64\bin\mysqladmin.exe'
$config = Join-Path $runtime 'client.ini'
if ((Test-Path -LiteralPath $admin) -and (Test-Path -LiteralPath $config)) {
    & $admin "--defaults-extra-file=$config" shutdown
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo detener MySQL o ya estaba detenido.' }
    Write-Host 'MySQL detenido. Los datos se conservan.'
}
