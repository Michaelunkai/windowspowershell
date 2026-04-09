<#
.SYNOPSIS
    ddevit
#>
docker load -i "F:\backup\Containers\developer.tar"
    docker rm -f dotnet-setup 2>$null
    docker run -it -d -v ${PWD}:C:\workspace -v ${env:USERPROFILE}:C:\host-profile -v F:\:C:\f-drive -w C:\f-drive\downloads --name dotnet-setup developer:latest powershell
    if ($args.Count -gt 0) {
        $envVarPattern = [regex]::Escape('$env:')
        $command = "`$env:PATH += ';C:\Users\ContainerAdministrator\AppData\Local\Microsoft\dotnet'; " + ($args[0] -replace $envVarPattern, '$env:')
        docker exec dotnet-setup powershell -Command $command
    }
    docker exec -it dotnet-setup powershell -NoExit -Command "`$env:PATH += ';C:\Users\ContainerAdministrator\AppData\Local\Microsoft\dotnet'"
