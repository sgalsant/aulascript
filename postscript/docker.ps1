# Este script añade todos los usuarios locales activos (no del sistema) al grupo "docker-users".

$grupo = "docker-users"

# Lista de cuentas del sistema que se deben ignorar
$systemAccounts = @('Administrator', 'Guest', 'DefaultAccount', 'WDAGUtilityAccount')

# Obtener todos los usuarios locales que están habilitados y no son cuentas del sistema
$usuarios = Get-LocalUser | Where-Object { $_.Enabled -and $_.Name -notin $systemAccounts }

Write-Host "Añadiendo usuarios al grupo '$grupo'..."

foreach ($usuario in $usuarios) {
    $userName = $usuario.Name
    # Verificar si el usuario ya es miembro del grupo de una forma más eficiente
    $miembro = Get-LocalGroupMember -Group $grupo -Member $userName -ErrorAction SilentlyContinue

    if (-not $miembro) {
        Write-Host "  - Añadiendo a '$userName'..."
        Add-LocalGroupMember -Group $grupo -Member $userName
    } else {
        Write-Host "  - '$userName' ya es miembro del grupo." -ForegroundColor Gray
    }
}
