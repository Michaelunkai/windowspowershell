<#
.SYNOPSIS
    backitup
#>
try {
        # Backup Windows apps
        Set-Location -Path "F:\\backup\windowsapps"
        built michadockermisha/backup:windowsapps
        docker push michadockermisha/backup:windowsapps
        # Backup study folder
        Set-Location -Path "F:\\study"
        docker build -t michadockermisha/backup:study .
        docker push michadockermisha/backup:study
        # Backup WSL
        Set-Location -Path "F:\\backup\linux\wsl"
        built michadockermisha/backup:wsl
        docker push michadockermisha/backup:wsl
        # Stop and remove any running containers to avoid conflicts
        docker stop $(docker ps -a -q) -ErrorAction Continue
        docker rm $(docker ps -a -q) -ErrorAction Continue
        # Clean up unused images to avoid conflicts
        docker rmi $(docker images -q --filter "dangling=true") -ErrorAction Continue
    }
    catch {
        Write-Error "An error occurred during the backup process: $_"
    }
