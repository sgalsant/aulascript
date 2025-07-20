@echo off

PowerShell -ExecutionPolicy Bypass -Command "Start-Process PowerShell -ArgumentList '-ExecutionPolicy Bypass -File \"%~dp0cuentas-usuario.ps1\"' -Verb RunAs"

PowerShell -ExecutionPolicy Bypass -Command "Start-Process PowerShell -ArgumentList '-ExecutionPolicy Bypass -File \"%~dp0instalar.ps1\"' -Verb RunAs"

pause
