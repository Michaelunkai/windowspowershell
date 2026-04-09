<#
.SYNOPSIS
    restoreit
#>
cd F:\backup\windowsapps; @('profile','install','installed','Credentials') | ForEach-Object { if (!(Test-Path $_)) { git clone "https://codeberg.org/mishaelovsky5/$_.git" } }; cd F:\backup\linux; @('wsl') | ForEach-Object { if (!(Test-Path $_)) { git clone "https://codeberg.org/mishaelovsky5/$_.git" } }; cd F:\; @('study') | ForEach-Object { if (!(Test-Path $_)) { git clone "https://codeberg.org/mishaelovsky5/$_.git" } }
