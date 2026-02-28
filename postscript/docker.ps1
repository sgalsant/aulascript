# Este script añade todos los usuarios locales activos (no del sistema) al grupo "docker-users".

. "$PSScriptRoot\..\script\utils.ps1"

$grupo = "docker-users"

# Lista de cuentas del sistema que se deben ignorar
$systemAccounts = @('Administrator', 'Guest', 'DefaultAccount', 'WDAGUtilityAccount')

try {
    # Obtener todos los usuarios locales que están habilitados y no son cuentas del sistema
    $usuarios = Get-LocalUser -ErrorAction Stop | Where-Object { $_.Enabled -and $_.Name -notin $systemAccounts }

    Write-AulaLog -Message "Añadiendo usuarios al grupo '$grupo'..." -Level INFO

    foreach ($usuario in $usuarios) {
        $userName = $usuario.Name
        # Verificar si el usuario ya es miembro del grupo de una forma más eficiente
        $miembro = Get-LocalGroupMember -Group $grupo -Member $userName -ErrorAction SilentlyContinue

        if (-not $miembro) {
            Write-AulaLog -Message "Añadiendo a '$userName' al grupo $grupo..." -Level INFO
            Add-LocalGroupMember -Group $grupo -Member $userName -ErrorAction Stop
        } else {
            Write-AulaLog -Message "'$userName' ya es miembro del grupo $grupo." -Level SUCCESS
        }
    }
} catch {
    $errorMessage = $_.Exception.Message
    Write-AulaLog -Message "Error CRÍTICO al procesar el grupo '$grupo': $errorMessage" -Level ERROR
}
