<#
.SYNOPSIS
    getph
#>
$cs = Get-WmiObject -Class Win32_ComputerSystem -EnableAllPrivileges; $cs.AutomaticManagedPagefile = $true; $cs.Put()
