# wsl

 Enable-windowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart

 Enable-windowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart

 # los siguientes pasos se deben hacer tras reiniciar windows
# wsl --set-default-version 2

# $parentDir = Split-Path -Path $PSScriptRoot -Parent
# $repoPath = Join-Path -Path $parentDir -ChildPath "repo"


# wsl --import ubuntu c:/ubuntu $repoPath/ubuntu-24.04.2-wsl-amd64.gz --version 2
