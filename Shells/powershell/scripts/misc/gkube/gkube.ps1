<#
.SYNOPSIS
    gkube
#>
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')); choco install -y kubernetes-cli minikube docker-desktop; [Environment]::SetEnvironmentVariable('MINIKUBE_DRIVER', 'hyperv', 'Machine'); minikube start --driver=hyperv; kubectl config use-context minikube; kubectl cluster-info
