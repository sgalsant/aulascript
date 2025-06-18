# Lista de usuarios a añadir al grupo "docker-users"
$usuarios = @("1dam", "2dam", "1daw", "2daw", "1smr", "2smr", "ciber", "35007842")
$grupo = "docker-users"

foreach ($usuario in $usuarios) {
    # Verificar si el usuario existe
    if (Get-LocalUser -Name $usuario -ErrorAction SilentlyContinue) {
        # Verificar si el usuario ya pertenece al grupo
        $miembro = Get-LocalGroupMember -Group $grupo -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $usuario }

        if (-not $miembro) {
            Write-Host "Añadiendo $usuario al grupo $grupo..."
            net localgroup $grupo $usuario /add | Out-Null
        } else {
            Write-Host "$usuario ya es miembro del grupo $grupo. No se añade."
        }
    } else {
        Write-Host "El usuario $usuario no existe. No se añade."
    }
}
