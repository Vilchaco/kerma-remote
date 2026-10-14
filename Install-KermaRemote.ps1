#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Instala (o quita) Kerma Remote en un PC de mesa.

.DESCRIPTION
    1. Copia KermaRemote.ps1 a C:\ProgramData\Kerma\remote y da permiso de escritura a los usuarios.
    2. Escribe config.json (si no existe o con -Force) y la clave remote.key.
    3. Reserva el puerto para los usuarios (netsh http urlacl), asi no hace falta ser administrador.
    4. Crea la regla de firewall "Kerma Remote" que solo deja entrar a las IPs permitidas.
    5. Crea la tarea "Kerma - Remote" que lo arranca, oculto, al iniciar sesion, y la lanza ya.

.EXAMPLE
    # prueba en Blackjack 01 contra el Bloc de notas, aceptando solo al PC de MCR
    .\Install-KermaRemote.ps1 -Allow 192.168.1.79 -TargetProcess notepad

.EXAMPLE
    # mesa real
    .\Install-KermaRemote.ps1 -Allow 192.168.1.79,192.168.0.181

.EXAMPLE
    .\Install-KermaRemote.ps1 -Uninstall
#>
[CmdletBinding()]
param(
    [string[]]$Allow = @('192.168.1.79'),
    [string]$TargetProcess = 'dealer-control',
    [int]$Port = 10010,
    [ValidateSet('paste', 'type')][string]$Mode = 'paste',
    [string]$Key,
    [switch]$Force,
    [switch]$NewKey,
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

# Con "powershell -File" las listas llegan como un solo texto ("ip1,ip2"): se separan aqui
$Allow = @($Allow | ForEach-Object { $_ -split '[,; ]+' } | Where-Object { $_ })
foreach ($a in $Allow) {
    $parsed = $null
    if (-not [System.Net.IPAddress]::TryParse($a, [ref]$parsed)) { throw "IP no valida en -Allow: '$a'" }
}
$Dir      = 'C:\ProgramData\Kerma\remote'
$TaskName = 'Kerma - Remote'
$RuleName = 'Kerma Remote'
$UsersSid = 'S-1-5-32-545'   # grupo Usuarios, sin depender del idioma de Windows

function Step([string]$m) { Write-Host "-> $m" -ForegroundColor Cyan }

if ($Uninstall) {
    Step 'Parando y quitando la tarea'
    Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like '*KermaRemote.ps1*' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Step 'Quitando la regla de firewall y la reserva del puerto'
    Remove-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue
    $cfgFile = Join-Path $Dir 'config.json'
    $p = $Port
    if (Test-Path -LiteralPath $cfgFile) { try { $p = (Get-Content -LiteralPath $cfgFile -Raw | ConvertFrom-Json).port } catch { } }
    & netsh http delete urlacl url="http://+:$p/" | Out-Null
    Step "Borrando $Dir"
    Remove-Item -LiteralPath $Dir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host 'Kerma Remote desinstalado.' -ForegroundColor Green
    return
}

# 1. carpeta y script
Step "Copiando el programa a $Dir"
$src = Join-Path $PSScriptRoot 'KermaRemote.ps1'
if (-not (Test-Path -LiteralPath $src)) { throw "No encuentro KermaRemote.ps1 junto al instalador ($src)." }
New-Item -ItemType Directory -Path $Dir -Force | Out-Null
Copy-Item -LiteralPath $src -Destination (Join-Path $Dir 'KermaRemote.ps1') -Force
& icacls $Dir /grant "*${UsersSid}:(OI)(CI)M" /T /Q | Out-Null

# 2. config y clave
$cfgFile = Join-Path $Dir 'config.json'
if ($Force -or -not (Test-Path -LiteralPath $cfgFile)) {
    Step 'Escribiendo config.json'
    $cfg = [ordered]@{
        port          = $Port
        allow         = @($Allow)
        targetProcess = $TargetProcess
        mode          = $Mode
        restoreFocus  = $true
        commands      = [ordered]@{ atem_auto = '{ATEM_AUTO}' }
    }
    $cfg | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $cfgFile -Encoding ASCII
} else {
    Step 'config.json ya existe: se deja como esta (usa -Force para rehacerlo)'
    $Port = (Get-Content -LiteralPath $cfgFile -Raw | ConvertFrom-Json).port
    $Allow = @((Get-Content -LiteralPath $cfgFile -Raw | ConvertFrom-Json).allow)
}

$keyFile = Join-Path $Dir 'remote.key'
$keyGenerated = $false
if (-not $Key -and (Test-Path -LiteralPath $keyFile) -and -not $NewKey) {
    Step 'remote.key ya existe: se mantiene la clave (usa -NewKey para cambiarla)'
    $Key = (Get-Content -LiteralPath $keyFile -Raw).Trim()
} else {
    if (-not $Key) {
        $Key = Read-Host 'Clave compartida con Companion (minimo 12 caracteres, vacio = generar una)'
        if (-not $Key) {
            $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'.ToCharArray()
            $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
            $bytes = New-Object byte[] 24; $rng.GetBytes($bytes)
            $Key = -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
            $keyGenerated = $true
        }
    }
    if ($Key.Length -lt 12) { throw 'La clave tiene que tener al menos 12 caracteres.' }
    Set-Content -LiteralPath $keyFile -Value $Key -Encoding ASCII -NoNewline
    Step 'Clave guardada en remote.key'
}

# 3. reserva del puerto para los usuarios
Step "Reservando el puerto $Port para los usuarios (urlacl)"
& netsh http delete urlacl url="http://+:$Port/" 2>$null | Out-Null
& netsh http add urlacl url="http://+:$Port/" sddl="D:(A;;GX;;;BU)" | Out-Null

# 4. firewall
Step "Regla de firewall: puerto $Port solo desde $($Allow -join ', ')"
Remove-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName $RuleName -Direction Inbound -Protocol TCP -LocalPort $Port `
    -RemoteAddress $Allow -Action Allow -Profile Any | Out-Null

# 5. tarea al iniciar sesion (en la sesion del usuario, oculta, se reinicia si cae)
Step "Creando la tarea '$TaskName'"
$taskArgs = "-STA -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Dir\KermaRemote.ps1`""
$action    = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $taskArgs -WorkingDirectory $Dir
$trigger   = New-ScheduledTaskTrigger -AtLogOn
$trigger.Delay = 'PT20S'
$principal = New-ScheduledTaskPrincipal -GroupId $UsersSid -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew `
                -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 5 -RestartInterval (New-TimeSpan -Minutes 1)
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings | Out-Null

Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like '*KermaRemote.ps1*' -and $_.ProcessId -ne $PID } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-ScheduledTask -TaskName $TaskName
Start-Sleep -Seconds 3

$listening = [bool](Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
Write-Host ''
if ($listening) { Write-Host "Kerma Remote instalado y escuchando en el puerto $Port." -ForegroundColor Green }
else { Write-Host "Instalado, pero el puerto $Port aun no escucha. Mira $Dir\remote.log." -ForegroundColor Yellow }
if ($keyGenerated) { Write-Host "Clave generada. Copiala en Companion, en la cabecera X-Kerma-Key:" -ForegroundColor Yellow }
else { Write-Host 'Clave de este PC (cabecera X-Kerma-Key en Companion):' -ForegroundColor Yellow }
Write-Host "  $Key" -ForegroundColor Yellow
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -ne 'WellKnown' -and $_.IPAddress -notlike '169.254.*' } | Select-Object -First 1).IPAddress
Write-Host "Prueba desde un PC permitido:"
Write-Host "  Invoke-RestMethod http://${ip}:$Port/health -Headers @{ 'X-Kerma-Key' = '<clave>' }"
Write-Host "  Invoke-RestMethod http://${ip}:$Port/cmd/atem_auto -Method Post -Headers @{ 'X-Kerma-Key' = '<clave>'; 'X-Kerma-Station' = 'MCR' }"
