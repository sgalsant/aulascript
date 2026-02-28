@echo off
:: Cambiar al directorio del script
cd /d "%~dp0"

:: Lanzar el menu de instalacion en PowerShell asegurando permisos
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"instalar.ps1\"'"
exit
