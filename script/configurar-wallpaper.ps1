<#
.SYNOPSIS
    Configura el fondo de escritorio institucional para usuarios no administradores.
#>

#requires -RunAsAdministrator
[CmdletBinding()]
param()

. "$PSScriptRoot\utils.ps1"

function Test-RunningAsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-RunningAsAdministrator)) {
    $message = 'Este script debe ejecutarse con privilegios de administrador.'
    Write-AulaLog -Message $message -Level ERROR
    throw $message
}

$config = Get-AulaConfig
$sourceImage = Resolve-AulaConfigPath -Path $config.wallpaper.sourcePath
$programDataRoot = Join-Path -Path $env:ProgramData -ChildPath 'AulaScript'
$wallpaperDirectory = Join-Path -Path $programDataRoot -ChildPath 'Wallpapers'
$wallpaperPath = Join-Path -Path $wallpaperDirectory -ChildPath (Split-Path -Path $sourceImage -Leaf)
$helperPath = Join-Path -Path $programDataRoot -ChildPath 'Apply-WallpaperPolicy.ps1'
$activeSetupKey = 'HKLM:\Software\Microsoft\Active Setup\Installed Components\AulaScriptWallpaper'

function Set-WallpaperPolicyInUserHive {
    param(
        [Parameter(Mandatory)]
        [string]$HiveRoot,

        [Parameter(Mandatory)]
        [string]$WallpaperPath,

        [Parameter(Mandatory)]
        [bool]$LockWallpaper
    )

    $activeDesktopPolicyPath = Join-Path -Path $HiveRoot -ChildPath 'Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop'
    $systemPolicyPath = Join-Path -Path $HiveRoot -ChildPath 'Software\Microsoft\Windows\CurrentVersion\Policies\System'
    $desktopPath = Join-Path -Path $HiveRoot -ChildPath 'Control Panel\Desktop'

    New-Item -Path $activeDesktopPolicyPath -Force | Out-Null
    New-Item -Path $systemPolicyPath -Force | Out-Null
    New-Item -Path $desktopPath -Force | Out-Null

    New-ItemProperty -Path $desktopPath -Name 'Wallpaper' -PropertyType String -Value $WallpaperPath -Force | Out-Null
    New-ItemProperty -Path $desktopPath -Name 'WallpaperStyle' -PropertyType String -Value '10' -Force | Out-Null
    New-ItemProperty -Path $desktopPath -Name 'TileWallpaper' -PropertyType String -Value '0' -Force | Out-Null

    if ($LockWallpaper) {
        New-ItemProperty -Path $activeDesktopPolicyPath -Name 'NoChangingWallPaper' -PropertyType DWord -Value 1 -Force | Out-Null
        New-ItemProperty -Path $systemPolicyPath -Name 'Wallpaper' -PropertyType String -Value $WallpaperPath -Force | Out-Null
        New-ItemProperty -Path $systemPolicyPath -Name 'WallpaperStyle' -PropertyType String -Value '10' -Force | Out-Null
    }
    else {
        Remove-ItemProperty -Path $activeDesktopPolicyPath -Name 'NoChangingWallPaper' -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $systemPolicyPath -Name 'Wallpaper' -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $systemPolicyPath -Name 'WallpaperStyle' -ErrorAction SilentlyContinue
    }
}

function Get-LocalAdministratorMemberSidSet {
    $administratorSid = 'S-1-5-32-544'
    $memberSids = @{}

    try {
        $administratorGroup = Get-LocalGroup -SID $administratorSid -ErrorAction Stop
        $members = Get-LocalGroupMember -Group $administratorGroup.Name -ErrorAction Stop

        foreach ($member in $members) {
            if ($member.SID -and $member.SID.Value) {
                $memberSids[$member.SID.Value] = $true
            }
        }
    }
    catch {
        Write-AulaLog -Message "No se pudo enumerar la membresia directa del grupo Administradores local: $($_.Exception.Message)" -Level WARNING
    }

    return $memberSids
}

function Invoke-ExistingUserWallpaperPolicy {
    param(
        [Parameter(Mandatory)]
        [string]$WallpaperPath
    )

    Write-AulaLog -Message 'Aplicando fondo a perfiles locales existentes; bloqueo solo para usuarios no administradores.' -Level INFO

    $administratorMemberSids = Get-LocalAdministratorMemberSidSet
    $profiles = @(Get-CimInstance -ClassName Win32_UserProfile -ErrorAction Stop)
    $enabledUsers = @(Get-LocalUser -ErrorAction Stop | Where-Object {
            $_.Enabled -and
            $_.SID -and
            $_.SID.Value -and
            ([int]($_.SID.Value.Split('-')[-1]) -ge 1000)
        })

    foreach ($user in $enabledUsers) {
        $userSid = $user.SID.Value
        $userName = $user.Name

        $lockWallpaper = -not $administratorMemberSids.ContainsKey($userSid)

        $profile = $profiles | Where-Object { $_.SID -eq $userSid } | Select-Object -First 1
        if (-not $profile -or [string]::IsNullOrWhiteSpace($profile.LocalPath)) {
            Write-AulaLog -Message "Omitiendo usuario '$userName' ($userSid): no se encontro perfil local." -Level WARNING
            continue
        }

        $loadedHiveRoot = "Registry::HKEY_USERS\$userSid"
        if (Test-Path -LiteralPath $loadedHiveRoot) {
            try {
                Set-WallpaperPolicyInUserHive -HiveRoot $loadedHiveRoot -WallpaperPath $WallpaperPath -LockWallpaper $lockWallpaper
                Write-AulaLog -Message "Fondo aplicado al hive cargado de '$userName' ($userSid). Bloqueo de cambios: $lockWallpaper." -Level SUCCESS
            }
            catch {
                Write-AulaLog -Message "No se pudo aplicar la politica al hive cargado de '$userName' ($userSid): $($_.Exception.Message)" -Level ERROR
            }

            continue
        }

        $ntUserDat = Join-Path -Path $profile.LocalPath -ChildPath 'NTUSER.DAT'
        if (-not (Test-Path -LiteralPath $ntUserDat)) {
            Write-AulaLog -Message "Omitiendo usuario '$userName' ($userSid): no existe '$ntUserDat'." -Level WARNING
            continue
        }

        $mountName = 'AulaScriptWallpaper_{0}' -f ($userSid -replace '[^A-Za-z0-9]', '_')
        $mountHiveRoot = "Registry::HKEY_USERS\$mountName"
        $hiveLoadedByScript = $false

        try {
            $loadResult = & reg.exe load "HKU\$mountName" $ntUserDat 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "reg.exe load fallo con codigo $LASTEXITCODE. $loadResult"
            }

            $hiveLoadedByScript = $true
            Set-WallpaperPolicyInUserHive -HiveRoot $mountHiveRoot -WallpaperPath $WallpaperPath -LockWallpaper $lockWallpaper
            Write-AulaLog -Message "Fondo aplicado al hive descargado de '$userName' ($userSid). Bloqueo de cambios: $lockWallpaper." -Level SUCCESS
        }
        catch {
            Write-AulaLog -Message "No se pudo aplicar la politica al perfil de '$userName' ($userSid): $($_.Exception.Message)" -Level ERROR
        }
        finally {
            if ($hiveLoadedByScript) {
                [GC]::Collect()
                [GC]::WaitForPendingFinalizers()

                $unloadResult = & reg.exe unload "HKU\$mountName" 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-AulaLog -Message "No se pudo descargar el hive temporal '$mountName' para '$userName' ($userSid): codigo $LASTEXITCODE. $unloadResult" -Level ERROR
                }
            }
        }
    }
}

function Invoke-DefaultUserWallpaperPolicy {
    param(
        [Parameter(Mandatory)]
        [string]$WallpaperPath
    )

    $defaultNtUserDat = 'C:\Users\Default\NTUSER.DAT'
    $mountName = 'AulaScriptWallpaper_Default'
    $mountHiveRoot = "Registry::HKEY_USERS\$mountName"
    $hiveLoadedByScript = $false

    Write-AulaLog -Message 'Aplicando fondo al perfil Default para usuarios que aun no iniciaron sesion.' -Level INFO

    if (-not (Test-Path -LiteralPath $defaultNtUserDat)) {
        Write-AulaLog -Message "No se pudo preparar el perfil Default: no existe '$defaultNtUserDat'. Los usuarios sin perfil dependeran solo de Active Setup al iniciar sesion." -Level WARNING
        return $false
    }

    if (Test-Path -LiteralPath $mountHiveRoot) {
        Write-AulaLog -Message "No se pudo cargar el perfil Default: el hive temporal '$mountName' ya esta cargado. Se continua sin fallar el script." -Level WARNING
        return $false
    }

    try {
        $loadResult = & reg.exe load "HKU\$mountName" $defaultNtUserDat 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "reg.exe load fallo con codigo $LASTEXITCODE. $loadResult"
        }

        $hiveLoadedByScript = $true
        Set-WallpaperPolicyInUserHive -HiveRoot $mountHiveRoot -WallpaperPath $WallpaperPath -LockWallpaper $true
        Write-AulaLog -Message "Fondo aplicado al perfil Default. Los nuevos perfiles heredaran el fondo y Active Setup ajustara el bloqueo segun si el usuario es administrador." -Level SUCCESS
        return $true
    }
    catch {
        Write-AulaLog -Message "No se pudo aplicar el fondo al perfil Default: $($_.Exception.Message). Se continua sin fallar el script." -Level WARNING
        return $false
    }
    finally {
        if ($hiveLoadedByScript) {
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()

            $unloadResult = & reg.exe unload "HKU\$mountName" 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-AulaLog -Message "No se pudo descargar el hive temporal '$mountName' para el perfil Default: codigo $LASTEXITCODE. $unloadResult" -Level WARNING
            }
        }
    }
}

if (-not (Test-Path -LiteralPath $sourceImage)) {
    $message = "No se encontro la imagen de fondo requerida: $sourceImage"
    Write-AulaLog -Message $message -Level ERROR
    throw $message
}

Write-AulaLog -Message 'Configurando fondo de escritorio para todos los usuarios y bloqueo para usuarios no administradores.' -Level INFO

New-Item -Path $wallpaperDirectory -ItemType Directory -Force | Out-Null
Copy-Item -LiteralPath $sourceImage -Destination $wallpaperPath -Force -ErrorAction Stop
Write-AulaLog -Message "Imagen copiada a '$wallpaperPath'." -Level SUCCESS

$helperContent = @"
<#
.SYNOPSIS
    Aplica la politica de fondo de escritorio al usuario interactivo actual.
#>

[CmdletBinding()]
param()

`$wallpaperPath = '$($wallpaperPath.Replace("'", "''"))'

function Test-CurrentUserIsAdministrator {
    `$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    `$administratorsSid = 'S-1-5-32-544'

    if (`$identity.Groups | Where-Object { `$_.Value -eq `$administratorsSid }) {
        return `$true
    }

    `$currentSid = `$identity.User.Value
    `$adminSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
    `$adminGroupName = `$adminSid.Translate([Security.Principal.NTAccount]).Value.Split('\')[-1]
    `$adminGroup = [ADSI]"WinNT://`$env:COMPUTERNAME/`$adminGroupName,group"

    foreach (`$member in @(`$adminGroup.psbase.Invoke('Members'))) {
        `$memberSidBytes = `$member.GetType().InvokeMember('objectSid', 'GetProperty', `$null, `$member, `$null)
        `$memberSid = [Security.Principal.SecurityIdentifier]::new(`$memberSidBytes, 0)

        if (`$memberSid.Value -eq `$currentSid) {
            return `$true
        }
    }

    return `$false
}

`$lockWallpaper = -not (Test-CurrentUserIsAdministrator)

`$activeDesktopPolicyPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop'
`$systemPolicyPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System'
`$desktopPath = 'HKCU:\Control Panel\Desktop'

New-Item -Path `$activeDesktopPolicyPath -Force | Out-Null
New-Item -Path `$systemPolicyPath -Force | Out-Null
New-Item -Path `$desktopPath -Force | Out-Null

New-ItemProperty -Path `$desktopPath -Name 'Wallpaper' -PropertyType String -Value `$wallpaperPath -Force | Out-Null
New-ItemProperty -Path `$desktopPath -Name 'WallpaperStyle' -PropertyType String -Value '10' -Force | Out-Null
New-ItemProperty -Path `$desktopPath -Name 'TileWallpaper' -PropertyType String -Value '0' -Force | Out-Null

if (`$lockWallpaper) {
    New-ItemProperty -Path `$activeDesktopPolicyPath -Name 'NoChangingWallPaper' -PropertyType DWord -Value 1 -Force | Out-Null
    New-ItemProperty -Path `$systemPolicyPath -Name 'Wallpaper' -PropertyType String -Value `$wallpaperPath -Force | Out-Null
    New-ItemProperty -Path `$systemPolicyPath -Name 'WallpaperStyle' -PropertyType String -Value '10' -Force | Out-Null
}
else {
    Remove-ItemProperty -Path `$activeDesktopPolicyPath -Name 'NoChangingWallPaper' -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path `$systemPolicyPath -Name 'Wallpaper' -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path `$systemPolicyPath -Name 'WallpaperStyle' -ErrorAction SilentlyContinue
}

try {
    Start-Process -FilePath 'rundll32.exe' -ArgumentList 'user32.dll,UpdatePerUserSystemParameters' -WindowStyle Hidden -ErrorAction Stop | Out-Null
}
catch {
    # La actualizacion visual inmediata es de mejor esfuerzo; la politica queda escrita en el perfil.
}
"@

New-Item -Path $programDataRoot -ItemType Directory -Force | Out-Null
Set-Content -LiteralPath $helperPath -Value $helperContent -Encoding UTF8 -Force
Write-AulaLog -Message "Script auxiliar creado en '$helperPath'." -Level SUCCESS

$stubPath = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $helperPath
New-Item -Path $activeSetupKey -Force | Out-Null
New-ItemProperty -Path $activeSetupKey -Name 'Version' -PropertyType String -Value '1,0' -Force | Out-Null
New-ItemProperty -Path $activeSetupKey -Name 'StubPath' -PropertyType String -Value $stubPath -Force | Out-Null
Write-AulaLog -Message "Active Setup registrado en '$activeSetupKey'." -Level SUCCESS

Invoke-ExistingUserWallpaperPolicy -WallpaperPath $wallpaperPath
$defaultProfileApplied = Invoke-DefaultUserWallpaperPolicy -WallpaperPath $wallpaperPath

if ($defaultProfileApplied) {
    Write-AulaLog -Message 'Perfiles existentes aplicados ahora; los usuarios sin perfil heredaran el fondo desde Default y Active Setup finalizara la politica en el primer inicio de sesion segun si son administradores.' -Level INFO
}
else {
    Write-AulaLog -Message 'Perfiles existentes aplicados ahora. No se pudo actualizar el perfil Default; los usuarios sin perfil dependeran solo de Active Setup en su primer inicio de sesion.' -Level WARNING
}
Write-AulaLog -Message 'La actualizacion visual del escritorio puede requerir cerrar sesion e iniciar sesion nuevamente.' -Level INFO
