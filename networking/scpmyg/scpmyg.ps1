<#
.SYNOPSIS
    scpmyg
#>
Remove-Item -Force -Path "F:\\\study\\Dev_Toolchain\\programming\python\apps\pyqt5menus\GamesDockerMenu\Gui\games_data.json"
Copy-Item -Path "F:\\\study\\Dev_Toolchain\\programming\python\apps\pyqt5menus\GamesDockerMenu\nogui\games_data.json" -Destination "F:\\\study\\Dev_Toolchain\\programming\python\apps\pyqt5menus\GamesDockerMenu\Gui\"
scp F:\\\study\\Dev_Toolchain\\programming\python\apps\pyqt5menus\GamesDockerMenu\nogui\games_data.json ubuntu@192.168.1.193:/home/ubuntu
