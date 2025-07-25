#requires -RunAsAdministrator

<#
.SYNOPSIS
    Configura ajustes básicos del sistema como la zona horaria y PowerShell Remoting.
.DESCRIPTION
    Este script establece la zona horaria a 'GMT Standard Time' y habilita
    PowerShell Remoting para permitir la administración remota.
    Es una tarea de configuración inicial común.
#>

# Importar funciones de utilidad
. "$PSScriptRoot\utils.ps1"

try {
    Write-Host "Configurando la zona horaria a 'GMT Standard Time'..." -ForegroundColor Cyan
    Set-TimeZone -Id 'GMT Standard Time'
    Write-Host "Habilitando PowerShell Remoting..." -ForegroundColor Cyan
    Enable-PSRemoting -SkipNetworkProfileCheck -Force
    Write-Host "`nConfiguración del sistema completada." -ForegroundColor Green
}
catch {
    Write-Error "Ocurrió un error durante la configuración del sistema: $_"
}

