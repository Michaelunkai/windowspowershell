<#
.SYNOPSIS
    renotes
#>
Get-AppxPackage *SamsungNotes* | Remove-AppxPackage -AllUsers ; Get-AppxPackage *SamsungAccount* | Remove-AppxPackage -AllUsers ; Start-Sleep 5 ; winget install --name "Samsung Notes"   --silent --accept-package-agreements --accept-source-agreements --force ; winget install --name "Samsung Account" --silent --accept-package-agreements --accept-source-agreements --force ; Start-Sleep 10 ; $snPF=(Get-AppxPackage *SamsungNotes*).PackageFamilyName ; Start-Process explorer.exe ("shell:appsFolder\$snPF!App") ; $saPF=(Get-AppxPackage *SamsungAccount*).PackageFamilyName ; Start-Process explorer.exe ("shell:appsFolder\$saPF!App")
