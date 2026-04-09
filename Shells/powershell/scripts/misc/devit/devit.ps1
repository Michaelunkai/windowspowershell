<#
.SYNOPSIS
    devit
#>
docker load -i "F:\backup\Containers\developer.tar"
    docker rm -f dotnet-setup 2>$null
    if ($args.Count -gt 0) {
        $envVarPattern = [regex]::Escape('$env:')
        $command = "`$env:PATH += ';C:\Users\ContainerAdministrator\AppData\Local\Microsoft\dotnet'; " + ($args[0] -replace $envVarPattern, '$env:')
        docker run -it -v ${PWD}:C:\workspace -v ${env:USERPROFILE}:C:\host-profile -v F:\:C:\f-drive -w C:\f-drive\downloads --name dotnet-setup developer:latest powershell -NoExit -Command $command
        docker rm -f dotnet-setup
    } else {
        docker run -it -v ${PWD}:C:\workspace -v ${env:USERPROFILE}:C:\host-profile -v F:\:C:\f-drive -w C:\f-drive\downloads --name dotnet-setup developer:latest powershell -NoExit -Command "`$env:PATH += ';C:\Users\ContainerAdministrator\AppData\Local\Microsoft\dotnet'"
        docker rm -f dotnet-setup
    }
