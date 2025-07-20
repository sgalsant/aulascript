@echo off

echo Iniciando la creacion de cuentas de usuario...
:: Se usa -Wait para asegurar que este script termina antes de que comience el siguiente.
PowerShell -WindowStyle Hidden -ExecutionPolicy Bypass -Command "Start-Process PowerShell -ArgumentList '-ExecutionPolicy Bypass -File \"%~dp0cuentas-usuario.ps1\"' -Verb RunAs -Wait"

echo.
echo Iniciando la instalacion de aplicaciones...
PowerShell -WindowStyle Hidden -ExecutionPolicy Bypass -Command "Start-Process PowerShell -ArgumentList '-ExecutionPolicy Bypass -File \"%~dp0instalar-aplicaciones.ps1\"' -Verb RunAs -Wait"

echo.
echo Proceso completado.
pause
