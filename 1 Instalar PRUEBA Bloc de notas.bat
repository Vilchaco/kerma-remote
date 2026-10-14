@echo off
rem Instala Kerma Remote apuntando al Bloc de notas (solo para pruebas). Pide administrador.
cd /d "%~dp0"
net session >nul 2>&1
if not errorlevel 1 goto admin
echo Pidiendo permisos de administrador...
powershell -NoProfile -Command "Start-Process -Verb RunAs -FilePath '%~f0'"
exit /b
:admin
echo Instalando Kerma Remote en modo PRUEBA (Bloc de notas), aceptando solo al PC de MCR 192.168.1.79
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-KermaRemote.ps1" -Allow 192.168.1.79 -TargetProcess notepad -Force
echo.
pause
