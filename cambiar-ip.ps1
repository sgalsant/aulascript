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
    [int]$PrefixLength = 24,
    [string]$Gateway,
    [string[]]$DNSServers
)

# --- CONFIGURACION POR DEFECTO (si no se pasan por parámetro) ---
$BaseIPNetwork = '192.168.150.'
$BaseOctet = 50
$DefaultGateway = '192.168.150.1'
$DefaultDNSServers = @('192.168.150.2', '8.8.8.8')
# --- FIN DE LA CONFIGURACION ---

# --- DETECCION AUTOMATICA DE INTERFAZ (si no se especifica) ---
if (-not $PSBoundParameters.ContainsKey('InterfaceAlias')) {
    Write-Host "Buscando primer adaptador de red físico, cableado y conectado (no Wi-Fi)..."
    # Busca adaptadores físicos, que no sean Wi-Fi (ifType 71) y que estén activos ('Up')
    $activeAdapter = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' -and $_.ifType -ne 71 } | Select-Object -First 1

    if ($activeAdapter) {
        $InterfaceAlias = $activeAdapter.Name
        Write-Host "Interfaz detectada automáticamente: '$InterfaceAlias'" -ForegroundColor Green
    } else {
        Write-Warning "No se pudo detectar un adaptador de red cableado y activo. Se usará el valor por defecto: '$InterfaceAlias'."
        Write-Warning "Si el script falla, compruebe las conexiones de red o ejecútelo de nuevo especificando el nombre correcto, ej: -InterfaceAlias 'Ethernet 2'"
    }
}
# --- FIN DE DETECCION ---

# Si no se proporcionó una IP, la calculamos
if ([string]::IsNullOrWhiteSpace($IPAddress)) {
    try {
        # Extraer TODOS los dígitos del hostname y coger los dos últimos
        $hostnameDigits = ($env:COMPUTERNAME -replace '[^0-9]')
        if ($hostnameDigits.Length -ge 2) {
            $lastDigits = $hostnameDigits.Substring($hostnameDigits.Length - 2)
        } elseif ($hostnameDigits.Length -eq 1) {
            $lastDigits = $hostnameDigits
        } else {
            $lastDigits = "0"
        }
        
        $hostNumber = [int]$lastDigits
        $finalOctet = $BaseOctet + $hostNumber
        
        if ($finalOctet -gt 254) { $finalOctet = 254 }

        $IPAddress = "$BaseIPNetwork$finalOctet"
    } catch {
        Write-Error "No se pudo calcular la IP a partir del nombre del equipo. Error: $_"
        exit 1
    }
}

# Asignar valores por defecto si los parámetros correspondientes están vacíos
if ([string]::IsNullOrWhiteSpace($Gateway)) { $Gateway = $DefaultGateway }
if ($null -eq $DNSServers -or $DNSServers.Count -eq 0) { $DNSServers = $DefaultDNSServers }

# --- CONFIRMACION DEL USUARIO ---
Clear-Host
Write-Host "=================================================" -ForegroundColor Yellow
Write-Host "      CONFIGURACION DE RED A APLICAR" -ForegroundColor Yellow
Write-Host "================================================="
Write-Host
Write-Host "  Interfaz............: $InterfaceAlias"
Write-Host "  Dirección IP........: $IPAddress"
Write-Host "  Máscara de subred...: (/$PrefixLength)"
Write-Host "  Puerta de enlace....: $Gateway"
Write-Host "  Servidores DNS......: $($DNSServers -join ', ')"
Write-Host
Write-Host "================================================="
Write-Host
# El script continuará si se introduce 's' o se presiona Enter. Cualquier otra tecla cancelará.
$choice = Read-Host "¿Aplicar esta configuración? [S/n]"
if ($choice.ToLower() -notin @('s', '')) {
    Write-Warning "Operación cancelada por el usuario."
    Start-Sleep -Seconds 3
    exit
}

# --- APLICACION DE LA CONFIGURACION ---
try {
    Write-Host "`nConfigurando zona horaria y PS Remoting..." -ForegroundColor Cyan
    Set-TimeZone -Id 'GMT Standard Time' 
    Enable-PSRemoting -SkipNetworkProfileCheck -Force 

    Write-host "adaptador"

    $adapter = Get-NetAdapter -Name $InterfaceAlias -ErrorAction Stop
    Write-Host "Configurando IP estática para '$($adapter.Name)'..." -ForegroundColor Cyan
    
    # Eliminar IPs y Gateways previos para evitar conflictos
    # Primero se elimina la ruta por defecto (Gateway) para evitar problemas
    Remove-NetRoute -InterfaceIndex $adapter.InterfaceIndex -DestinationPrefix 0.0.0.0/0 -Confirm:$false -ErrorAction SilentlyContinue
    Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
    
    # Asignar la nueva configuración de IP y Puerta de enlace
    New-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -IPAddress $IPAddress -PrefixLength $PrefixLength -DefaultGateway $Gateway -ErrorAction Stop
    Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses $DNSServers -ErrorAction Stop
    Write-Host "`nConfiguración de red completada." -ForegroundColor Green
} catch {
    Write-Error "Ocurrió un error al aplicar la configuración: $_"
}

Write-Host "`nProceso finalizado. Presione cualquier tecla para cerrar la ventana."
[void][System.Console]::ReadKey($true)