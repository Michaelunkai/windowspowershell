<#
.SYNOPSIS
    compilenet
#>
if ($args.Count -gt 0) {
        $path = $args[0]
        # Convert Windows path to container path if needed
        if ($path.StartsWith("F:\")) {
            $containerPath = $path -replace "F:\\", "C:\f-drive\"
        } else {
            $containerPath = $path
        }
        devit "cd '$containerPath'; dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:PublishTrimmed=true -o bin\Release\Publish"
    } else {
        Write-Host "Usage: compilenet [project-path]"
        Write-Host "Example: compilenet F:\Downloads\uninstellerInDotnet\EnhancedUninstaller"
    }
