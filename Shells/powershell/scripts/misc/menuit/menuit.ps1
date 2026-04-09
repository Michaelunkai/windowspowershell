<#
.SYNOPSIS
    menuit
#>
cd F:\GAMES; ls F:\GAMES -Directory | ForEach-Object { menu "$($_.Name)" }
