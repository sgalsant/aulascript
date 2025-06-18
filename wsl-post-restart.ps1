wsl --set-default-version 2

$repoPath = Join-Path -Path  $PSScriptRoot "repo"

write-host "ruta $repoPath"


wsl --import ubuntu c:/ubuntu $repoPath/ubuntu-24.04.2-wsl-amd64.gz --version 2
  [void][System.Console]::ReadKey($true)