 #requires -RunAsAdministrator

<#
.SYNOPSIS
    Instala o actualiza el VirtualBox Extension Pack.
.DESCRIPTION
    Este script comprueba la versión de VirtualBox y del Extension Pack instalado.
    Si es necesario, instala o actualiza el pack de extensiones encontrado en la carpeta 'repo'.
    Puede ejecutarse de forma independiente o como post-script.
#>

Write-Host "Verificando instalación del VirtualBox Extension Pack..." -ForegroundColor Cyan

# --- CONFIGURACION ---
# Resuelve la ruta a la carpeta 'repo' de forma robusta
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$installersPath = Join-Path $projectRoot "repo"
# La ruta por defecto donde VirtualBox instala su herramienta de línea de comandos
$vboxManagePath = Join-Path $env:ProgramFiles "Oracle\VirtualBox\VBoxManage.exe"
# --- FIN CONFIGURACION ---

try {
    # 1. Verificar que VBoxManage.exe existe
    if (-not (Test-Path $vboxManagePath)) {
        throw "VirtualBox no parece estar instalado en la ruta por defecto: $vboxManagePath"
    }

    # 2. Encontrar el archivo del Extension Pack en el repositorio
    $extensionPackFile = Get-ChildItem -Path $installersPath -Filter "*.vbox-extpack" | Select-Object -First 1
    if (-not $extensionPackFile) {
        throw "No se encontró ningún archivo .vbox-extpack en la carpeta $installersPath"
    }

    # 3. Extraer la versión del archivo del Extension Pack
    $fileVersion = if ($extensionPackFile.BaseName -match '(\d+\.\d+\.\d+)') { $Matches[1] } else { $null }
    if (-not $fileVersion) {
        throw "No se pudo determinar la versión desde el nombre del archivo: $($extensionPackFile.Name)"
    }
    Write-Host "INFO: Versión del Extension Pack encontrada en el repo: $fileVersion"

    # 4. Obtener la versión del Extension Pack ya instalado (si existe)
    $installedExtPack = & $vboxManagePath list extpacks | Select-String -Pattern "Version:"
    $installedVersion = if ($installedExtPack -match '(\d+\.\d+\.\d+)') { $Matches[1] } else { $null }

    # 5. Comparar versiones y decidir si instalar
    if ($installedVersion -eq $fileVersion) {
        Write-Host "INFO: El Extension Pack versión $fileVersion ya está instalado. No se requiere ninguna acción." -ForegroundColor Green
    } else {
        if ($installedVersion) {
            Write-Host "INFO: Se encontró una versión diferente ($installedVersion). Actualizando a $fileVersion..."
        } else {
            Write-Host "INFO: No hay un Extension Pack instalado. Instalando versión $fileVersion..."
        }

        Write-Host "Instalando: $($extensionPackFile.Name)"
        # Se envía 'y' a través de una tubería (pipe) para aceptar la licencia de forma automática.
        $installResult = Write-Output 'y' | & $vboxManagePath extpack install --replace "$($extensionPackFile.FullName)" 2>&1

        # Verificar si la instalación fue exitosa
        if ($LASTEXITCODE -ne 0 -or $installResult -match "error|failed") {
            throw "La instalación del Extension Pack falló. Salida del comando: $installResult"
        }

        Write-Host "Extension Pack instalado/actualizado correctamente a la versión $fileVersion." -ForegroundColor Green
    }
}
catch {
    Write-Warning "No se pudo instalar el VirtualBox Extension Pack. Error: $_"
}

# Añadir una pausa si se ejecuta directamente para que el usuario pueda leer la salida
if ($MyInvocation.Line) {
    Read-Host "`nProceso finalizado. Presione Enter para salir."
}
