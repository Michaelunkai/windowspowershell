<#
.SYNOPSIS
    stashit
#>
git stash push -m "Auto-stash before pull $(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')"; git pull --rebase=false --no-edit; git stash pop
