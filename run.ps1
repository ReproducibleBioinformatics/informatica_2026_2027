# JupyterLab with R — Windows (PowerShell).
# Run with:  powershell -ExecutionPolicy Bypass -File run.ps1
# Then open: http://localhost:8888
$ErrorActionPreference = "Stop"

$Image = "ghcr.io/reproduciblebioinformatics/informatica_2026_2027:latest"
$Name  = "informatica-jupyter"
$Port  = 8888

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigFile = Join-Path $ScriptDir "configurationFile.txt"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { Write-Error "Docker is not installed or not in PATH." }
docker info *> $null
if ($LASTEXITCODE -ne 0) { Write-Error "Docker is not running. Start Docker Desktop and try again." }

# Architecture autodetect (asks the Docker engine)
$Arch = (docker info --format '{{.Architecture}}').Trim()
switch -Regex ($Arch) {
    '^(aarch64|arm64)$' { $Platform = "linux/arm64" }
    '^(x86_64|amd64)$'  { $Platform = "linux/amd64" }
    default { Write-Error "Unsupported architecture: $Arch" }
}

# Shared folder
if (Test-Path $ConfigFile) {
    $SharedDir = (Get-Content $ConfigFile -TotalCount 1).Trim()
    if (-not $SharedDir) { Write-Error "configurationFile.txt is empty: write the folder to share on the first line." }
    if (-not [System.IO.Path]::IsPathRooted($SharedDir)) { $SharedDir = Join-Path $ScriptDir $SharedDir }
} else {
    $SharedDir = $ScriptDir
    Set-Content -Path $ConfigFile -Value $SharedDir
}
New-Item -ItemType Directory -Force -Path $SharedDir | Out-Null
$SharedDir = (Resolve-Path $SharedDir).Path

# Clean up a previous run
if (docker ps -a --format '{{.Names}}' | Select-String -Pattern "^$Name$" -Quiet) {
    Write-Host "Removing previous container $Name..."
    docker rm -f $Name | Out-Null
}

Write-Host "Architecture: $Arch -> $Platform"
Write-Host "Downloading/updating image (the first time it may take a few minutes)..."
docker pull --platform $Platform $Image

Write-Host ""
Write-Host "Shared folder: $SharedDir"
Write-Host "Open http://localhost:$Port in your browser."
Write-Host "Press Ctrl+C here to stop."
docker run --rm -it --name $Name --platform $Platform `
    -p "127.0.0.1:${Port}:8888" -v "${SharedDir}:/sharedFolder" --shm-size=2g $Image
