# Script local para crear usuarios y carpetas personales en D:, si no es USB

# Importar funciones de utilidad
. "$PSScriptRoot\utils.ps1"

# --- FUNCIONES ---

function Ensure-ClassroomUser {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$UserName,
        
        [Parameter(Mandatory=$true)]
        [string]$UsersGroupName
    )

    try {
        Write-AulaLog -Message "Procesando usuario: $UserName" -Level INFO
        
        $existingUser = Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue
        
        if ($existingUser) {
            Write-AulaLog -Message "[OK] El usuario '$UserName' ya existe. Omitiendo creación." -Level SUCCESS
        } else {
            Write-AulaLog -Message "[+] Creando el usuario '$UserName'..." -Level INFO
            $password = ConvertTo-SecureString $UserName -AsPlainText -Force
            
            # El requerimiento indica que NUNCA caduque la contraseña y el usuario PUEDA cambiarla.
            # Por tanto incluyo -AccountNeverExpires y NO incluyo -UserMayNotChangePassword.
            # Añado también -PasswordNeverExpires si es soportado, comúnmente en PowerShell se asume que no caduca con la flag correcta o por defecto en cuentas locales dependiendo de la política, pero explicitly:
            New-LocalUser -Name $UserName -Password $password -PasswordNeverExpires -AccountNeverExpires -ErrorAction Stop | Out-Null
            
            # Asegurar membresía
            Add-LocalGroupMember -Group $UsersGroupName -Member $UserName -ErrorAction Stop
            
            Write-AulaLog -Message "[EXITO] Usuario '$UserName' y su membresía creados correctamente." -Level SUCCESS
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-AulaLog -Message "Error al procesar el usuario '$UserName': $errorMessage" -Level ERROR
    }
}

# --- EJECUCIÓN ---

# Lista fija de usuarios
$usuarios = @("1dam", "2dam", "1daw", "2daw", "1smr", "2smr", "ciber", "35007842")

# Obtener nombres de grupos administradores/usuarios independientes del idioma
$grupo_adminSID = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
$grupo_admin = $grupo_adminSID.Translate([System.Security.Principal.NTAccount]).value.Replace("BUILTIN\", "")
$grupo_usuariosSID = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-545")
$grupo_usuarios = $grupo_usuariosSID.Translate([System.Security.Principal.NTAccount]).value.Replace("BUILTIN\", "")

Write-AulaLog -Message "Iniciando creación de usuarios..." -Level INFO

foreach ($usuario in $usuarios) {
    Ensure-ClassroomUser -UserName $usuario -UsersGroupName $grupo_usuarios
}

# --- CREACION DE CARPETAS PERSONALES (INTERACTIVO CON VALIDACION) ---
Write-Host ""
$driveLetter = $null
while ($true) {
    $driveLetterInput = Read-Host "Introduzca la letra de la unidad para crear las carpetas (Enter para usar 'D', 'no' para omitir)"

    if ($driveLetterInput.ToLower() -eq 'no') {
        $driveLetter = $null
        break
    }

    $driveLetter = if ([string]::IsNullOrWhiteSpace($driveLetterInput)) { "D" } else { $driveLetterInput }

    if (Test-Path -Path "$($driveLetter):") {
        break
    }
    else {
        Write-AulaLog -Message "La unidad '$($driveLetter):' no existe. Por favor, inténtelo de nuevo." -Level WARNING
    }
}

if ($driveLetter) {
    Write-AulaLog -Message "Creando carpetas personales en la unidad $($driveLetter):" -Level INFO
    
    foreach ($usuario in $usuarios) {
        try {
            $carpeta = Join-Path -Path "$($driveLetter):\" -ChildPath $usuario
            
            if (-not (Test-Path $carpeta)) {
                Write-AulaLog -Message "Creando directorio: $carpeta" -Level INFO
                New-Item -Path $carpeta -ItemType Directory -ErrorAction Stop | Out-Null
            }
            else {
                Write-AulaLog -Message "[OK] La carpeta $carpeta ya existe." -Level SUCCESS
            }

            # Establecer permisos: solo el usuario y administradores tienen acceso
            Write-AulaLog -Message "Asignando permisos exclusivos a $usuario en $carpeta" -Level INFO
            
            $acl = Get-Acl -Path $carpeta
            $acl.SetAccessRuleProtection($true, $false) # Deshabilitar herencia

            # Intentar crear la regla para el usuario local
            $ruleUser = New-Object System.Security.AccessControl.FileSystemAccessRule("$env:COMPUTERNAME\$usuario", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
            $acl.AddAccessRule($ruleUser)
            
            $ruleAdmin = New-Object System.Security.AccessControl.FileSystemAccessRule("$grupo_admin", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
            $acl.AddAccessRule($ruleAdmin)
            
            Set-Acl -Path $carpeta -AclObject $acl -ErrorAction Stop
        }
        catch {
            $errorMessage = $_.Exception.Message
            Write-AulaLog -Message "Error configurando la carpeta personal para '$usuario': $errorMessage" -Level ERROR
        }
    }
}
else {
    Write-AulaLog -Message "Creación de carpetas personales omitida por el usuario." -Level WARNING
}
