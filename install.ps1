# Kerma Remote - instalacion en una linea (PowerShell):
#
#   irm https://raw.githubusercontent.com/Vilchaco/kerma-remote/main/install.ps1 | iex
#
# Descarga la ultima version de main, pide administrador si hace falta y pregunta:
#   - si es una PRUEBA (Bloc de notas) o una MESA (Dealer App)
#   - que IPs pueden mandar comandos
# Despues ejecuta Install-KermaRemote.ps1. Si ya estaba instalado, mantiene la clave.

$ErrorActionPreference = 'Stop'
$KrRepo = 'Vilchaco/kerma-remote'
$KrRaw  = "https://raw.githubusercontent.com/$KrRepo/main"

$KrAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $KrAdmin) {
    Write-Host 'Pidiendo permisos de administrador...' -ForegroundColor Cyan
    $cmd = "irm $KrRaw/install.ps1 | iex"
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -Command `"$cmd`""
    return
}

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# carpeta temporal con ruta corta y sin espacios (los %TEMP% con nombre 8.3 dan problemas)
$KrTmp = Join-Path $env:ProgramData 'Kerma\remote-install'
New-Item -ItemType Directory -Path $KrTmp -Force | Out-Null
Write-Host "Descargando Kerma Remote de github.com/$KrRepo ..." -ForegroundColor Cyan
foreach ($f in @('KermaRemote.ps1', 'Install-KermaRemote.ps1')) {
    Invoke-WebRequest -UseBasicParsing -Uri "$KrRaw/$f" -OutFile (Join-Path $KrTmp $f)
}

# valores por defecto: los de la instalacion anterior, si la hay
$KrCfgFile = 'C:\ProgramData\Kerma\remote\config.json'
$KrDefAllow = '192.168.1.79'
$KrDefKind = '2'
if (Test-Path -LiteralPath $KrCfgFile) {
    try {
        $old = Get-Content -LiteralPath $KrCfgFile -Raw | ConvertFrom-Json
        if ($old.allow) { $KrDefAllow = (@($old.allow) -join ',') }
        if ($old.targetProcess -eq 'notepad') { $KrDefKind = '1' }
        Write-Host "Ya estaba instalado: se mantiene la clave." -ForegroundColor Yellow
    } catch { }
}

Write-Host ''
Write-Host '  1 = PRUEBA: pega en el Bloc de notas'
Write-Host '  2 = MESA:   pega en la Dealer App'
$kind = Read-Host "Que instalacion es? [$KrDefKind]"
if (-not $kind) { $kind = $KrDefKind }
$target = if ($kind -eq '1') { 'notepad' } else { 'dealer-control' }

$allow = Read-Host "IPs que pueden mandar comandos, separadas por comas [$KrDefAllow]"
if (-not $allow) { $allow = $KrDefAllow }

Write-Host ''
& (Join-Path $KrTmp 'Install-KermaRemote.ps1') -Allow $allow -TargetProcess $target -Force
Remove-Item -LiteralPath $KrTmp -Recurse -Force -ErrorAction SilentlyContinue
