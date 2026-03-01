#requires -RunAsAdministrator

<#
.SYNOPSIS
    Configura la red estática de un equipo, calculando la IP a partir del nombre del host.
.DESCRIPTION
    Este script asigna una dirección IP estática, puerta de enlace y servidores DNS.
    Calcula la IP por defecto basándose en los dos últimos dígitos del nombre del equipo.
    Permite anular los valores calculados mediante parámetros o de forma interactiva.
.PARAMETER InterfaceAlias
    Nombre de la interfaz de red a configurar. Por defecto es 'Ethernet'.
.PARAMETER IPAddress
    La dirección IP a asignar. Si no se especifica, se calcula automáticamente.
.PARAMETER PrefixLength
    La longitud del prefijo de la máscara de subred (ej. 24 para 255.255.255.0).
.PARAMETER Gateway
    La puerta de enlace predeterminada.
.PARAMETER DNSServers
    Una lista de servidores DNS.
#>
param (
    [string]$InterfaceAlias = 'Ethernet',
    [string]$IPAddress,
    [int]$PrefixLength = 0, # Se inicializa a 0; se asignará un valor válido más adelante
    [string]$Gateway,
    [string[]]$DNSServers
)

# Importar funciones de utilidad
. "$PSScriptRoot\utils.ps1"

# --- CONFIGURACION DE AULAS ---
# Centralizar la configuración en una tabla hash para facilitar el mantenimiento.
$classroomConfigs = @{
    '5'  = @{ BaseIPNetwork = '10.5.0.'; BaseOctet = 50; DefaultGateway = '10.5.0.1'; DefaultPrefixLength = 16; DNSServers = @('8.8.8.8') }
    '6'  = @{ BaseIPNetwork = '10.6.0.'; BaseOctet = 50; DefaultGateway = '10.6.0.1'; DefaultPrefixLength = 16; DNSServers = @('8.8.8.8') }
    '11' = @{ BaseIPNetwork = '10.11.0.'; BaseOctet = 50; DefaultGateway = '10.11.0.1'; DefaultPrefixLength = 16; DNSServers = @('8.8.8.8') }
    '12' = @{ BaseIPNetwork = '192.168.5.'; BaseOctet = 50; DefaultGateway = '192.168.5.1'; DefaultPrefixLength = 24; DNSServers = @('8.8.8.8') }
}
# --- FIN DE CONFIGURACION ---

Clear-Host
# --- SELECCION DE AULA Y CONFIGURACION DE RED ---
# Declarar las variables para que tengan alcance fuera del bucle
$selectedConfig = $null
$useDhcp = $false

while ($true) {
    Write-Host "Por favor, seleccione el aula para configurar la red:" -ForegroundColor Yellow
    foreach ($key in $classroomConfigs.Keys | Sort-Object) {
        Write-Host "  [$key] - Aula $key"
    }
    Write-Host "  [D] - Configurar con DHCP (Automatico)"
    $choice = Read-Host "`nIntroduzca su seleccion"

    if ($choice.ToLower() -eq 'd') {
        $useDhcp = $true
        Write-AulaLog -Message "Se configurará la red para usar DHCP." -Level INFO
        Start-Sleep -Seconds 1
        break
    }

    if ($classroomConfigs.ContainsKey($choice)) {
        $selectedConfig = $classroomConfigs[$choice]
        Write-AulaLog -Message "Configuración para el Aula $choice seleccionada." -Level INFO
        Start-Sleep -Seconds 1
        break
    }
    else {
        Write-AulaLog -Message "Seleccion no valida. Por favor, intentelo de nuevo." -Level WARNING
        Start-Sleep -Seconds 2
        Clear-Host
    }
}
# --- FIN DE LA SELECCION ---

# --- DETECCION AUTOMATICA DE INTERFAZ (si no se especifica) ---
if (-not $PSBoundParameters.ContainsKey('InterfaceAlias')) {
    Write-AulaLog -Message "Buscando primer adaptador de red físico, cableado y conectado (no Wi-Fi)..." -Level INFO
    # Busca adaptadores físicos, que no sean Wi-Fi (ifType 71) y que estén activos ('Up')
    $activeAdapter = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' -and $_.ifType -ne 71 } | Select-Object -First 1

    if ($activeAdapter) {
        $InterfaceAlias = $activeAdapter.Name
        Write-AulaLog -Message "Interfaz detectada automaticamente: '$InterfaceAlias'" -Level SUCCESS
    }
    else {
        Write-AulaLog -Message "No se pudo detectar un adaptador de red cableado y activo. Se usará el valor por defecto: '$InterfaceAlias'." -Level WARNING
        Write-AulaLog -Message "Si el script falla, compruebe las conexiones de red o ejecútelo de nuevo especificando el nombre correcto, ej: -InterfaceAlias 'Ethernet 2'" -Level WARNING
    }
}
# --- FIN DE DETECCION ---

# --- CONFIRMACION DEL USUARIO ---
Clear-Host
Write-Host "=================================================" -ForegroundColor Yellow
Write-Host "      CONFIGURACION DE RED A APLICAR" -ForegroundColor Yellow
Write-Host "================================================="
Write-Host
Write-Host "  Interfaz: $InterfaceAlias"

if ($useDhcp) {
    Write-Host "  Modo....: DHCP (Automatico)"
}
else {
    # Si no se proporcionó una IP, la calculamos
    if ([string]::IsNullOrWhiteSpace($IPAddress)) {
        try {
            # Extraer los dígitos finales del nombre del equipo. Ej: PC-07 -> 7, AULA1-15 -> 15
            if ([System.Environment]::MachineName -match '(\d+)$') {
                $hostNumber = [int]$Matches[1]
            }
            else {
                Write-AulaLog -Message "No se encontraron dígitos al final del nombre del equipo. Usando 0." -Level WARNING
                $hostNumber = 0
            }
            
            $finalOctet = $selectedConfig.BaseOctet + $hostNumber
            if ($finalOctet -gt 254) { $finalOctet = 254 }

            $IPAddress = "$($selectedConfig.BaseIPNetwork)$finalOctet"
        }
        catch {
            Write-AulaLog -Message "No se pudo calcular la IP a partir del nombre del equipo. Error: $_" -Level ERROR
            exit 1
        }
    }

    # Asignar valores por defecto si los parámetros correspondientes están vacíos
    if ([string]::IsNullOrWhiteSpace($Gateway)) { $Gateway = $selectedConfig.DefaultGateway }
    if ($null -eq $DNSServers -or $DNSServers.Count -eq 0) { $DNSServers = $selectedConfig.DNSServers }
    if ($PrefixLength -eq 0) { $PrefixLength = $selectedConfig.DefaultPrefixLength }

    Write-Host "  Direccion IP........: $IPAddress"
    Write-Host "  Mascara de subred...: (/$PrefixLength)"
    Write-Host "  Puerta de enlace....: $Gateway"
    Write-Host "  Servidores DNS......: $($DNSServers -join ', ')"
}
Write-Host "================================================="

# El script continuará si se introduce 's' o se presiona Enter. Cualquier otra tecla cancelará.
$confirm = Read-Host "`nAplicar esta configuracion? [S/n]"
if ($confirm.ToLower() -notin @('s', '')) {
    Write-AulaLog -Message "Operación cancelada por el usuario." -Level WARNING
    Start-Sleep -Seconds 3
    exit
}

# --- APLICACION DE LA CONFIGURACION ---
try {
    $adapter = Get-NetAdapter -Name $InterfaceAlias -ErrorAction Stop
    Write-AulaLog -Message "Configurando IP estática para '$($adapter.Name)'..." -Level INFO

    if ($useDhcp) {
        Write-AulaLog -Message "Habilitando DHCP en '$($adapter.Name)'..." -Level INFO
        Set-NetIPInterface -InterfaceIndex $adapter.InterfaceIndex -Dhcp Enabled -ErrorAction Stop
        Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ResetServerAddresses -ErrorAction Stop
        Write-AulaLog -Message "Configuración DHCP completada." -Level SUCCESS
    }
    else {
        # Eliminar IPs y Gateways previos para evitar conflictos
        # Primero se elimina la ruta por defecto (Gateway) para evitar problemas
        try {
            Remove-NetRoute -InterfaceIndex $adapter.InterfaceIndex -DestinationPrefix 0.0.0.0/0 -Confirm:$false -ErrorAction Stop
            Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction Stop | Remove-NetIPAddress -Confirm:$false -ErrorAction Stop
        }
        catch {
            Write-AulaLog -Message "Advertencia al purgar rutas previas (puede ignorarse si estaba limpia): $($_.Exception.Message)" -Level WARNING
        }
        
        # Asignar la nueva configuración de IP y Puerta de enlace
        New-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -IPAddress $IPAddress -PrefixLength $PrefixLength -DefaultGateway $Gateway -ErrorAction Stop | Out-Null
        Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses $DNSServers -ErrorAction Stop
        Write-AulaLog -Message "Configuración de red estática completada exitosamente." -Level SUCCESS
    }
}
catch {
    Write-AulaLog -Message "Ocurrio un error CRITICO al aplicar la configuracion de red: $($_.Exception.Message)" -Level ERROR
}
