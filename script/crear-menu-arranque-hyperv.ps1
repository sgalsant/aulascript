Write-Host "Entradas actuales del menú de arranque:`n"

# Mostrar entradas actuales
$bcdEntries = bcdedit /enum | Out-String
$entries = $bcdEntries -split "\r?\n\r?\n" | Where-Object { $_ -match "identifier" }
$index = 1

foreach ($entry in $entries) {
    $description = ($entry -split "`n") | Where-Object { $_ -match "description" }
    $id = ($entry -split "`n") | Where-Object { $_ -match "identifier" }
    Write-Host "$index. $description".Trim()
    Write-Host "   $id".Trim()
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
    Write-Host "`n Operación cancelada por el usuario. No se ha modificado el sistema."
    exit
}

# Crear backup del BCD
$computerName = $env:COMPUTERNAME
$timestamp = Get-Date -Format yyyyMMdd_HHmmss
$backupFileName = "bcd_backup_${computerName}_$timestamp.bcd"
$backupPath = Join-Path $PSScriptRoot $backupFileName

Write-Host "`n Guardando copia de seguridad en: $backupPath"
bcdedit /export $backupPath
Write-Host "Backup creado.`n"

# Verificar si ya existen las entradas
$hvExists = $bcdEntries -match [regex]::Escape($descHv)
$nohExists = $bcdEntries -match [regex]::Escape($descNoHv)

# Crear entrada con Hyper-V si no existe
if (-not $hvExists) {
    Write-Host "Creando entrada: $descHv"
    $hvId = bcdedit /copy '{current}' /d "$descHv"
    $hvId = ($hvId | Select-String -Pattern "\{.+\}").Matches.Value
    bcdedit /set $hvId hypervisorlaunchtype auto
} else {
    Write-Host "Entrada ya existe: $descHv"
}

# Crear entrada sin Hyper-V si no existe
if (-not $nohExists) {
    Write-Host "Creando entrada: $descNoHv"
    $nohId = bcdedit /copy '{current}' /d "$descNoHv"
    $nohId = ($nohId | Select-String -Pattern "\{.+\}").Matches.Value
    bcdedit /set $nohId hypervisorlaunchtype off
} else {
    Write-Host "Entrada ya existe: $descNoHv"
}

# Establecer timeout y entrada predeterminada
bcdedit /timeout 10
if ($hvId) {
    bcdedit /default $hvId
    Write-Host "Entrada predeterminada: $descHv"
}

Write-Host "Configuracion finalizada. Reinicia el equipo para probar las opciones disponibles"

