#requires -RunAsAdministrator
[CmdletBinding()]
param()
. "$PSScriptRoot\script\utils.ps1"
Set-StrictMode -Version 2

# Configurar el encoding a UTF8 para caracteres especiales
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# --- LOG DE SESIÓN CENTRALIZADO ---
# Crear un único archivo de log para toda la sesión del menú.
# Se publica como variable de entorno de proceso para que todos los scripts hijos lo hereden.
$_sessionLog = Join-Path $PSScriptRoot "$($env:COMPUTERNAME)_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$env:AULA_LOG_FILE = $_sessionLog
Write-AulaLog -Message "=== INICIO DE SESION AulaScript ===" -Level INFO

# --- TABLA DE ACCIONES DEL MENU ---
# Rutas base a sub-scripts (capturadas por closure en los Action scriptblocks).
$scriptRoot = $PSScriptRoot
$scriptDir  = Join-Path $scriptRoot 'script'
$postDir    = Join-Path $scriptRoot 'postscript'

# Tabla de acciones: clave = opcion del menu; valor = @{ Label, Action, PostPause }.
# PostPause = $false solo para '0' (Salir). El resto lleva PostPause = $true
# (explícito, porque Set-StrictMode v2 NO permite leer una propiedad ausente
# de un hashtable — $record.PostPause lanzaria PropertyNotFoundException).
$menuActions = [ordered]@{
    '1' = @{ Label = 'Configurar Sistema (Zona Horaria, PSRemoting)';
            Action = { & (Join-Path $scriptDir 'configurar-psremoting.ps1') };
            PostPause = $true }
    '2' = @{ Label = 'Configurar direccion de red estatica';
            Action = { & (Join-Path $scriptDir 'cambiar-ip.ps1') };
            PostPause = $true }
    '3' = @{ Label = 'Crear cuentas de usuario';
            Action = { & (Join-Path $scriptDir 'cuentas-usuario.ps1') };
            PostPause = $true }
    '4' = @{ Label = 'Instalar aplicaciones';
            Action = { & (Join-Path $scriptDir 'instalar-aplicaciones.ps1') };
            PostPause = $true }
    '5' = @{ Label = 'Ejecutar todas las tareas (1-4)';
            Action = {
                foreach ($k in '1','2','3','4') {
                    Write-AulaLog -Message "Sub-tarea $k" -Level INFO
                    & $menuActions[$k].Action
                }
            };
            PostPause = $true }
    '6' = @{ Label = 'Crear menu de arranque con opciones de hyperv (beta)';
            Action = { & (Join-Path $scriptDir 'crear-menu-arranque-hyperv.ps1') };
            PostPause = $true }
    '7' = @{ Label = 'Instalar extension de virtualbox';
            Action = { & (Join-Path $postDir 'virtualbox-ext.ps1') };
            PostPause = $true }
    '8' = @{ Label = 'Configurar opciones de Hyper-V';
            Action = { & (Join-Path $scriptDir 'HyperV_Setup.ps1') };
            PostPause = $true }
    '0' = @{ Label = 'Salir'; Action = { }; PostPause = $false }
}

function Show-Menu {
    Clear-Host
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host " MENU DE CONFIGURACION E INSTALACION DE EQUIPOS DE AULA" -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host " (Ejecutando como Administrador, compatible con PSRemoting)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host " 1 - Configurar Sistema (Zona Horaria, PSRemoting)"
    Write-Host " 2 - Configurar direccion de red estatica"
    Write-Host " 3 - Crear cuentas de usuario"
    Write-Host " 4 - Instalar aplicaciones"
    Write-Host " 5 - Ejecutar todas las tareas (1-4)"
    Write-Host " 0 - Salir"
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host " 6 - Crear menu de arranque con opciones de hyperv (beta)"
    Write-Host " 7 - Instalar extension de virtualbox"
    Write-Host " 8 - Configurar opciones de Hyper-V"
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
}

function Invoke-AulaScript {
    param ([string]$ScriptPath)
    $fullPath = Join-Path $PSScriptRoot $ScriptPath
    if (Test-Path $fullPath) {
        & $fullPath
    }
    else {
        Write-Warning "No se encontro el script: $fullPath"
    }

    Write-Host "`n=============================================" -ForegroundColor Green
    Write-Host "Tarea del menu completada. Presione ENTER para volver..." -ForegroundColor Green
    Wait-Event -Timeout 1 | Out-Null
    Read-Host
}

# --- BUCLE PRINCIPAL ---
while ($true) {
    Show-Menu
    $opcion = Read-Host "Seleccione una opcion y presione ENTER"

    switch ($opcion) {
        "1" {
            Clear-Host
            Write-Host "=============================================`n 1. CONFIGURANDO SISTEMA...`n=============================================" -ForegroundColor Yellow
            Invoke-AulaScript -ScriptPath "script\configurar-psremoting.ps1"
        }
        "2" {
            Clear-Host
            Write-Host "=============================================`n 2. CONFIGURANDO RED ESTATICA...`n=============================================" -ForegroundColor Yellow
            Invoke-AulaScript -ScriptPath "script\cambiar-ip.ps1"
        }
        "3" {
            Clear-Host
            Write-Host "=============================================`n 3. CREANDO CUENTAS DE USUARIO...`n=============================================" -ForegroundColor Yellow
            Invoke-AulaScript -ScriptPath "script\cuentas-usuario.ps1"
        }
        "4" {
            Clear-Host
            Write-Host "=============================================`n 4. INSTALANDO APLICACIONES...`n=============================================" -ForegroundColor Yellow
            Invoke-AulaScript -ScriptPath "script\instalar-aplicaciones.ps1"
        }
        "5" {
            Clear-Host
            Write-Host "=============================================`n EJECUTANDO TODAS LAS TAREAS (1-4)...`n=============================================" -ForegroundColor Yellow

            Write-Host "`n--- 1. Configurando Sistema ---" -ForegroundColor Cyan
            & (Join-Path $PSScriptRoot "script\configurar-psremoting.ps1")

            Write-Host "`n--- 2. Configurando Red Estatica ---" -ForegroundColor Cyan
            & (Join-Path $PSScriptRoot "script\cambiar-ip.ps1")

            Write-Host "`n--- 3. Creando Cuentas de Usuario ---" -ForegroundColor Cyan
            & (Join-Path $PSScriptRoot "script\cuentas-usuario.ps1")

            Write-Host "`n--- 4. Instalando Aplicaciones ---" -ForegroundColor Cyan
            & (Join-Path $PSScriptRoot "script\instalar-aplicaciones.ps1")

            Write-Host "`n=============================================" -ForegroundColor Green
            Write-Host "Proceso multitarea completado. Presione ENTER para volver al menu..." -ForegroundColor Green
            Read-Host
        }
        "6" {
            Clear-Host
            Write-Host "=============================================`n 6. CREANDO MENU DE ARRANQUE...`n=============================================" -ForegroundColor Yellow
            Invoke-AulaScript -ScriptPath "script\crear-menu-arranque-hyperv.ps1"
        }
        "7" {
            Clear-Host
            Write-Host "=============================================`n 7. Instalar extension de virtualbox...`n=============================================" -ForegroundColor Yellow
            Invoke-AulaScript -ScriptPath "postscript\virtualbox-ext.ps1"
        }
        "8" {
            Clear-Host
            Write-Host "=============================================`n 8. CONFIGURANDO OPCIONES DE HYPER-V...`n=============================================" -ForegroundColor Yellow
            Invoke-AulaScript -ScriptPath "script\HyperV_Setup.ps1"
        }
        "0" {
            Write-AulaLog -Message "=== FIN DE SESION AulaScript ===" -Level INFO
            Write-Host "`nSaliendo del menu..."
            exit
        }
        default {
            Write-Warning "`nOpcion no valida. Presione ENTER para continuar..."
            Read-Host
        }
    }
}
