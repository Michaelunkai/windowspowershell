<#
.SYNOPSIS
    killmacrium
#>
Get-Service | Where-Object { $_.Name -like '*macrium*' } | ForEach-Object {
  try { Stop-Service -Name $_.Name -Force -ErrorAction Stop } catch {
    Get-WmiObject Win32_Service -Filter "Name='$($_.Name)'" | ForEach-Object {
      taskkill /F /PID $_.ProcessId
    }
  }
}; Get-Process | Where-Object { $_.Name -like '*macrium*' } | Stop-Process -Force
