@echo off
rem Pega el comando en la app configurada sin usar la red. No necesita administrador.
cd /d "%~dp0"
echo Abre antes el Bloc de notas (o la Dealer App). En 3 segundos se pegara {ATEM_AUTO}.
echo.
powershell -NoProfile -STA -ExecutionPolicy Bypass -File "C:\ProgramData\Kerma\remote\KermaRemote.ps1" -TestCommand atem_auto
echo.
pause
