# Script local para crear usuarios y carpetas personales en D:, si no es USB

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
        } else {
            Write-Host "El usuario $usuario ya existe"
        }
    } catch {
        Write-Host "Error con el usuario $usuario : $_"
    }
}

  

# Verificar si D: existe y no es USB
$unidadD = Get-PSDrive D -ErrorAction SilentlyContinue
if ($unidadD) {
   
  
   
        foreach ($usuario in $usuarios) {
            $carpeta = "D:\$usuario"
            if (-not (Test-Path $carpeta)) {
                Write-Host "Creando carpeta: $carpeta"
                New-Item -Path $carpeta -ItemType Directory | Out-Null
            } else {
                Write-Host "La carpeta $carpeta ya existe"
            }

            # Establecer permisos: solo el usuario tiene acceso
            Write-Host "Asignando permisos exclusivos a $usuario en $carpeta"
            $acl = New-Object System.Security.AccessControl.DirectorySecurity
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("$env:COMPUTERNAME\$usuario","FullControl","ContainerInherit,ObjectInherit","None","Allow")
            $acl.SetAccessRuleProtection($true, $false)  # Deshabilitar herencia
            $acl.AddAccessRule($rule)

            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("$grupo_admin","FullControl","ContainerInherit,ObjectInherit","None","Allow")
            $acl.AddAccessRule($rule)

            Set-Acl -Path $carpeta -AclObject $acl

        }
 
} else {
    Write-Host "Unidad D: no existe."
}

    Write-Host "Creadas cuentas de usuario. Press any key to close..." -ForegroundColor Cyan
    [void][System.Console]::ReadKey($true)