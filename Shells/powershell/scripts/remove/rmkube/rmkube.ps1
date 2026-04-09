<#
.SYNOPSIS
    rmkube - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
minikube delete --all --purge; choco uninstall -y kubernetes-cli minikube; [Environment]::SetEnvironmentVariable('MINIKUBE_DRIVER', $null, 'Machine'); Remove-Item -Recurse -Force "$env:USERPROFILE\.kube" -ErrorAction SilentlyContinue; Remove-Item -Recurse -Force "$env:USERPROFILE\.minikube" -ErrorAction SilentlyContinue `
