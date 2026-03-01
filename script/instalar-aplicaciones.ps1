# Script parameters
param (
    [string]$installersPath = "$PSScriptRoot\..\repo",
    [string]$configFile = "$PSScriptRoot\..\aplicaciones.json",
    [string]$logPath = "$PSScriptRoot\..\installation.log"
)


# --- Define project root for resolving relative paths ---
$projectRoot = (Split-Path -Path $PSScriptRoot -Parent)

# Importar funciones de utilidad para usar Write-AulaLog
. "$PSScriptRoot\utils.ps1"

# Flag to track if a reboot is needed
$rebootRequired = $false

# Load configuration
$config = Get-Content $configFile | ConvertFrom-Json
$total = $config.Count
$index = 0

foreach ($app in $config) {
    $index++
    $name = $app.name

    # Determine if the application should be installed. Defaults to 'true' if the 'install' property is missing.
    $shouldInstall = if ($app.PSObject.Properties.Name -contains 'install') {
        [bool]$app.install
    } else {
        $true
    }

    # Display installation progress
    Write-Progress -Activity "Installing applications" `
                   -Status "$index of $total - $name" `
                   -PercentComplete (($index / $total) * 100)

    if (-not $shouldInstall) {
        Write-AulaLog -Message "Instalación omitida para '$name' (install = false)" -Level INFO
        continue
    }

    # Find the installer file
    $installer = Get-ChildItem -Path $installersPath -File |
                  Where-Object { $_.BaseName -like "$name*" } |
                  Select-Object -First 1

    # An app is valid if it has an installer OR a script to run.
    $hasInstaller = $null -ne $installer
    $hasPostScript = $app.PSObject.Properties.Name -contains 'postscript' -and -not [string]::IsNullOrWhiteSpace($app.postscript)
    $hasPostRebootScript = $app.PSObject.Properties.Name -contains 'postRebootScript' -and -not [string]::IsNullOrWhiteSpace($app.postRebootScript)

    if ($hasInstaller -or $hasPostScript -or $hasPostRebootScript) {
        try {
            if ($hasInstaller) {
                $fileName = $installer.Name
                $filePath = $installer.FullName
                $isMSI = $installer.Extension -eq ".msi"

                # If it's an MSI and no parameters are specified, use default
                $argList = $app.parameters
                if ($isMSI -and ($null -eq $argList -or $argList.Count -eq 0)) {
                    $argList = @("/qn", "/norestart", "ALLUSERS=1")
                    Write-AulaLog -Message "Parámetros MSI por defecto asignados para $fileName" -Level INFO
                }

                # Log and display the installation command
                Write-AulaLog -Message "Ejecutando $fileName con parámetros: $($argList -join ' ')" -Level INFO

                if ($isMSI) {
                    $argList = @("/i", "`"$filePath`"") + $argList
                    Start-Process "msiexec.exe" -ArgumentList $argList -Wait -NoNewWindow -ErrorAction Stop
                } else {
                    if ([string]::IsNullOrWhiteSpace($argList)) {
                       Start-Process -FilePath $filePath -Wait -NoNewWindow -ErrorAction Stop
                    } else {
                       Start-Process -FilePath $filePath -ArgumentList $argList -Wait -NoNewWindow -ErrorAction Stop
                    }
                }
                Write-AulaLog -Message "Instalación completada exitosamente: $fileName" -Level SUCCESS
            }

            # Check for a post-reboot script to schedule
            if ($hasPostRebootScript) {
                $postRebootScriptPath = Join-Path $projectRoot $app.postRebootScript
                if (Test-Path $postRebootScriptPath) {
                    $runOnceKey = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
                    $command = "powershell.exe -ExecutionPolicy Bypass -File `"$postRebootScriptPath`""
                    $entryName = "PostInstall_$($name)"
                    
                    Write-AulaLog -Message "Se ha programado un script para ejecutarse después del reinicio para $name : $postRebootScriptPath" -Level SUCCESS
                    
                    Set-ItemProperty -Path $runOnceKey -Name $entryName -Value $command -Force -ErrorAction Stop

                    $rebootRequired = $true
                } else {
                    Write-AulaLog -Message "No se encontró el script post-reinicio para $name en $postRebootScriptPath" -Level WARNING
                }
            }

            # Check for an immediate post-install script (keeps existing functionality)
            if ($hasPostScript) {
                $postScriptPath = Join-Path $projectRoot $app.postscript
                if (Test-Path $postScriptPath) {
                    Write-AulaLog -Message "Ejecutando post-script para $name - $postScriptPath" -Level INFO
                    & $postScriptPath
                } else {
                    Write-AulaLog -Message "No se encontró el script post-instalación para $name en $postScriptPath" -Level WARNING
                }
            }
        } catch {
            $errorMessage = $_.Exception.Message
            Write-AulaLog -Message "Error CRÍTICO al procesar '$name': $errorMessage" -Level ERROR
        }
    } else {
        Write-AulaLog -Message "No se encontraron instaladores ni scripts para '$name'. Omitiendo." -Level WARNING
    }
}

# If a reboot is required, prompt the user
if ($rebootRequired) {
    Write-Host "`n----------------------------------------------------------------" -ForegroundColor Yellow
    Write-Host "REINICIO NECESARIO" -ForegroundColor Yellow
    Write-Host "Algunas aplicaciones requieren un reinicio para completar la instalación." -ForegroundColor Yellow
    Write-Host "Se ha configurado una tarea para finalizar la configuración automáticamente después del reinicio." -ForegroundColor Yellow
    Write-Host "----------------------------------------------------------------`n"

    if ($Host.Name -notlike "*ServerRemoteHost*") {
        $rebootChoice = Read-Host "¿Desea reiniciar el equipo ahora? [S/n]"
        if ($rebootChoice.ToLower() -notin @('s', '')) {
            Write-Warning "Reinicio pospuesto. Por favor, reinicie el equipo manualmente."
        } else {
            Write-Host "Reiniciando el equipo en 5 segundos..." -ForegroundColor Green
            Start-Sleep -Seconds 5
            Restart-Computer -Force
        }
    } else {
        Write-Warning "Reinicio necesario. El script se está ejecutando en una sesión remota, no se reiniciará automáticamente."
    }
} else {
    Write-Host "`nTodas las instalaciones han finalizado." -ForegroundColor Cyan
}
