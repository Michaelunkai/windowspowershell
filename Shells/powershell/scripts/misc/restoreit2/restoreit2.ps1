<#
.SYNOPSIS
    restoreit2
#>
cd F:\backup\windowsapps; @('profile','install','installed','Credentials') | ForEach-Object { Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue; git clone "https://codeberg.org/mishaelovsky5/$_.git" }; cd F:\backup\linux; @('wsl') | ForEach-Object { Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue; git clone "https://codeberg.org/mishaelovsky5/$_.git" }; cd F:\; @('study') | ForEach-Object { Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue; git clone "https://codeberg.org/mishaelovsky5/$_.git" }
