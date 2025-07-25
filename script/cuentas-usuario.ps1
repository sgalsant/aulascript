# Script local para crear usuarios y carpetas personales en D:, si no es USB

# Importar funciones de utilidad
. "$PSScriptRoot\utils.ps1"

# Lista fija de usuarios
$usuarios = @("1dam", "2dam", "1daw", "2daw", "1smr", "2smr", "ciber", "35007842")
  
# Crear usuarios locales

#para obtener el nombre del grupo "usuarios" y "administradores" independiente del idioma

$grupo_adminSID = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
$grupo_admin = $grupo_adminSID.Translate([System.Security.Principal.NTAccount]).value.Replace("BUILTIN\", "")
$grupo_usuariosSID = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-545")
$grupo_usuarios = $grupo_usuariosSID.Translate([System.Security.Principal.NTAccount]).value.Replace("BUILTIN\", "")

foreach ($usuario in $usuarios) {
    try {
        if (-not (Get-LocalUser -Name $usuario -ErrorAction SilentlyContinue)) {
            Write-Host "Creando usuario: $usuario"
            $password = ConvertTo-SecureString $usuario -AsPlainText -Force
            New-LocalUser -Name $usuario -Password $password -AccountNeverExpires -UserMayNotChangePassword
            Add-LocalGroupMember -Group $grupo_usuarios -Member $usuario
        }
        else {
            Write-Host "El usuario $usuario ya existe"
        }
    }
    catch {
        Write-Host "Error con el usuario $usuario : $_"
    }
}

# --- CREACION DE CARPETAS PERSONALES (INTERACTIVO CON VALIDACION) ---
Write-Host
$driveLetter = $null
while ($true) {
    $driveLetterInput = Read-Host "Introduzca la letra de la unidad para crear las carpetas (Enter para usar 'D', 'no' para omitir)"

    # Si el usuario escribe 'no', salimos del bucle para omitir la creación
    if ($driveLetterInput.ToLower() -eq 'no') {
        $driveLetter = $null
        break
    }

    # Determinar la letra de unidad a usar (la introducida o 'D' por defecto)
    $driveLetter = if ([string]::IsNullOrWhiteSpace($driveLetterInput)) { "D" } else { $driveLetterInput }

    # Validar que la unidad existe. Si existe, salimos del bucle para continuar.
    if (Test-Path -Path "$($driveLetter):") {
        break
    }
    else {
        Write-Warning "La unidad '$($driveLetter):' no existe. Por favor, inténtelo de nuevo."
    }
}

# Si se ha seleccionado una unidad válida, procedemos a crear las carpetas
if ($driveLetter) {
    Write-Host "`nCreando carpetas en la unidad $($driveLetter):" -ForegroundColor Cyan
    foreach ($usuario in $usuarios) {
        $carpeta = Join-Path -Path "$($driveLetter):\" -ChildPath $usuario
        if (-not (Test-Path $carpeta)) {
            Write-Host "Creando carpeta: $carpeta"
            New-Item -Path $carpeta -ItemType Directory | Out-Null
        }
        else {
            Write-Host "La carpeta $carpeta ya existe"
        }

        # Establecer permisos: solo el usuario y administradores tienen acceso
        Write-Host "Asignando permisos exclusivos a $usuario en $carpeta"
        $acl = New-Object System.Security.AccessControl.DirectorySecurity
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("$env:COMPUTERNAME\$usuario", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
        $acl.SetAccessRuleProtection($true, $false) # Deshabilitar herencia
        $acl.AddAccessRule($rule)
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("$grupo_admin", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
        $acl.AddAccessRule($rule)
        Set-Acl -Path $carpeta -AclObject $acl
    }
}
else {
    Write-Warning "Creación de carpetas personales omitida por el usuario."
}

