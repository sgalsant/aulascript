<#
.SYNOPSIS
    Contiene funciones de utilidad reutilizables para los scripts del proyecto.
#>

function Write-AulaLog {
    <#
.SYNOPSIS
    Escribe un mensaje en la consola y lo guarda en un archivo de log centralizado.
.DESCRIPTION
    Esta función proporciona un mecanismo estructurado para emitir mensajes (INFO, WARNING, ERROR)
    con código de colores a la consola, y registrarlos concurrentemente en un archivo de log
    con marcas de tiempo.
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO',

        [string]$LogPath = $(if ($env:AULA_LOG_FILE) { $env:AULA_LOG_FILE } else { "C:\Logs\AulaScript.log" })
    )

    # Asegurar que el directorio del log existe
    $logDir = Split-Path -Path $LogPath -Parent
    if (-not (Test-Path -Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }

    # Formatear el mensaje
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logOutput = "$timestamp [$Level] $Message"

    # Escribir a consola con colores apropiados
    switch ($Level) {
        'INFO' { Write-Host $logOutput -ForegroundColor Cyan }
        'SUCCESS' { Write-Host $logOutput -ForegroundColor Green }
        'WARNING' { Write-Warning $Message } # Write-Warning automaticamente prefija con "WARNING:"
        'ERROR' { Write-Host $logOutput -ForegroundColor Red } # Write-Error es muy verboso, preferimos Host rojo
    }

    # Anexar al archivo de log usando compatibilidad amplia
    try {
        $logOutput | Out-File -FilePath $LogPath -Append -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        Write-Host "No se pudo escribir en el archivo de log: $($_.Exception.Message)" -ForegroundColor DarkRed
    }
}

function Wait-KeyWithTimeout {
    <#
.SYNOPSIS
    Pausa la ejecución del script hasta que el usuario presiona una tecla o se agota un tiempo de espera.
.DESCRIPTION
    Muestra un mensaje y un contador regresivo. Si el usuario presiona cualquier tecla, la función termina inmediatamente.
    Si el tiempo de espera se agota, la función termina y el script continúa.
    Esto evita que los scripts se queden pausados indefinidamente.
.PARAMETER Timeout
    El número de segundos a esperar antes de continuar automáticamente. El valor por defecto es 15.
.PARAMETER Message
    El mensaje a mostrar al usuario. Debe contener un marcador de posición '{0}' para el número de segundos.
.EXAMPLE
    Wait-KeyWithTimeout
    # Pausa durante 15 segundos con el mensaje por defecto.

.EXAMPLE
    Wait-KeyWithTimeout -Timeout 30 -Message "La instalación ha finalizado. Presione una tecla o espere {0} segundos para salir."
    # Pausa durante 30 segundos con un mensaje personalizado.
#>
    [CmdletBinding()]
    [OutputType([void])]
    param (
        [int]$Timeout = 15,
        [string]$Message = "Presione cualquier tecla para continuar o espere {0} segundos..."
    )

    Write-Host "`n$([string]::Format($Message, $Timeout))"

    # Bucle de cuenta atrás
    for ($i = $Timeout; $i -gt 0; $i--) {
        # Muestra el contador y lo sobrescribe en cada iteración
        $countdownMessage = "Continuando automaticamente en $i segundos... "
        Write-Host -NoNewline "`r$countdownMessage"

        # Comprueba si se ha presionado una tecla sin bloquear el script
        if ([System.Console]::KeyAvailable) {
            # Limpia la tecla del búfer de entrada
            [void][System.Console]::ReadKey($true)
            # Limpia la línea del contador antes de salir del bucle
            Write-Host -NoNewline ("`r" + (" " * $countdownMessage.Length) + "`r")
            break
        }
        Start-Sleep -Seconds 1
    }
    # Asegura una nueva línea al final, tanto si se agota el tiempo como si se presiona una tecla.
    Write-Host ""
}