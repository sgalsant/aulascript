<#
.SYNOPSIS
    Script Enterprise para configurar Hyper-V para usuarios estándar en Windows 11.
    Incluye: validación de SO, parámetros para despliegue masivo, tarea programada
    de auto-continuación tras reinicio (ejecutada como SYSTEM), logs con Hostname,
    redes limpias e interactividad opcional.

.PARAMETER UnidadVMs
    Letra de unidad donde crear la carpeta 'hypervm' (ej. C, D).
    Si se omite y -NoInteractivo no está activo, se preguntará al usuario.

.PARAMETER NoInteractivo
    Suprime todas las preguntas. Ideal para despliegue masivo via GPO/PDQ/Intune.
    Si -UnidadVMs también se omite, se salta la configuración de almacenamiento.

.EXAMPLE
    # Ejecución manual (con preguntas)
    powershell.exe -ExecutionPolicy Bypass -File HyperV_Setup.ps1

.EXAMPLE
    # Despliegue masivo silencioso con VMs en D:
    powershell.exe -ExecutionPolicy Bypass -File HyperV_Setup.ps1 -UnidadVMs D -NoInteractivo
#>

param(
    [string]$UnidadVMs = "",
    [switch]$NoInteractivo
)

# ============================================================
# --- CONFIGURACIÓN GLOBAL ---
# ============================================================
$ScriptPath = $MyInvocation.MyCommand.Path
$NombreHost = $env:COMPUTERNAME
$FechaHora = Get-Date -Format "yyyyMMdd_HHmmss"
# Usar el log de sesión centralizado si existe (lanzado desde el menú), o crear uno propio (ejecución directa)
$LogFile = if ($env:AULA_LOG_FILE) {
    $env:AULA_LOG_FILE
}
else {
    $BaseDir = (Get-Item $PSScriptRoot).Parent.FullName
    Join-Path -Path $BaseDir -ChildPath "HyperV_Setup_${NombreHost}_${FechaHora}.log"
}
$TareaName = "HyperV_Setup_PostReinicio"
$HyperVSID = "S-1-5-32-578"

# ============================================================
# --- FUNCIÓN DE LOG ---
# ============================================================
function Write-Log {
    param([string]$Mensaje, [string]$Color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $mensajeLog = $Mensaje -replace "`n", ""
    "$timestamp [$NombreHost] - $mensajeLog" | Out-File -FilePath $LogFile -Append -Encoding UTF8
    Write-Host $Mensaje -ForegroundColor $Color
}

# ============================================================
# --- 0. COMPROBACIÓN DE PRIVILEGIOS ---
# ============================================================
$esAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $esAdmin) {
    Write-Host "`n[ERROR] Este script debe ejecutarse como Administrador." -ForegroundColor Red
    Write-Host "        Haz clic derecho en PowerShell -> 'Ejecutar como administrador'." -ForegroundColor Yellow
    exit 1
}

Write-Log "`n=== INICIANDO CONFIGURACIÓN DE HYPER-V ===" "Cyan"
Write-Log "Historial guardado en: $LogFile" "DarkGray"
Write-Log "Modo desatendido: $($NoInteractivo.IsPresent)" "DarkGray"

# ============================================================
# --- 1. BLOQUEO PARA WINDOWS HOME ---
# ============================================================
Write-Log "`n[1/7] Comprobando edición de Windows..." "Yellow"
$os = (Get-CimInstance Win32_OperatingSystem).Caption
if ($os -match "Home") {
    Write-Log "   [ERROR] Detectado: $os" "Red"
    Write-Log "   Hyper-V no está disponible en ediciones Home. Necesitas Pro o Enterprise." "Red"
    exit 1
}
Write-Log "   [OK] Edición compatible: $os" "Green"

# ============================================================
# --- 2. COMPROBAR BIOS/UEFI ---
# ============================================================
Write-Log "`n[2/7] Comprobando virtualización en BIOS/UEFI..." "Yellow"
$biosOK = $false
foreach ($proc in (Get-CimInstance Win32_Processor)) {
    if ($proc.VirtualizationFirmwareEnabled) { $biosOK = $true }
}
if ($biosOK) {
    Write-Log "   [OK] Virtualización habilitada en BIOS." "Green"
}
else {
    Write-Log "   [ADVERTENCIA] Virtualización desactivada en BIOS. Las VMs no arrancarán hasta que la actives en la placa base." "Red"
    if (-not $NoInteractivo) {
        $resp = Read-Host "   ¿Continuar de todas formas? (S/N)"
        if ($resp -notmatch "^[Ss]$") {
            Write-Log "   [INFO] Cancelado por el usuario." "DarkGray"
            exit 0
        }
    }
}

# ============================================================
# --- 3. HABILITAR HYPER-V ---
# ============================================================
Write-Log "`n[3/7] Comprobando caracteristica Hyper-V..." "Yellow"
$necesitaReinicio = $false

# Suprimir barra de progreso para evitar bloqueos en sesiones remotas/no interactivas
$ProgressPreference = 'SilentlyContinue'

try {
    $hypervFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -ErrorAction Stop

    if ($hypervFeature.State -ne 'Enabled') {
        Write-Log "   Instalando Hyper-V con DISM (puede tardar varios minutos)..." "Cyan"

        # Usar DISM.exe directamente: mas fiable que Enable-WindowsOptionalFeature
        # que puede bloquearse intentando contactar Windows Update o mostrar progreso UI.
        $dismArgs = @('/Online', '/Enable-Feature', '/FeatureName:Microsoft-Hyper-V', '/All', '/NoRestart', '/Quiet')
        $dismResult = Start-Process -FilePath 'DISM.exe' -ArgumentList $dismArgs -Wait -PassThru -NoNewWindow

        switch ($dismResult.ExitCode) {
            0 {
                Write-Log "   [OK] Hyper-V instalado. No se requiere reinicio." "Green"
            }
            3010 {
                $necesitaReinicio = $true
                Write-Log "   [OK] Hyper-V instalado. Se requiere reinicio para completar." "Yellow"
            }
            default {
                throw "DISM finalizo con codigo de error: $($dismResult.ExitCode)"
            }
        }
    }
    else {
        Write-Log "   [OK] Hyper-V ya estaba instalado." "Green"
    }
}
catch {
    Write-Log "   [ERROR] Fallo al instalar Hyper-V: $_" "Red"
    exit 1
}

# ============================================================
# --- 4. TAREA PROGRAMADA DE AUTO-CONTINUACIÓN (si hace falta reinicio) ---
# ============================================================
if ($necesitaReinicio) {
    Write-Log "`n[4/7] Registrando tarea de auto-continuación tras reinicio..." "Yellow"

    # Construimos el argumento que re-lanzará este mismo script con los mismos parámetros
    $argumentos = "-ExecutionPolicy Bypass -NonInteractive -File `"$ScriptPath`""
    if ($UnidadVMs -ne "") { $argumentos += " -UnidadVMs $UnidadVMs" }
    $argumentos += " -NoInteractivo"   # Tras reinicio siempre desatendido (corre como SYSTEM)

    $accion = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $argumentos
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $config = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -AllowStartIfOnBatteries
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

    # Eliminamos la tarea si existía de una ejecución anterior
    Unregister-ScheduledTask -TaskName $TareaName -Confirm:$false -ErrorAction SilentlyContinue

    Register-ScheduledTask -TaskName $TareaName `
        -Action $accion `
        -Trigger $trigger `
        -Settings $config `
        -Principal $principal `
        -Description "Continúa la configuración de Hyper-V tras el reinicio requerido por la instalación." `
        -ErrorAction Stop | Out-Null

    Write-Log "   [OK] Tarea '$TareaName' registrada. Se ejecutará como SYSTEM al arrancar." "Green"
    Write-Log "`n========================================================" "Cyan"
    Write-Log "   REINICIA EL EQUIPO. La configuración continuará sola." "Red"
    Write-Log "   No es necesario volver a ejecutar el script manualmente." "Yellow"
    Write-Log "========================================================`n" "Cyan"
    exit 0
}

# ============================================================
# --- AUTO-LIMPIEZA: eliminar la tarea si llegamos aquí ---
# (significa que ya no se necesita más)
# ============================================================
if (Get-ScheduledTask -TaskName $TareaName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TareaName -Confirm:$false
    Write-Log "   [OK] Tarea de auto-continuación eliminada (ya no necesaria)." "DarkGray"
}

# ============================================================
# --- 5. LOCALIZAR GRUPO Y ASIGNAR USUARIOS ---
# ============================================================
Write-Log "`n[5/7] Asignando permisos a usuarios estándar..." "Yellow"

# Espera al servicio VMMS (puede tardar unos segundos tras arrancar)
$svc = Get-Service -Name vmms -ErrorAction SilentlyContinue
if ($null -ne $svc -and $svc.Status -ne 'Running') {
    Write-Log "   Esperando al servicio vmms..." "Cyan"
    Start-Service -Name vmms -ErrorAction SilentlyContinue
    $intentos = 0
    while ((Get-Service -Name vmms).Status -ne 'Running' -and $intentos -lt 10) {
        Start-Sleep -Seconds 2
        $intentos++
    }
}

$grupoHyperV = Get-LocalGroup | Where-Object { $_.SID.Value -eq $HyperVSID }
if (-not $grupoHyperV) {
    Write-Log "   [ERROR] Grupo de Hyper-V (SID $HyperVSID) no encontrado." "Red"
    exit 1
}
Write-Log "   [OK] Grupo localizado: $($grupoHyperV.Name)" "Green"

$usuarios = Get-LocalUser | Where-Object { [int]($_.SID.Value.Split('-')[-1]) -ge 1000 -and $_.Enabled -eq $true }
$miembrosActuales = (Get-LocalGroupMember -Group $grupoHyperV.Name -ErrorAction SilentlyContinue).SID.Value

foreach ($usuario in $usuarios) {
    if ($null -ne $miembrosActuales -and $miembrosActuales -contains $usuario.SID.Value) {
        Write-Log "   -> [OMITIDO] '$($usuario.Name)' ya tiene permisos." "DarkGray"
    }
    else {
        try {
            Add-LocalGroupMember -Group $grupoHyperV.Name -Member $usuario.Name -ErrorAction Stop
            Write-Log "   -> [OK] Permisos concedidos a: '$($usuario.Name)'." "Green"
        }
        catch {
            Write-Log "   -> [ERROR] Fallo al añadir '$($usuario.Name)': $_" "Red"
        }
    }
}

# ============================================================
# --- 6. CREAR REDES VIRTUALES ---
# ============================================================
Write-Log "`n[6/7] Configurando conmutadores virtuales..." "Yellow"

$nombreSwitchExt = "Red Virtual Externa"
if (Get-VMSwitch -Name $nombreSwitchExt -ErrorAction SilentlyContinue) {
    Write-Log "   [OK] Conmutador externo '$nombreSwitchExt' ya existe." "DarkGray"
}
else {
    # Seleccionar el primer adaptador activo que NO sea loopback, TAP, VPN o de otra herramienta de virtualizacion.
    # NOTA: dentro de una VM Hyper-V todos los adaptadores son "Microsoft Hyper-V Network Adapter",
    #       por lo que NO se excluye "Hyper-V" del filtro de descripcion.
    $adaptadoresActivos = Get-NetAdapter | Where-Object {
        $_.Status -eq 'Up' -and
        $_.InterfaceDescription -notmatch "VirtualBox|VMware|VPN|TAP|Cisco|Loopback|WireGuard|Virtual Ethernet Adapter"
    }

    # Excluir adaptadores que ya estan vinculados a un conmutador virtual existente
    # (causaria el error "La secuencia no contiene ningun elemento coincidente")
    $switchesExistentes = Get-VMSwitch -ErrorAction SilentlyContinue
    $adaptadoresEnUso = $switchesExistentes | Where-Object { $_.SwitchType -eq 'External' } |
    ForEach-Object { $_.NetAdapterInterfaceDescription }

    $adaptadorActivo = $adaptadoresActivos | Where-Object {
        $_.InterfaceDescription -notin $adaptadoresEnUso
    } | Select-Object -First 1

    # Mostrar los adaptadores candidatos para facilitar el diagnostico
    Write-Log "   Adaptadores en uso por switches: $(($adaptadoresEnUso -join ', ') -replace '^$', 'ninguno')" "DarkGray"
    if ($adaptadoresActivos) {
        $adaptadoresActivos | ForEach-Object {
            Write-Log "   Candidato: '$($_.Name)' - $($_.InterfaceDescription)" "DarkGray"
        }
    }

    if ($adaptadorActivo) {
        try {
            Write-Log "   Creando conmutador externo en: $($adaptadorActivo.Name) ($($adaptadorActivo.InterfaceDescription))..." "Cyan"
            New-VMSwitch -Name $nombreSwitchExt -NetAdapterName $adaptadorActivo.Name -AllowManagementOS $true -ErrorAction Stop | Out-Null
            Write-Log "   [OK] Conmutador '$nombreSwitchExt' creado." "Green"
        }
        catch {
            Write-Log "   [ERROR] Fallo al crear conmutador externo: $_" "Red"
            Write-Log "   Adaptador intentado: '$($adaptadorActivo.Name)'" "Red"
        }
    }
    else {
        Write-Log "   [ADVERTENCIA] No se encontro tarjeta de red disponible (sin asignar a otro switch) para la red externa." "Yellow"
        Write-Log "   Si ya existe un switch externo con otro nombre, puede ignorar este aviso." "DarkGray"
    }
}

foreach ($red in @("lan1", "lan2", "lan3")) {
    if (Get-VMSwitch -Name $red -ErrorAction SilentlyContinue) {
        Write-Log "   [OK] Red privada '$red' ya existe." "DarkGray"
    }
    else {
        try {
            New-VMSwitch -Name $red -SwitchType Private -ErrorAction Stop | Out-Null
            Write-Log "   [OK] Red privada '$red' creada." "Green"
        }
        catch {
            Write-Log "   [ERROR] Fallo al crear '$red': $_" "Red"
        }
    }
}

# ============================================================
# --- 7. CONFIGURAR ALMACENAMIENTO ---
# ============================================================
Write-Log "`n[7/7] Configurando almacenamiento predeterminado..." "Yellow"

# Determinamos la unidad: parámetro > preguntar > saltar
if ($UnidadVMs -eq "" -and -not $NoInteractivo) {
    $respuestaCarpeta = Read-Host "   ¿Configurar carpeta 'hypervm' para las VMs? (S/N)"
    if ($respuestaCarpeta -match "^[Ss]$") {
        $unidadValida = $false
        do {
            $entrada = Read-Host "   Letra de unidad (ej. C, D) o 'X' para cancelar"
            $entrada = $entrada.Trim().TrimEnd(':').ToUpper()
            if ($entrada -eq 'X') {
                Write-Log "   [INFO] Cancelado por el usuario." "DarkGray"
                break
            }
            if (Test-Path "$($entrada):\") {
                $UnidadVMs = $entrada
                $unidadValida = $true
            }
            else {
                Write-Log "   [ERROR] La unidad $($entrada):\ no existe. Inténtalo de nuevo." "Red"
            }
        } while (-not $unidadValida)
    }
    else {
        Write-Log "   [INFO] Omitido por el usuario." "DarkGray"
    }
}
elseif ($UnidadVMs -eq "" -and $NoInteractivo) {
    Write-Log "   [INFO] Sin unidad especificada en modo desatendido. Omitiendo almacenamiento." "DarkGray"
}

if ($UnidadVMs -ne "") {
    $UnidadVMs = $UnidadVMs.Trim().TrimEnd(':').ToUpper()
    if (-not (Test-Path "$($UnidadVMs):\")) {
        Write-Log "   [ERROR] La unidad $($UnidadVMs):\ no existe." "Red"
    }
    else {
        $rutaVMs = "$($UnidadVMs):\hypervm"

        if (-not (Test-Path -Path $rutaVMs)) {
            New-Item -ItemType Directory -Path $rutaVMs | Out-Null
            Write-Log "   [OK] Carpeta creada en: $rutaVMs" "Green"
        }
        else {
            Write-Log "   [OK] La carpeta ya existía en: $rutaVMs" "DarkGray"
        }

        try {
            $acl = Get-Acl -Path $rutaVMs
            $identificador = New-Object System.Security.Principal.SecurityIdentifier($HyperVSID)
            $regla = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $identificador, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
            )
            $acl.AddAccessRule($regla)
            Set-Acl -Path $rutaVMs -AclObject $acl
            Write-Log "   [OK] Permisos NTFS aplicados." "Green"

            Set-VMHost -VirtualMachinePath $rutaVMs -VirtualHardDiskPath $rutaVMs -ErrorAction Stop
            Write-Log "   [OK] Rutas de Hyper-V redirigidas a $rutaVMs." "Green"
        }
        catch {
            Write-Log "   [ERROR] Fallo al aplicar permisos o rutas: $_" "Red"
        }
    }
}

# ============================================================
# --- FIN ---
# ============================================================
Write-Log "`n========================================================" "Cyan"
Write-Log "   PROCESO COMPLETADO EXITOSAMENTE." "Green"
Write-Log "   Los alumnos deben CERRAR SESIÓN y volver a entrar." "Yellow"
Write-Log "========================================================`n" "Cyan"
