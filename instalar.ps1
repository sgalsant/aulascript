# Script parameters
param (
    [string]$installersPath = "$PSScriptRoot\repo",
    [string]$configFile = "$PSScriptRoot\config.json",
    [string]$logPath = "$PSScriptRoot\installation.log"
)

# Load configuration
$config = Get-Content $configFile | ConvertFrom-Json
$total = $config.Count
$index = 0

function Write-Log {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message" | Out-File -FilePath $logPath -Append -Encoding utf8
}

foreach ($app in $config) {
    $index++

    # Skip this application if install = false
    $shouldInstall = $true
    if ($null -ne $app.install) {
        $shouldInstall = [bool]$app.install
    }

    # Get the application name and parameters
    $name = $app.name
    $parameters = $app.parameters

    Write-Host "Name: $name"
    Write-Host "Parameters: $parameters"

    # Display installation progress
    Write-Progress -Activity "Installing applications" `
                   -Status "$index of $total - $name" `
                   -PercentComplete (($index / $total) * 100)

    if (-not $shouldInstall) {
        $msg = "INFO: Installation skipped for '$name' (install = false)"
        Write-Host $msg -ForegroundColor Yellow
        Write-Log $msg
        continue
    }

    # Find the installer file
    $installer = Get-ChildItem -Path $installersPath -File |
                  Where-Object { $_.BaseName -like "$name*" } |
                  Select-Object -First 1

    if ($installer) {
        $fileName = $installer.Name
        $filePath = $installer.FullName
        $isMSI = $installer.Extension -eq ".msi"

        # If it's an MSI and no parameters are specified, use default
        if ($isMSI -and ([string]::IsNullOrWhiteSpace($parameters))) {
            $parameters = "/qn /norestart ALLUSERS=1"
            Write-Log "INFO: Default parameters assigned for $fileName - $parameters"
        }

        # Create argument list
        if ($parameters -like "*,*") {
            $argList = $parameters.Split(",")
        } else {
            $argList = $parameters
        }

        # Log and display the installation command
        Write-Log "Executing $fileName with parameters: $parameters"
        Write-Host "Executing $fileName with parameters: $parameters"

        try {
            if ($isMSI) {
                if ($argList -is [string]) {
                    $argList = @("/i", "`"$filePath`"", $argList)
                } else {
                    $argList = @("/i", "`"$filePath`"") + $argList
                }
                Start-Process "msiexec.exe" -ArgumentList $argList -Wait -NoNewWindow
            } else {
                Start-Process -FilePath $filePath -ArgumentList $argList -Wait -NoNewWindow
            }

            Write-Log "SUCCESS: Installation completed: $fileName"

            if ($app.postscript) {
              $postScriptPath = Join-Path $PSScriptRoot $app.postscript
              if (Test-Path $postScriptPath) {
                Write-Log "Executing postscript for $name - $postScriptPath"
                & $postScriptPath
              } else {
                Write-Host "No encontrado script para $name - $postScriptPath"
              }
            }

        } catch {
            Write-Log "ERROR: Error installing $fileName - $_"
        }
    } else {
        $msg = "WARNING: Installer not found for '$name'"
        Write-Warning $msg
        Write-Log $msg
    }
}

# Final message with remote/local check
 if ($Host.Name -notlike "*ServerRemoteHost*") {
    Write-Host "All installations completed. Press any key to close..." -ForegroundColor Cyan
    [void][System.Console]::ReadKey($true)
 } else {
    Write-Host "All installations completed (remote session, no pause)." -ForegroundColor Cyan
 }
