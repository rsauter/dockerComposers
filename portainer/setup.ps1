#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ComposeFile  = "docker-compose.yml"
$VolumeName   = "zabbix-sandbox_zabbix-alertscripts"
$PagerScript  = "fake-pager.sh"
$LogPath      = "/usr/lib/zabbix/alertscripts/pager.log"

Write-Host ""
Write-Host "=== Zabbix Sandbox Setup ===" -ForegroundColor Cyan
Write-Host ""

# Check dependencies
if (-not (Get-Command "docker" -ErrorAction SilentlyContinue)) {
    Write-Error "ERROR: 'docker' is not installed or not in PATH."
    exit 1
}

try {
    docker compose version | Out-Null
} catch {
    Write-Error "ERROR: 'docker compose' (v2) is not available.`n       Make sure Docker Desktop is installed and running."
    exit 1
}

# Start containers
Write-Host "[1/4] Starting containers..."
docker compose -f $ComposeFile up -d

# Wait for Zabbix server to become healthy
Write-Host "[2/4] Waiting for Zabbix server to be ready (this takes ~60 seconds)..."
$retries = 30
$ready = $false
while ($retries -gt 0) {
    $logs = docker compose -f $ComposeFile logs zabbix-server 2>&1
    if ($logs -match "server #0 started") {
        $ready = $true
        break
    }
    $retries--
    Write-Host "." -NoNewline
    Start-Sleep -Seconds 5
}
Write-Host ""

if (-not $ready) {
    Write-Error "ERROR: Zabbix server did not start in time.`n       Run 'docker compose logs zabbix-server' to investigate."
    exit 1
}
Write-Host "       Zabbix server is up."

# Locate alertscripts volume mountpoint
Write-Host "[3/4] Locating alertscripts volume..."
$mountRaw = docker volume inspect $VolumeName --format '{{ .Mountpoint }}' 2>&1
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($mountRaw)) {
    Write-Error "ERROR: Volume '$VolumeName' not found.`n       Make sure the compose project name matches 'zabbix-sandbox'."
    exit 1
}
$mountPoint = $mountRaw.Trim()

# On Windows, Docker Desktop uses a Linux VM — volume data is accessible
# via the Docker socket. We write the script using 'docker run' instead
# of direct filesystem access.
Write-Host "[4/4] Creating $PagerScript..."

$scriptContent = @'
#!/bin/sh
echo "$(date) | TO: $1 | SUBJECT: $2 | MSG: $3" >> /usr/lib/zabbix/alertscripts/pager.log
'@

# Write via a temporary alpine container that shares the volume
$scriptContent | docker run --rm -i `
    -v "${VolumeName}:/alertscripts" `
    alpine sh -c "cat > /alertscripts/$PagerScript && chmod +x /alertscripts/$PagerScript"

if ($LASTEXITCODE -ne 0) {
    Write-Error "ERROR: Failed to write $PagerScript into the volume."
    exit 1
}
Write-Host "       Script written to volume: $VolumeName"

Write-Host ""
Write-Host "=== Setup complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "  Web UI:  http://localhost:8080"
Write-Host "  Login:   Admin / zabbix"
Write-Host ""
Write-Host "  To watch incoming pager alerts:"
Write-Host "  docker exec zabbix-server tail -f $LogPath"
Write-Host ""