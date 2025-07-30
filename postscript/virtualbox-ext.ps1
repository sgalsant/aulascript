<#
.SYNOPSIS
    Instala el VirtualBox Extension Pack después de la instalación de VirtualBox.
.DESCRIPTION
    Este script busca el ejecutable VBoxManage.exe y el archivo .vbox-extpack
    para realizar una instalación silenciosa del pack de extensiones.
    Está diseñado para ser llamado como un 'postscript' desde el instalador principal.
#>

Write-Host "Ejecutando post-script para VirtualBox: Instalando Extension Pack..." -ForegroundColor Cyan

# --- CONFIGURACION ---
$installersPath = "$PSScriptRoot\..\repo"
# La ruta por defecto donde VirtualBox instala su herramienta de línea de comandos
$vboxManagePath = Join-Path $env:ProgramFiles "Oracle\VirtualBox\VBoxManage.exe"
# --- FIN CONFIGURACION ---

try {
    if (-not (Test-Path $vboxManagePath)) {
        throw "No se encontró VBoxManage.exe en la ruta esperada: $vboxManagePath"
    }

    $extensionPack = Get-ChildItem -Path $installersPath -Filter "*.vbox-extpack" | Select-Object -First 1

    if (-not $extensionPack) {
        throw "No se encontró ningún archivo .vbox-extpack en la carpeta $installersPath"
    }

    Write-Host "Instalando Extension Pack: $($extensionPack.Name)"
    # Se envía 'y' a través de una tubería (pipe) para aceptar la licencia de forma automática.
    Write-Output 'y' | & $vboxManagePath extpack install --replace "$($extensionPack.FullName)"

    Write-Host "Extension Pack instalado correctamente." -ForegroundColor Green
}
catch {
    Write-Warning "No se pudo instalar el VirtualBox Extension Pack. Error: $_"
}
