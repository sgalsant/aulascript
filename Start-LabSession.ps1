param(
    [switch]$NoRestore,
    [switch]$IncludeRepo
)

$VMName = "VM-Aula"
$SnapshotName = "Base"

# Asegurar la ruta local sea como script o desde consola
$LocalProjectPath = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
$RemoteProjectPath = "C:\aulascript"

Write-Host "=== Iniciando Laboratorio ==="
if ($NoRestore) {
    Write-Host "[INFO] Modo sin restauracion: se mantiene el estado actual de la VM." -ForegroundColor Yellow
}
else {
    Write-Host "[INFO] Restaurando snapshot '$SnapshotName'..." -ForegroundColor Gray
    Restore-VMSnapshot -VMName $VMName -Name $SnapshotName -Confirm:$false
}

$cred = Get-Credential -UserName "$VMName\Admin" -Message "Credenciales de la VM"

Start-VM -Name $VMName

$isReady = $false
$retryCount = 0
$maxRetries = 30

while (-not $isReady -and $retryCount -lt $maxRetries) {
    try {
        $null = Invoke-Command -VMName $VMName -Credential $cred -ScriptBlock { $true } -ErrorAction Stop
        $isReady = $true
    }
    catch {
        $retryCount++
        Start-Sleep -Seconds 2
    }
}

if (-not $isReady) {
    Write-Error "La VM no responde."
    exit
}

$session = New-PSSession -VMName $VMName -Credential $cred

Write-Host "Limpiando directorio destino previo en la VM..." -ForegroundColor Gray
try {
    Invoke-Command -Session $session -ArgumentList $RemoteProjectPath -ScriptBlock {
        param([string]$DestinationPath)

        if (Test-Path -LiteralPath $DestinationPath) {
            Remove-Item -LiteralPath $DestinationPath -Recurse -Force -ErrorAction Stop
        }

        New-Item -Path $DestinationPath -ItemType Directory -ErrorAction Stop | Out-Null
    } -ErrorAction Stop
}
catch {
    Remove-PSSession -Session $session
    throw "No se pudo limpiar '$RemoteProjectPath' en la VM. Cierre cualquier instalador o proceso que este usando archivos de esa carpeta y vuelva a ejecutar el laboratorio. Detalle: $($_.Exception.Message)"
}

Write-Host "Copiando archivos necesarios a la VM ($RemoteProjectPath)..." -ForegroundColor Cyan
# Obtenemos solo los archivos y carpetas estrictamente necesarios para los scripts
$elementosRequeridos = @("script", "postscript", "instalar.ps1", "instalar.bat", "aplicaciones.json")

if ($IncludeRepo) {
    Write-Host "[INFO] Incluyendo directorio repo en la copia a la VM (se reemplaza por completo)." -ForegroundColor Yellow
    $elementosRequeridos += "repo"
}

foreach ($item in $elementosRequeridos) {
    $itemPath = Join-Path -Path $LocalProjectPath -ChildPath $item
    if (Test-Path $itemPath) {
        try {
            Copy-Item -Path $itemPath -Destination $RemoteProjectPath -Recurse -ToSession $session -Force -ErrorAction Stop
        }
        catch {
            Remove-PSSession -Session $session
            throw "No se pudo copiar '$item' a la VM. Cierre cualquier proceso que este usando archivos en '$RemoteProjectPath\$item' y vuelva a ejecutar el laboratorio. Detalle: $($_.Exception.Message)"
        }
    }
    else {
        Write-Warning "El archivo o carpeta '$item' no se encontro en el host."
    }
}

Remove-PSSession -Session $session

Write-Host "Laboratorio Listo. Ejecutando el menu principal en la VM..." -ForegroundColor Green
Invoke-Command -VMName $VMName -Credential $cred -ScriptBlock {
    Set-Location -Path "C:\aulascript"
    .\instalar.ps1
}
Write-Host "====== Sesion de Laboratorio finalizada ======" -ForegroundColor Green
