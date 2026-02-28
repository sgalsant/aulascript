# Importar funciones de utilidad
. "$PSScriptRoot\..\script\utils.ps1"

Write-AulaLog -Message "Configurando WSL versión 2 por defecto..." -Level INFO
try {
    wsl --set-default-version 2 | Out-Null
} catch {
    Write-AulaLog -Message "Advertencia al fijar WSL v2 por defecto: $($_.Exception.Message)" -Level WARNING
}

# Cuando se ejecuta desde RunOnce, $PSScriptRoot es el directorio del script (ej: ...\aulascript-1\postscript)
# Necesitamos subir un nivel para encontrar la carpeta 'repo'.
$projectRoot = Split-Path -Path $PSScriptRoot -Parent
$repoPath = Join-Path -Path $projectRoot -ChildPath "repo"

$imageName = "ubuntu-24.04.2-wsl-amd64.gz"
$imagePath = Join-Path -Path $repoPath -ChildPath $imageName

Write-AulaLog -Message "Ruta del repositorio de imágenes: $repoPath" -Level INFO

try {
    Write-AulaLog -Message "Importando imagen: $imagePath" -Level INFO
    # Invocamos el ejecutable dentro del try
    $wslProcess = Start-Process -FilePath "wsl.exe" -ArgumentList "--import ubuntu c:/ubuntu `"$imagePath`" --version 2" -Wait -NoNewWindow -PassThru
    
    if ($wslProcess.ExitCode -eq 0) {
        Write-AulaLog -Message "Importación de Ubuntu en WSL finalizada con éxito." -Level SUCCESS
    } else {
        Write-AulaLog -Message "El proceso wsl.exe devolvió un código de error: $($wslProcess.ExitCode)" -Level ERROR
    }
} catch {
    $errorMessage = $_.Exception.Message
    Write-AulaLog -Message "Error CRÍTICO al importar la imagen WSL: $errorMessage" -Level ERROR
}

Wait-KeyWithTimeout -Message "Script post-reinicio finalizado. Presione cualquier tecla para cerrar o espere {0} segundos."