param([switch]$DatabaseOnly)
$ErrorActionPreference = 'Stop'
$labRoot = Split-Path -Parent $PSScriptRoot
$runtime = Join-Path $labRoot '.cache\mysql'
$mysqlHome = Join-Path $runtime 'mysql-8.4.11-winx64'
$dataDirectory = Join-Path $runtime 'data'
$mysql = Join-Path $mysqlHome 'bin\mysql.exe'
$mysqld = Join-Path $mysqlHome 'bin\mysqld.exe'
$credentialsPath = Join-Path $runtime 'credentials.json'
$clientConfig = Join-Path $runtime 'client.ini'
$appStatePath = Join-Path $runtime 'app.json'
# Puerto propio: no modifica una instalacion de MySQL que ya utilice 3306.
$mysqlPort = 3307
New-Item -ItemType Directory -Force -Path $runtime | Out-Null

function Test-LabPort([int]$Port) {
    $socket = [System.Net.Sockets.TcpClient]::new()
    try { $socket.Connect('127.0.0.1', $Port); return $true }
    catch { return $false }
    finally { $socket.Dispose() }
}

function Invoke-LabSql([string]$Sql, [switch]$Initial) {
    $client = [System.Diagnostics.Process]::new()
    $client.StartInfo.FileName = $mysql
    $client.StartInfo.Arguments = if ($Initial) {
        "--no-defaults --host=127.0.0.1 --port=$mysqlPort --user=root --skip-password"
    } else { '--defaults-extra-file="{0}"' -f $clientConfig }
    $client.StartInfo.Arguments += ' --batch --raw --skip-column-names'
    $client.StartInfo.UseShellExecute = $false
    $client.StartInfo.CreateNoWindow = $true
    $client.StartInfo.RedirectStandardInput = $true
    $client.StartInfo.RedirectStandardOutput = $true
    $client.StartInfo.RedirectStandardError = $true
    try {
        [void]$client.Start()
        $client.StandardInput.WriteLine($Sql)
        $client.StandardInput.Close()
        $outputText = $client.StandardOutput.ReadToEnd()
        $errorText = $client.StandardError.ReadToEnd()
        $client.WaitForExit()
        if ($client.ExitCode -ne 0) { throw "La consulta MySQL fallo (codigo $($client.ExitCode)). $errorText" }
        return $outputText.Trim()
    } finally { $client.Dispose() }
}

if (!(Test-Path -LiteralPath $mysqld)) {
    $archive = Join-Path $runtime 'mysql-8.4.11-winx64.zip'
    if (!(Test-Path -LiteralPath $archive)) {
        Write-Host 'Descargando MySQL oficial (aproximadamente 268 MB, solo la primera vez)...'
        & curl.exe --fail --location --retry 2 --output $archive 'https://cdn.mysql.com/Downloads/MySQL-8.4/mysql-8.4.11-winx64.zip'
        if ($LASTEXITCODE -ne 0) { throw 'No se pudo descargar MySQL.' }
    }
    Write-Host 'Extrayendo MySQL...'
    Expand-Archive -LiteralPath $archive -DestinationPath $runtime -Force
}

if (!(Test-Path -LiteralPath (Join-Path $dataDirectory 'mysql'))) {
    Write-Host 'Inicializando los datos locales de MySQL...'
    & $mysqld --no-defaults --initialize-insecure "--basedir=$mysqlHome" "--datadir=$dataDirectory" --console
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo inicializar MySQL. Revisa el runtime de Visual C++ requerido por MySQL.' }
}

if (!(Test-LabPort $mysqlPort)) {
    $mysqlArgs = @('--no-defaults', ('--basedir="{0}"' -f $mysqlHome),
        ('--datadir="{0}"' -f $dataDirectory), "--port=$mysqlPort", '--bind-address=127.0.0.1',
        '--mysqlx=0', ('--log-error="{0}"' -f (Join-Path $runtime 'server.log')))
    $server = Start-Process -FilePath $mysqld -ArgumentList $mysqlArgs -WindowStyle Hidden -PassThru
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        if (Test-LabPort $mysqlPort) { break }
        if ($server.HasExited) { throw "MySQL no arranco. Revisa $runtime\server.log" }
        Start-Sleep -Seconds 1
    }
    if (!(Test-LabPort $mysqlPort)) { throw 'MySQL no respondio a tiempo.' }
}

if (!(Test-Path -LiteralPath $credentialsPath)) {
    $actualData = [string](Invoke-LabSql 'SELECT @@datadir;' -Initial)
    if ($actualData.TrimEnd('\', '/') -ne $dataDirectory.TrimEnd('\', '/')) {
        throw 'El puerto 3307 pertenece a otra instalacion de MySQL. No se modifico esa instalacion.'
    }
    # Claves locales aleatorias, ignoradas por Git; nunca se imprimen.
    $credentials = [pscustomobject]@{
        rootPassword = [Guid]::NewGuid().ToString('N')
        appPassword = [Guid]::NewGuid().ToString('N')
        username = 'security_lab'
        port = $mysqlPort
    }
    $credentials | ConvertTo-Json | Set-Content -LiteralPath $credentialsPath -Encoding UTF8
    @"
[client]
host=127.0.0.1
port=$mysqlPort
user=root
password=$($credentials.rootPassword)
"@ | Set-Content -LiteralPath $clientConfig -Encoding ASCII
    Invoke-LabSql "ALTER USER 'root'@'localhost' IDENTIFIED BY '$($credentials.rootPassword)';" -Initial | Out-Null
} else {
    $credentials = Get-Content -LiteralPath $credentialsPath -Raw | ConvertFrom-Json
}

Invoke-LabSql @"
CREATE DATABASE IF NOT EXISTS securitydb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS securitydb_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'security_lab'@'localhost' IDENTIFIED BY '$($credentials.appPassword)';
GRANT ALL PRIVILEGES ON securitydb.* TO 'security_lab'@'localhost';
GRANT ALL PRIVILEGES ON securitydb_test.* TO 'security_lab'@'localhost';
"@ | Out-Null
Write-Host "MySQL listo en 127.0.0.1:$mysqlPort. Bases: securitydb y securitydb_test."
if ($DatabaseOnly) { return }

if (Test-LabPort 8080) {
    if (Test-Path -LiteralPath $appStatePath) {
        $previous = Get-Content -LiteralPath $appStatePath -Raw | ConvertFrom-Json
        $process = Get-Process -Id $previous.processId -ErrorAction SilentlyContinue
        if ($process -and $process.StartTime.ToUniversalTime().ToString('o') -eq $previous.startTime) {
            Write-Host 'Access Lab con MySQL ya esta funcionando: http://localhost:8080/'
            return
        }
    }
    throw 'El puerto 8080 esta ocupado por otra instancia. Cierrala antes de iniciar el laboratorio con MySQL.'
}

if (!$env:JAVA_HOME) {
    $jdk = Get-ChildItem 'C:\Program Files\Java\jdk-*', 'C:\Program Files\Eclipse Adoptium\jdk-*' -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName 'bin\javac.exe') } | Select-Object -First 1
    if ($jdk) { $env:JAVA_HOME = $jdk.FullName }
}
$java = if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME 'bin\java.exe' } else { 'java.exe' }
$jar = Join-Path $labRoot 'target\semana07-security-1.0.0.jar'
if (!(Test-Path -LiteralPath $jar)) {
    Push-Location $labRoot
    try {
        & (Join-Path $labRoot 'mvnw.cmd') --batch-mode -DskipTests package
        if ($LASTEXITCODE -ne 0) { throw 'No se pudo compilar el proyecto.' }
    } finally { Pop-Location }
}
$env:DB_URL = "jdbc:mysql://127.0.0.1:$mysqlPort/securitydb"
$env:DB_USERNAME = $credentials.username
$env:DB_PASSWORD = $credentials.appPassword
$env:SPRING_PROFILES_ACTIVE = 'mysql'
$env:PORT = '8080'
$app = Start-Process -FilePath $java -ArgumentList @('-jar', ('"{0}"' -f $jar), '--debug=false') -WorkingDirectory $labRoot -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput (Join-Path $runtime 'app.log') -RedirectStandardError (Join-Path $runtime 'app-error.log')
[pscustomobject]@{ processId = $app.Id; startTime = $app.StartTime.ToUniversalTime().ToString('o') } |
    ConvertTo-Json | Set-Content -LiteralPath $appStatePath -Encoding UTF8
for ($attempt = 0; $attempt -lt 60; $attempt++) {
    if ($app.HasExited) { throw "La aplicacion no arranco. Revisa $runtime\app.log y app-error.log" }
    try {
        $response = Invoke-WebRequest -Uri 'http://localhost:8080/api/free' -UseBasicParsing -TimeoutSec 2
        if ($response.StatusCode -eq 200) {
            Write-Host 'Access Lab funcionando con MySQL: http://localhost:8080/'
            Write-Host 'Los datos persisten. Para detenerlo: scripts\stop-lab.cmd'
            return
        }
    } catch { }
    Start-Sleep -Seconds 1
}
throw 'La aplicacion no respondio a tiempo.'
