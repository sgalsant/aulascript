#requires -RunAsAdministrator

# Configurar el encoding a UTF8 para caracteres especiales
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Show-Menu {
    Clear-Host
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host " MENÚ DE CONFIGURACIÓN E INSTALACIÓN DE EQUIPOS DE AULA" -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host " (Ejecutando como Administrador, compatible con PSRemoting)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host " 1 - Configurar Sistema (Zona Horaria, PSRemoting)"
    Write-Host " 2 - Configurar dirección de red estática"
    Write-Host " 3 - Crear cuentas de usuario"
    Write-Host " 4 - Instalar aplicaciones"
    Write-Host " 5 - Ejecutar todas las tareas (1-4)"
    Write-Host " 0 - Salir"
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host " 6 - Crear menú de arranque con opciones de hyperv (beta)"
    Write-Host " 7 - Instalar extensión de virtualbox"
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
        Write-Warning "No se encontró el script: $fullPath"
    }
    
    Write-Host "`n=============================================" -ForegroundColor Green
    Write-Host "Tarea del menú completada. Presione ENTER para volver..." -ForegroundColor Green
    Wait-Event -Timeout 1 | Out-Null
    Read-Host
}

# --- BUCLE PRINCIPAL ---
while ($true) {
    Show-Menu
    $opcion = Read-Host "Seleccione una opción y presione ENTER"

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
            Write-Host "Proceso multitaréa completado. Presione ENTER para volver al menú..." -ForegroundColor Green
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
            Write-Host "`nSaliendo del menú..."
            exit
        }
        default {
            Write-Warning "`nOpción no válida. Presione ENTER para continuar..."
            Read-Host
        }
    }
}
