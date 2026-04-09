<#
.SYNOPSIS
    rmkube
#>
minikube delete --all --purge; choco uninstall -y kubernetes-cli minikube; [Environment]::SetEnvironmentVariable('MINIKUBE_DRIVER', $null, 'Machine'); Remove-Item -Recurse -Force "$env:USERPROFILE\.kube" -ErrorAction SilentlyContinue; Remove-Item -Recurse -Force "$env:USERPROFILE\.minikube" -ErrorAction SilentlyContinue `
