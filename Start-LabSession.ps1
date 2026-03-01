param(
    [switch]$NoRestore
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
Invoke-Command -Session $session -ScriptBlock {
    if (Test-Path "C:\aulascript") { Remove-Item -Path "C:\aulascript" -Recurse -Force }
    New-Item -Path "C:\aulascript" -ItemType Directory | Out-Null
}

Write-Host "Copiando archivos necesarios a la VM ($RemoteProjectPath)..." -ForegroundColor Cyan
# Obtenemos solo los archivos y carpetas estrictamente necesarios para los scripts
$elementosRequeridos = @("script", "postscript", "instalar.ps1", "instalar.bat", "aplicaciones.json")

foreach ($item in $elementosRequeridos) {
    $itemPath = Join-Path -Path $LocalProjectPath -ChildPath $item
    if (Test-Path $itemPath) {
        Copy-Item -Path $itemPath -Destination $RemoteProjectPath -Recurse -ToSession $session -Force
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