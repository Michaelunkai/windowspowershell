<#
.SYNOPSIS
    docdev
#>
docker load -i "F:\backup\Containers\developer.tar"; if (docker ps -aq -f name=dotnet-setup) { if (docker ps -q -f name=dotnet-setup) { docker exec -it dotnet-setup powershell -NoExit -Command ". 'C:\host-profile\Documents\WindowsPowerShell\M icrosoft.PowerShell_profile.ps1'" } else { docker start dotnet-setup | Out-Null; docker exec -it dotnet-setup powershell -NoExit -Command ". 'C:\host-profile\Documents\WindowsPowerShell\M icrosoft.PowerShell_profile.ps1'" } } else { docker run -d --name dotnet-setup -v ${PWD}:C:\workspace -v ${env:USERPROFILE}:C:\host-profile -v F:\:C:\f-drive -w C:\f-drive\downloads -e IMAGE_INFO="developer:latest" developer:latest powershell -Command "Start-Sleep 31536000"; docker exec -it dotnet-setup powershell -NoExit -Command ". 'C:\host-profile\Documents\WindowsPowerShell\M icrosoft.PowerShell_profile.ps1'" }
