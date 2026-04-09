<#
.SYNOPSIS
    dcode
#>
docker run -v "C:/:/c/" -e DISPLAY=$DISPLAY -v "/tmp/.X11-unix:/tmp/.X11-unix" -p 3000:3000 -it --rm --name my_container michadockermisha/backup:python "bash -c 'echo y | code --no-sandbox --user-data-dir=~/vscode-data && bash'"
