<#
.SYNOPSIS
    ccwsl - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
wsl --shutdown; Optimize-VHD -Path "C:\wsl2\ubuntu2\ext4.vhdx" -Mode Full; Optimize-VHD -Path "C:\wsl2\ubuntu2\ext4.vhdx" -Mode Quick; Optimize-VHD -Path "C:\wsl2\ubuntu\ext4.vhdx" -Mode Full; Optimize-VHD -Path "C:\wsl2\ubuntu\ext4.vhdx" -Mode Quick
