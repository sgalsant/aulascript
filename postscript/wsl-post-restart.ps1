wsl --set-default-version 2

# Importar funciones de utilidad
. "$PSScriptRoot\..\script\utils.ps1"

# Cuando se ejecuta desde RunOnce, $PSScriptRoot es el directorio del script (ej: ...\aulascript-1\postscript)
# Necesitamos subir un nivel para encontrar la carpeta 'repo'.
$projectRoot = Split-Path -Path $PSScriptRoot -Parent
$repoPath = Join-Path -Path $projectRoot -ChildPath "repo"

Write-Host "Ruta del repositorio de imágenes: $repoPath"

$imageName = "ubuntu-24.04.2-wsl-amd64.gz"
$imagePath = Join-Path -Path $repoPath -ChildPath $imageName

Write-Host "Importando imagen: $imagePath"
wsl --import ubuntu c:/ubuntu "$imagePath" --version 2
Wait-KeyWithTimeout -Message "Importación finalizada. Presione cualquier tecla para cerrar o espere {0} segundos."