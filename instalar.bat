@echo off
setlocal

:admin_check
:: Comprueba si el script tiene privilegios de administrador. Si no, se reinicia para pedirlos.
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo Solicitando privilegios de administrador...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:menu
cls
echo =============================================
echo  MENU DE CONFIGURACION E INSTALACION
echo =============================================
echo.
echo  (Ejecutando como Administrador)
echo.
echo  1 - Configurar Sistema (Zona Horaria, PSRemoting)
echo  2 - Configurar direccion de red estatica
echo  3 - Crear cuentas de usuario
echo  4 - Instalar aplicaciones
echo  5 - Ejecutar todas las tareas
echo  6 - Salir
echo.
echo =============================================

set /p "opcion=Seleccione una opcion y presione ENTER: "

if "%opcion%"=="1" goto configurar_sistema
if "%opcion%"=="2" goto configurar_ip
if "%opcion%"=="3" goto crear_usuarios
if "%opcion%"=="4" goto instalar_apps
if "%opcion%"=="5" goto todo
if "%opcion%"=="6" goto salir

echo.
echo Opcion no valida. Presione una tecla para continuar...
pause >nul
goto menu

:configurar_sistema
cls
echo =============================================
echo  1. CONFIGURANDO SISTEMA...
echo =============================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0\script\configurar-psremoting.ps1"
goto :post_task

:configurar_ip
cls
echo =============================================
echo  2. CONFIGURANDO RED ESTATICA...
echo =============================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0\script\cambiar-ip.ps1"
goto :post_task

:crear_usuarios
cls
echo =============================================
echo  3. CREANDO CUENTAS DE USUARIO...
echo =============================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0\script\cuentas-usuario.ps1"
goto :post_task

:instalar_apps
cls
echo =============================================
echo  4. INSTALANDO APLICACIONES...
echo =============================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0\script\instalar-aplicaciones.ps1"
goto :post_task

:todo
cls
echo =============================================
echo  EJECUTANDO TODAS LAS TAREAS...
echo =============================================
echo.
echo --- 1. Configurando Sistema ---
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0\script\configurar-psremoting.ps1"
echo.
echo --- 2. Configurando Red Estatica ---
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0\script\cambiar-ip.ps1"
echo.
echo --- 3. Creando Cuentas de Usuario ---
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0\script\cuentas-usuario.ps1"
echo.
echo --- 4. Instalando Aplicaciones ---
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0\script\instalar-aplicaciones.ps1"
echo.
echo =============================================
echo Proceso completado.
pause
goto menu

:post_task
echo.
echo =============================================
echo Tarea completada. Presione una tecla para volver al menu...
pause >nul
goto menu

:salir
endlocal
exit /b
