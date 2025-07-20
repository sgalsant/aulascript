@echo off

:: Cambiar zona horaria
powershell -NoProfile -ExecutionPolicy Bypass -Command "Set-TimeZone -Id 'GMT Standard Time'"

:: Permitir la ejecución remota de comandos 
powershell -NoProfile -ExecutionPolicy Bypass -Command "Enable-PSRemoting -SkipNetworkProfileCheck -Force"

setlocal enabledelayedexpansion

:: Configuración base
set INTERFAZ=Ethernet
set BASEIP=192.168.150.
set BASEOCTET=50
set MASCARA=255.255.255.0
set GATEWAY=192.168.150.1
set DNS1=8.8.8.8
set DNS2=1.1.1.1

:: Obtener nombre del equipo
for /f %%A in ('hostname') do set EQUIPO=%%A

:: Extraer los últimos 2 dígitos numéricos del nombre del equipo
set DIGITOS=
for /l %%i in (0,1,31) do (
    set CHAR=!EQUIPO:~%%i,1!
    for %%d in (0 1 2 3 4 5 6 7 8 9) do (
        if "!CHAR!"=="%%d" set DIGITOS=!DIGITOS!!CHAR!
    )
)
set LAST2=!DIGITOS:~-2!

:: Si no hay dígitos, usar 0
if "!LAST2!"=="" set LAST2=0

set /a CLEANLAST2=1%LAST2%-100

:: Sumar base + últimos dígitos del equipo
set /a FINALOCTET=%BASEOCTET% + !CLEANLAST2!

:: Control de rango (opcional): si pasa de 254, poner 254
if !FINALOCTET! GTR 254 set FINALOCTET=254

:: Generar IP final
set IP=%BASEIP%!FINALOCTET!

echo Nombre del equipo: %EQUIPO%
echo Últimos dígitos detectados: %LAST2%
echo IP resultante: %IP%

:: Configurar IP
netsh interface ip set address name="%INTERFAZ%" static %IP% %MASCARA% %GATEWAY%

:: Configurar DNS
netsh interface ip set dns name="%INTERFAZ%" static %DNS1% primary
netsh interface ip add dns name="%INTERFAZ%" %DNS2% index=2

echo Configuración de red completada correctamente.
pause
