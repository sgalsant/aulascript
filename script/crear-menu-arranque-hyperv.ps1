# Importar funciones de utilidad para usar Write-AulaLog
. "$PSScriptRoot\utils.ps1"

Write-AulaLog -Message "La opción de crear un menú de arranque para Hyper-V se encuentra temporalmente DESHABILITADA." -Level WARNING
exit

Write-AulaLog -Message "Entradas actuales del menú de arranque:" -Level INFO

# Mostrar entradas actuales
$bcdEntries = bcdedit /enum | Out-String
$entries = $bcdEntries -split "\r?\n\r?\n" | Where-Object { $_ -match "identifier" }
$index = 1

foreach ($entry in $entries) {
    $description = ($entry -split "`n") | Where-Object { $_ -match "description" }
    $id = ($entry -split "`n") | Where-Object { $_ -match "identifier" }
    Write-Host "   $index. $description".Trim()
    Write-Host "      $id".Trim()
    $index++
}

# Descripciones de las nuevas entradas
$descHv   = "Windows con Hyper-V (Docker/WSL2)"
$descNoHv = "Windows sin Hyper-V (VMware/VirtualBox rápido)"

Write-Host "`n Este script añadirá dos entradas nuevas al menú de arranque:"
Write-Host "   '$descHv' → activa Hyper-V, necesario para Docker Desktop y WSL 2"
Write-Host "   '$descNoHv' → desactiva Hyper-V, mejora rendimiento en VMware y VirtualBox"
Write-Host "   La entrada con Hyper-V se establecerá como predeterminada (se arranca por defecto)"
Write-Host "`n¿Deseás continuar y realizar estos cambios? (s/n)"

$response = Read-Host
if ($response -ne "s" -and $response -ne "S") {
    Write-AulaLog -Message "Operación cancelada por el usuario. No se ha modificado el sistema de arranque." -Level WARNING
    exit
}

try {
    # Crear backup del BCD
    $computerName = $env:COMPUTERNAME
    $timestamp = Get-Date -Format yyyyMMdd_HHmmss
    $backupFileName = "bcd_backup_${computerName}_$timestamp.bcd"
    $backupPath = Join-Path $PSScriptRoot $backupFileName

    Write-AulaLog -Message "Guardando copia de seguridad en: $backupPath" -Level INFO
    bcdedit /export $backupPath | Out-Null
    Write-AulaLog -Message "Backup del BCD creado." -Level SUCCESS

    # Verificar si ya existen las entradas
    $hvExists = $bcdEntries -match [regex]::Escape($descHv)
    $nohExists = $bcdEntries -match [regex]::Escape($descNoHv)

    # Crear entrada con Hyper-V si no existe
    if (-not $hvExists) {
        Write-AulaLog -Message "Creando entrada: $descHv" -Level INFO
        $hvId = bcdedit /copy '{current}' /d "$descHv"
        $hvId = ($hvId | Select-String -Pattern "\{.+\}").Matches.Value
        if ($hvId) {
            bcdedit /set $hvId hypervisorlaunchtype auto | Out-Null
        } else {
            throw "No se pudo extraer el ID al crear la entrada $descHv"
        }
    } else {
        Write-AulaLog -Message "La entrada ya existe: $descHv" -Level SUCCESS
    }

    # Crear entrada sin Hyper-V si no existe
    if (-not $nohExists) {
        Write-AulaLog -Message "Creando entrada: $descNoHv" -Level INFO
        $nohId = bcdedit /copy '{current}' /d "$descNoHv"
        $nohId = ($nohId | Select-String -Pattern "\{.+\}").Matches.Value
        if ($nohId) {
            bcdedit /set $nohId hypervisorlaunchtype off | Out-Null
        } else {
            throw "No se pudo extraer el ID al crear la entrada $descNoHv"
        }
    } else {
        Write-AulaLog -Message "La entrada ya existe: $descNoHv" -Level SUCCESS
    }

    # Establecer timeout y entrada predeterminada
    bcdedit /timeout 10 | Out-Null
    if ($hvId) {
        bcdedit /default $hvId | Out-Null
        Write-AulaLog -Message "Entrada predeterminada establecida: $descHv" -Level SUCCESS
    }

    Write-AulaLog -Message "Configuración del menú de arranque finalizada. Reinicia el equipo para probar las opciones." -Level SUCCESS

} catch {
    $errorMessage = $_.Exception.Message
    Write-AulaLog -Message "Error CRÍTICO modificando el menú de arranque: $errorMessage" -Level ERROR
}

