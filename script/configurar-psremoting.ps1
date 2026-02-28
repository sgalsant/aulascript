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
    Write-AulaLog -Message "Configurando la zona horaria a 'GMT Standard Time'..." -Level INFO
    Set-TimeZone -Id 'GMT Standard Time' -ErrorAction Stop
    
    Write-AulaLog -Message "Habilitando PowerShell Remoting..." -Level INFO
    Enable-PSRemoting -SkipNetworkProfileCheck -Force -ErrorAction Stop
    
    Write-AulaLog -Message "Configuración del sistema (Zona horaria y PSRemoting) completada." -Level SUCCESS
}
catch {
    $errorMessage = $_.Exception.Message
    Write-AulaLog -Message "Ocurrió un error durante la configuración del sistema: $errorMessage" -Level ERROR
}

