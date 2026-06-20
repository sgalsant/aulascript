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
    foreach ($k in $menuActions.Keys) {
        Write-Host (" {0} - {1}" -f $k, $menuActions[$k].Label)
    }
    Write-Host ""
}

# --- BUCLE PRINCIPAL: dispatch unificado basado en $menuActions ---
# Cada opcion (1-8, 0) pasa por el mismo camino: log del pick, log de inicio,
# ejecutar Action bajo try/catch, log de resultado, pausa post-accion condicional.
# La unica salida es $opcion -eq '0' (Salir), que rompe el bucle por la
# condicion del do/while y termina con el marcador FIN DE SESION.
do {
    Show-Menu
    $opcion = Read-Host "Seleccione una opcion y presione ENTER"

    if ($menuActions.Contains($opcion)) {
        $record = $menuActions[$opcion]
        Write-AulaLog -Message "Menu: opcion '$opcion' - $($record.Label)" -Level INFO

        if ($opcion -ne '0') {
            Write-AulaLog -Message "Iniciando: $($record.Label)" -Level INFO
            try {
                # Mantener el modo estricto limitado al dispatcher. Los scripts hijos
                # son anteriores a este refactor y conservan su semántica no estricta.
                & {
                    Set-StrictMode -Off
                    & $record.Action
                }
                Write-AulaLog -Message "Finalizado: $($record.Label)" -Level SUCCESS
            }
            catch {
                Write-AulaLog -Message "Error en '$($record.Label)': $($_.Exception.Message)" -Level ERROR
            }
        }

        if ($record.PostPause -ne $false) {
            Wait-Enter -Message "Tarea completada. Presione ENTER para volver al menu..."
        }
    }
    else {
        Write-AulaLog -Message "Menu: opcion '$opcion' - no valida" -Level WARNING
        Wait-Enter -Message "Opcion no valida. Presione ENTER para continuar..."
    }
} while ($opcion -ne '0')

Write-AulaLog -Message "=== FIN DE SESION AulaScript ===" -Level INFO
Write-Host "`nSaliendo del menu..."
