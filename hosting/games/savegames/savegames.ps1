<#
.SYNOPSIS
    savegames
#>
Set-Location -Path "F:\backup\gamesaves"
    # Build Dockerfile
    @"
# Use a base image
FROM alpine:latest
# Install rsync
RUN apk --no-cache add rsync
# Set the working directory
WORKDIR /app
# Copy everything within the current path to /home/
COPY . /home/
# Default runtime options
CMD ["rsync", "-aP", "/home/", "/home/"]
"@ | Set-Content -Path Dockerfile
    # Run backup container
    drun gamesdata michadockermisha/backup:gamesaves "sh -c 'apk add rsync && rsync -aP /home/* /c/backup/gamesaves && exit'"
    # Build and push image
    built michadockermisha/backup:gamesaves
    docker push michadockermisha/backup:gamesaves
    # Clean up folder
    Remove-Item -Recurse -Force .\*
