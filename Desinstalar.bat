@echo off
rem Quita Kerma Remote de este PC. Pide administrador.
cd /d "%~dp0"
net session >nul 2>&1
if not errorlevel 1 goto admin
echo Pidiendo permisos de administrador...
powershell -NoProfile -Command "Start-Process -Verb RunAs -FilePath '%~f0'"
exit /b
:admin
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-KermaRemote.ps1" -Uninstall
echo.
pause
