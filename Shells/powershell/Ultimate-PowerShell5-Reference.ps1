<#
═══════════════════════════════════════════════════════════════════════════════
    ULTIMATE POWERSHELL 5 REFERENCE - COMPREHENSIVE COMMAND COLLECTION
    Created: 2026-03-11
    PowerShell Version: 5.x
    Total Commands: 800+
    Category: Complete Windows Administration & Automation Reference
═══════════════════════════════════════════════════════════════════════════════
#>

#region SYSTEM INFORMATION
#═══════════════════════════════════════════════════════════════════════════════

# Get Computer Info
Get-ComputerInfo
Get-ComputerInfo | Select-Object CsName, WindowsVersion, OsArchitecture
Get-WmiObject Win32_ComputerSystem
Get-WmiObject Win32_OperatingSystem
Get-CimInstance Win32_OperatingSystem

# System Details
[System.Environment]::OSVersion
$PSVersionTable
$PSVersionTable.PSVersion
Get-Host
$env:COMPUTERNAME
$env:USERNAME
$env:USERDOMAIN
hostname
systeminfo
systeminfo | findstr /C:"OS Name" /C:"OS Version"

# Hardware Info
Get-WmiObject Win32_Processor
Get-WmiObject Win32_PhysicalMemory
Get-WmiObject Win32_BaseBoard
Get-WmiObject Win32_BIOS
Get-WmiObject Win32_ComputerSystem | Select-Object Manufacturer, Model
Get-CimInstance Win32_VideoController
Get-WmiObject Win32_DiskDrive

# CPU Information
Get-WmiObject Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors
(Get-WmiObject Win32_Processor).LoadPercentage

# Memory Information
Get-WmiObject Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
[Math]::Round((Get-WmiObject Win32_OperatingSystem).FreePhysicalMemory/1MB,2)
Get-Counter '\Memory\Available MBytes'

# Uptime
(Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
Get-Uptime

# Time & Date
Get-Date
Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Get-TimeZone
Set-TimeZone -Name "GMT Standard Time"
w32tm /query /status

#endregion

#region FILE & FOLDER OPERATIONS
#═══════════════════════════════════════════════════════════════════════════════

# Navigation
Get-Location
Set-Location C:\
Push-Location C:\Temp
Pop-Location
cd ..
pwd

# List Files & Folders
Get-ChildItem
Get-ChildItem -Path C:\ -Recurse
Get-ChildItem -File
Get-ChildItem -Directory
Get-ChildItem -Hidden
Get-ChildItem -Force
Get-ChildItem -Filter *.txt
Get-ChildItem -Include *.log -Recurse
Get-ChildItem -Exclude *.tmp
dir
ls

# File Operations
New-Item -Path "C:\Temp\file.txt" -ItemType File
New-Item -ItemType Directory -Path "C:\Temp\NewFolder"
Copy-Item -Path "source.txt" -Destination "dest.txt"
Copy-Item -Path "C:\Source\*" -Destination "C:\Dest" -Recurse
Move-Item -Path "old.txt" -Destination "new.txt"
Rename-Item -Path "old.txt" -NewName "new.txt"
Remove-Item -Path "file.txt"
Remove-Item -Path "C:\Folder" -Recurse -Force

# File Content
Get-Content "file.txt"
Get-Content "file.txt" -Head 10
Get-Content "file.txt" -Tail 20
Set-Content -Path "file.txt" -Value "New content"
Add-Content -Path "log.txt" -Value "New log entry"
Clear-Content -Path "file.txt"
Out-File -FilePath "output.txt" -InputObject $data

# File Properties
Get-Item "file.txt"
Get-ItemProperty "file.txt"
Set-ItemProperty -Path "file.txt" -Name IsReadOnly -Value $true
Test-Path "C:\file.txt"
Test-Path "C:\folder" -PathType Container

# File Attributes
(Get-Item "file.txt").Attributes
(Get-Item "file.txt").CreationTime
(Get-Item "file.txt").LastWriteTime
(Get-Item "file.txt").LastAccessTime
(Get-Item "file.txt").Length

# Search Files
Get-ChildItem -Path C:\ -Recurse -Filter *.log
Get-ChildItem -Path C:\ -Recurse | Where-Object {$_.Length -gt 100MB}
Get-ChildItem | Where-Object {$_.LastWriteTime -gt (Get-Date).AddDays(-7)}
Select-String -Path "*.txt" -Pattern "error"

# File Hashing
Get-FileHash "file.txt"
Get-FileHash "file.txt" -Algorithm SHA256
Get-FileHash "file.txt" -Algorithm MD5

# Compress & Extract
Compress-Archive -Path "C:\Source\*" -DestinationPath "archive.zip"
Expand-Archive -Path "archive.zip" -DestinationPath "C:\Dest"

#endregion

#region PROCESS MANAGEMENT
#═══════════════════════════════════════════════════════════════════════════════

# List Processes
Get-Process
Get-Process | Sort-Object CPU -Descending
Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10
Get-Process -Name chrome
Get-Process | Where-Object {$_.CPU -gt 100}
ps

# Start & Stop Processes
Start-Process notepad
Start-Process "C:\Program.exe" -ArgumentList "/arg1"
Start-Process powershell -Verb RunAs
Stop-Process -Name notepad
Stop-Process -Id 1234
Stop-Process -Name chrome -Force
kill 1234

# Process Details
Get-Process | Select-Object Name, Id, CPU, WorkingSet
(Get-Process -Name chrome).Path
(Get-Process -Id 1234).StartTime
Get-Process | Measure-Object WorkingSet -Sum

# Wait for Process
Wait-Process -Name notepad
Start-Process notepad -Wait

#endregion

#region SERVICE MANAGEMENT
#═══════════════════════════════════════════════════════════════════════════════

# List Services
Get-Service
Get-Service | Where-Object {$_.Status -eq "Running"}
Get-Service | Where-Object {$_.Status -eq "Stopped"}
Get-Service -Name wuauserv
Get-Service | Sort-Object DisplayName

# Service Operations
Start-Service -Name wuauserv
Stop-Service -Name wuauserv
Restart-Service -Name wuauserv
Suspend-Service -Name wuauserv
Resume-Service -Name wuauserv
Set-Service -Name wuauserv -StartupType Automatic
Set-Service -Name wuauserv -StartupType Disabled

# Service Details
Get-Service -Name wuauserv | Select-Object *
(Get-Service -Name wuauserv).DependentServices
Get-Service -Name wuauserv | Format-List *

# Create & Remove Services
New-Service -Name "MyService" -BinaryPathName "C:\Service.exe"
Remove-Service -Name "MyService"

#endregion

#region NETWORK OPERATIONS
#═══════════════════════════════════════════════════════════════════════════════

# Network Adapters
Get-NetAdapter
Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
Get-NetAdapterStatistics
Disable-NetAdapter -Name "Ethernet"
Enable-NetAdapter -Name "Ethernet"
Restart-NetAdapter -Name "Ethernet"

# IP Configuration
Get-NetIPAddress
Get-NetIPAddress -InterfaceAlias "Ethernet"
Get-NetIPAddress -AddressFamily IPv4
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress "192.168.1.10" -PrefixLength 24 -DefaultGateway "192.168.1.1"
Remove-NetIPAddress -IPAddress "192.168.1.10"
Set-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress "192.168.1.11"

# DNS Configuration
Get-DnsClientServerAddress
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses ("8.8.8.8","8.8.4.4")
Clear-DnsClientCache
Get-DnsClientCache
Resolve-DnsName google.com
nslookup google.com

# Network Testing
Test-Connection google.com
Test-Connection -ComputerName google.com -Count 4
ping google.com
Test-NetConnection google.com
Test-NetConnection google.com -Port 80
Test-NetConnection -ComputerName google.com -TraceRoute

# Network Routes
Get-NetRoute
Get-NetRoute -AddressFamily IPv4
New-NetRoute -DestinationPrefix "192.168.2.0/24" -NextHop "192.168.1.1" -InterfaceAlias "Ethernet"
Remove-NetRoute -DestinationPrefix "192.168.2.0/24"

# Firewall
Get-NetFirewallProfile
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
Get-NetFirewallRule
Get-NetFirewallRule | Where-Object {$_.Enabled -eq "True"}
New-NetFirewallRule -DisplayName "Allow Port 8080" -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow
Remove-NetFirewallRule -DisplayName "Allow Port 8080"
Disable-NetFirewallRule -DisplayName "Rule Name"
Enable-NetFirewallRule -DisplayName "Rule Name"

# Network Shares
Get-SmbShare
New-SmbShare -Name "Share" -Path "C:\Share" -FullAccess "Everyone"
Remove-SmbShare -Name "Share"
Get-SmbConnection
Get-SmbMapping

# Network Statistics
Get-NetTCPConnection
Get-NetTCPConnection -State Established
Get-NetTCPConnection -LocalPort 80
netstat -an
netstat -ano | findstr :80

#endregion

#region USER & GROUP MANAGEMENT
#═══════════════════════════════════════════════════════════════════════════════

# Local Users
Get-LocalUser
Get-LocalUser -Name "Administrator"
New-LocalUser -Name "TestUser" -Password (ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force)
Remove-LocalUser -Name "TestUser"
Set-LocalUser -Name "TestUser" -Description "Test Account"
Disable-LocalUser -Name "TestUser"
Enable-LocalUser -Name "TestUser"
Rename-LocalUser -Name "OldName" -NewName "NewName"

# Local Groups
Get-LocalGroup
Get-LocalGroup -Name "Administrators"
New-LocalGroup -Name "TestGroup" -Description "Test"
Remove-LocalGroup -Name "TestGroup"
Add-LocalGroupMember -Group "Administrators" -Member "TestUser"
Remove-LocalGroupMember -Group "Administrators" -Member "TestUser"
Get-LocalGroupMember -Group "Administrators"

# User Session
whoami
whoami /all
whoami /groups
whoami /priv
query user
quser

#endregion

#region DISK & STORAGE OPERATIONS
#═══════════════════════════════════════════════════════════════════════════════

# Disk Information
Get-PSDrive
Get-PSDrive -PSProvider FileSystem
Get-Volume
Get-Disk
Get-PhysicalDisk
Get-Partition

# Disk Space
Get-PSDrive C | Select-Object Used,Free
Get-Volume | Select-Object DriveLetter, FileSystem, SizeRemaining, Size
[Math]::Round((Get-Volume -DriveLetter C).SizeRemaining / 1GB, 2)

# Disk Operations
Initialize-Disk -Number 1
New-Partition -DiskNumber 1 -UseMaximumSize -AssignDriveLetter
Format-Volume -DriveLetter E -FileSystem NTFS -NewFileSystemLabel "Data"
Set-Volume -DriveLetter C -NewFileSystemLabel "System"

# Disk Optimization
Optimize-Volume -DriveLetter C -Analyze
Optimize-Volume -DriveLetter C -Defrag
Optimize-Volume -DriveLetter C -ReTrim

# Storage Spaces
Get-StoragePool
New-StoragePool -FriendlyName "MyPool" -StorageSubSystemFriendlyName "Storage Spaces*" -PhysicalDisks (Get-PhysicalDisk -CanPool $true)
New-VirtualDisk -StoragePoolFriendlyName "MyPool" -FriendlyName "VDisk1" -Size 500GB

#endregion

#region REGISTRY OPERATIONS
#═══════════════════════════════════════════════════════════════════════════════

# Navigate Registry
Get-ChildItem HKLM:\
Get-ChildItem HKCU:\
Set-Location HKLM:\Software

# Registry Keys
Get-Item "HKLM:\Software\Microsoft\Windows\CurrentVersion"
Test-Path "HKLM:\Software\MyApp"
New-Item -Path "HKLM:\Software\MyApp"
Remove-Item -Path "HKLM:\Software\MyApp" -Recurse
Rename-Item -Path "HKLM:\Software\OldName" -NewName "NewName"

# Registry Values
Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion" -Name "ProgramFilesDir"
Set-ItemProperty -Path "HKLM:\Software\MyApp" -Name "Version" -Value "1.0"
New-ItemProperty -Path "HKLM:\Software\MyApp" -Name "Setting" -Value "Value" -PropertyType String
Remove-ItemProperty -Path "HKLM:\Software\MyApp" -Name "Setting"

# Registry Export/Import
reg export "HKLM\Software\MyApp" "C:\backup.reg"
reg import "C:\backup.reg"

#endregion

#region WINDOWS FEATURES & UPDATES
#═══════════════════════════════════════════════════════════════════════════════

# Windows Features
Get-WindowsOptionalFeature -Online
Get-WindowsOptionalFeature -Online | Where-Object {$_.State -eq "Enabled"}
Enable-WindowsOptionalFeature -Online -FeatureName "TelnetClient"
Disable-WindowsOptionalFeature -Online -FeatureName "TelnetClient"
DISM /Online /Get-Features
DISM /Online /Enable-Feature /FeatureName:TelnetClient

# Windows Updates
Get-WindowsUpdate
Install-WindowsUpdate -AcceptAll -AutoReboot
Get-WUHistory
Get-WULastResults
wuauclt /detectnow

# Windows Capability
Get-WindowsCapability -Online
Add-WindowsCapability -Online -Name "OpenSSH.Client~~~~0.0.1.0"
Remove-WindowsCapability -Online -Name "OpenSSH.Client~~~~0.0.1.0"

# Windows Packages
Get-AppxPackage
Get-AppxPackage -AllUsers
Get-AppxPackage -Name "*store*"
Remove-AppxPackage -Package "PackageName"
Add-AppxPackage -Path "C:\package.appx"

#endregion

#region EVENT LOG MANAGEMENT
#═══════════════════════════════════════════════════════════════════════════════

# View Event Logs
Get-EventLog -LogName System -Newest 100
Get-EventLog -LogName Application -EntryType Error
Get-EventLog -LogName Security -After (Get-Date).AddHours(-24)
Get-WinEvent -LogName System -MaxEvents 100
Get-WinEvent -FilterHashtable @{LogName='System'; Level=2}

# Event Log Details
Get-EventLog -List
Get-WinEvent -ListLog *
Limit-EventLog -LogName Application -MaximumSize 512MB

# Clear Event Logs
Clear-EventLog -LogName Application
wevtutil cl System
wevtutil cl Application

# Export Event Logs
wevtutil epl System C:\system.evtx

#endregion

#region SCHEDULED TASKS
#═══════════════════════════════════════════════════════════════════════════════

# List Scheduled Tasks
Get-ScheduledTask
Get-ScheduledTask | Where-Object {$_.State -eq "Ready"}
Get-ScheduledTask -TaskName "TaskName"
Get-ScheduledTask -TaskPath "\Microsoft\Windows\*"

# Create Scheduled Task
$action = New-ScheduledTaskAction -Execute "notepad.exe"
$trigger = New-ScheduledTaskTrigger -Daily -At 9am
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "MyTask"

# Manage Scheduled Tasks
Start-ScheduledTask -TaskName "MyTask"
Stop-ScheduledTask -TaskName "MyTask"
Disable-ScheduledTask -TaskName "MyTask"
Enable-ScheduledTask -TaskName "MyTask"
Unregister-ScheduledTask -TaskName "MyTask" -Confirm:$false

# Task Details
Get-ScheduledTaskInfo -TaskName "MyTask"
Export-ScheduledTask -TaskName "MyTask" | Out-File "C:\task.xml"
Register-ScheduledTask -Xml (Get-Content "C:\task.xml" | Out-String) -TaskName "RestoredTask"

#endregion

#region PERFORMANCE MONITORING
#═══════════════════════════════════════════════════════════════════════════════

# Performance Counters
Get-Counter
Get-Counter -ListSet *
Get-Counter '\Processor(_Total)\% Processor Time'
Get-Counter '\Memory\Available MBytes'
Get-Counter '\PhysicalDisk(_Total)\Disk Reads/sec'
Get-Counter '\Network Interface(*)\Bytes Total/sec'

# Continuous Monitoring
Get-Counter '\Processor(_Total)\% Processor Time' -Continuous
Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 2 -MaxSamples 10

# Multiple Counters
Get-Counter -Counter @('\Processor(_Total)\% Processor Time', '\Memory\Available MBytes')

#endregion

#region SYSTEM ADMINISTRATION
#═══════════════════════════════════════════════════════════════════════════════

# System Shutdown & Restart
Stop-Computer
Stop-Computer -Force
Restart-Computer
Restart-Computer -Force
shutdown /s /t 0
shutdown /r /t 0
shutdown /a

# Hibernate & Sleep
shutdown /h
rundll32.exe powrprof.dll,SetSuspendState 0,1,0

# Environment Variables
Get-ChildItem Env:
$env:PATH
$env:TEMP
[Environment]::SetEnvironmentVariable("VAR", "Value", "User")
[Environment]::SetEnvironmentVariable("VAR", "Value", "Machine")

# System Configuration
msconfig
services.msc
compmgmt.msc
devmgmt.msc
diskmgmt.msc

#endregion

#region REMOTE MANAGEMENT
#═══════════════════════════════════════════════════════════════════════════════

# PowerShell Remoting
Enable-PSRemoting -Force
Disable-PSRemoting -Force
Test-WSMan -ComputerName "Server01"
Enter-PSSession -ComputerName "Server01"
Exit-PSSession

# Remote Commands
Invoke-Command -ComputerName "Server01" -ScriptBlock { Get-Process }
Invoke-Command -ComputerName "Server01" -FilePath "C:\script.ps1"
Invoke-Command -ComputerName Server01,Server02 -ScriptBlock { Get-Service }

# Remote Sessions
$session = New-PSSession -ComputerName "Server01"
Invoke-Command -Session $session -ScriptBlock { Get-Process }
Remove-PSSession -Session $session
Get-PSSession
Disconnect-PSSession -Session $session
Connect-PSSession -Session $session

# WinRM Configuration
Get-Item WSMan:\localhost\Client\TrustedHosts
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*"
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "Server01,Server02"
winrm quickconfig

#endregion

#region SECURITY OPERATIONS
#═══════════════════════════════════════════════════════════════════════════════

# Windows Defender
Get-MpComputerStatus
Get-MpPreference
Update-MpSignature
Start-MpScan -ScanType QuickScan
Start-MpScan -ScanType FullScan
Set-MpPreference -DisableRealtimeMonitoring $true
Add-MpPreference -ExclusionPath "C:\Safe\Folder"
Remove-MpPreference -ExclusionPath "C:\Safe\Folder"

# Execution Policy
Get-ExecutionPolicy
Set-ExecutionPolicy RemoteSigned
Set-ExecutionPolicy Bypass -Scope Process
Set-ExecutionPolicy Unrestricted -Force

# Certificates
Get-ChildItem Cert:\LocalMachine\My
Get-ChildItem Cert:\CurrentUser\My
Export-Certificate -Cert $cert -FilePath "C:\cert.cer"
Import-Certificate -FilePath "C:\cert.cer" -CertStoreLocation Cert:\LocalMachine\Root

# Credentials
$cred = Get-Credential
$securePassword = ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ("Username", $securePassword)

# Bitlocker
Get-BitLockerVolume
Enable-BitLocker -MountPoint "C:" -EncryptionMethod Aes256 -Password (ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force)
Disable-BitLocker -MountPoint "C:"
Unlock-BitLocker -MountPoint "C:" -Password (ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force)

#endregion

#region ACTIVE DIRECTORY (Requires AD Module)
#═══════════════════════════════════════════════════════════════════════════════

# Import Module
Import-Module ActiveDirectory

# Get AD Objects
Get-ADUser -Filter *
Get-ADUser -Identity "username"
Get-ADUser -Filter {Enabled -eq $true}
Get-ADGroup -Filter *
Get-ADComputer -Filter *
Get-ADOrganizationalUnit -Filter *

# Create AD Objects
New-ADUser -Name "John Doe" -GivenName "John" -Surname "Doe" -SamAccountName "jdoe" -UserPrincipalName "jdoe@domain.com"
New-ADGroup -Name "TestGroup" -GroupScope Global
New-ADOrganizationalUnit -Name "TestOU" -Path "DC=domain,DC=com"

# Modify AD Objects
Set-ADUser -Identity "jdoe" -Description "Test User"
Add-ADGroupMember -Identity "TestGroup" -Members "jdoe"
Remove-ADGroupMember -Identity "TestGroup" -Members "jdoe"

# Remove AD Objects
Remove-ADUser -Identity "jdoe"
Remove-ADGroup -Identity "TestGroup"

#endregion

#region STRING & TEXT OPERATIONS
#═══════════════════════════════════════════════════════════════════════════════

# String Methods
"Hello World".ToUpper()
"Hello World".ToLower()
"Hello World".Replace("World", "PowerShell")
"Hello World".Contains("World")
"Hello World".StartsWith("Hello")
"Hello World".EndsWith("World")
"Hello World".Substring(0, 5)
"Hello World".Split(" ")
"Hello,World,PowerShell".Split(",")
"  Hello  ".Trim()
"Hello" + " " + "World"

# String Comparison
"Hello" -eq "Hello"
"Hello" -ne "World"
"Hello" -like "H*"
"Hello" -match "^H"
"Hello" -contains "e"

# Format Strings
"{0} {1}" -f "Hello", "World"
"Value: {0:N2}" -f 123.456

#endregion

#region ARRAY & COLLECTION OPERATIONS
#═══════════════════════════════════════════════════════════════════════════════

# Arrays
$array = @(1, 2, 3, 4, 5)
$array[0]
$array[-1]
$array.Count
$array.Length
$array += 6
$array | ForEach-Object { $_ * 2 }
$array | Where-Object { $_ -gt 2 }
$array | Sort-Object
$array | Sort-Object -Descending
$array | Measure-Object -Sum -Average -Maximum -Minimum

# Array Operations
$array -contains 3
$array -join ","
@(1,2,3) + @(4,5,6)
1..10
1..10 | ForEach-Object { $_ * 2 }

# ArrayList
$arrayList = New-Object System.Collections.ArrayList
$arrayList.Add("Item1")
$arrayList.Remove("Item1")
$arrayList.Clear()

# HashTable
$hash = @{}
$hash = @{Key1="Value1"; Key2="Value2"}
$hash["Key1"]
$hash.Key1
$hash.Add("Key3", "Value3")
$hash.Remove("Key1")
$hash.Keys
$hash.Values
$hash.ContainsKey("Key1")

#endregion

#region LOOP & CONDITIONAL STRUCTURES
#═══════════════════════════════════════════════════════════════════════════════

# For Loop
for ($i = 0; $i -lt 10; $i++) {
    Write-Host $i
}

# ForEach Loop
foreach ($item in $collection) {
    Write-Host $item
}

# ForEach-Object (Pipeline)
1..10 | ForEach-Object { Write-Host $_ }
Get-Process | ForEach-Object { $_.Name }

# While Loop
while ($condition) {
    # code
}

# Do-While
do {
    # code
} while ($condition)

# Do-Until
do {
    # code
} until ($condition)

# If-Else
if ($condition) {
    # code
} elseif ($condition2) {
    # code
} else {
    # code
}

# Switch
switch ($value) {
    1 { "One" }
    2 { "Two" }
    default { "Other" }
}

# Try-Catch
try {
    # code
} catch {
    Write-Error $_.Exception.Message
} finally {
    # cleanup
}

#endregion

#region OUTPUT & FORMATTING
#═══════════════════════════════════════════════════════════════════════════════

# Write Output
Write-Output "Message"
Write-Host "Message"
Write-Host "Message" -ForegroundColor Green
Write-Host "Message" -BackgroundColor Red
Write-Verbose "Verbose message" -Verbose
Write-Warning "Warning message"
Write-Error "Error message"
Write-Debug "Debug message" -Debug

# Formatting
Get-Process | Format-Table
Get-Process | Format-Table -AutoSize
Get-Process | Format-Table Name, Id, CPU
Get-Process | Format-List
Get-Process | Format-List *
Get-Process | Format-Wide
Get-Process | Out-GridView

# Export Data
Get-Process | Export-Csv "processes.csv"
Get-Process | Export-Csv "processes.csv" -NoTypeInformation
Import-Csv "processes.csv"
Get-Process | ConvertTo-Json
Get-Process | ConvertTo-Html | Out-File "processes.html"
Get-Process | ConvertTo-Xml

#endregion

#region VARIABLES & DATA TYPES
#═══════════════════════════════════════════════════════════════════════════════

# Variables
$variable = "Value"
$number = 123
$decimal = 123.45
$boolean = $true
$null = $null

# Data Types
[string]$string = "Text"
[int]$integer = 123
[double]$double = 123.45
[bool]$boolean = $true
[datetime]$date = Get-Date
[array]$array = @(1,2,3)
[hashtable]$hash = @{}

# Type Checking
$variable.GetType()
$variable -is [string]
$variable -isnot [int]

# Type Conversion
[int]"123"
[string]123
[datetime]"2024-01-01"

# Variable Scope
$global:var = "Global"
$script:var = "Script"
$local:var = "Local"

# Constants
Set-Variable -Name "Constant" -Value "Value" -Option Constant
New-Variable -Name "ReadOnly" -Value "Value" -Option ReadOnly

# Automatic Variables
$PSVersionTable
$HOME
$PROFILE
$pwd
$_
$args
$error
$host

#endregion

#region FUNCTIONS & MODULES
#═══════════════════════════════════════════════════════════════════════════════

# Define Function
function Get-CustomInfo {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    Write-Output "Hello, $Name"
}

# Advanced Function
function Get-AdvancedInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$Name,
        
        [Parameter()]
        [switch]$Detailed
    )
    
    process {
        if ($Detailed) {
            Write-Output "Detailed info for $Name"
        } else {
            Write-Output "Basic info for $Name"
        }
    }
}

# Modules
Get-Module
Get-Module -ListAvailable
Import-Module ModuleName
Remove-Module ModuleName
New-ModuleManifest -Path "Module.psd1"

# Module Paths
$env:PSModulePath
$env:PSModulePath -split ";"

#endregion

#region WMI & CIM OPERATIONS
#═══════════════════════════════════════════════════════════════════════════════

# WMI Queries
Get-WmiObject Win32_ComputerSystem
Get-WmiObject Win32_OperatingSystem
Get-WmiObject Win32_LogicalDisk
Get-WmiObject Win32_NetworkAdapter
Get-WmiObject Win32_Service
Get-WmiObject -Class Win32_Process -Filter "Name='notepad.exe'"
Get-WmiObject -Query "SELECT * FROM Win32_Service WHERE State='Running'"

# CIM Queries
Get-CimInstance Win32_ComputerSystem
Get-CimInstance Win32_OperatingSystem
Get-CimInstance Win32_Service
Get-CimClass -ClassName Win32_*
Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine="notepad.exe"}

# WMI Methods
(Get-WmiObject Win32_Service -Filter "Name='wuauserv'").StartService()
(Get-WmiObject Win32_Service -Filter "Name='wuauserv'").StopService()

#endregion

#region JOBS & BACKGROUND TASKS
#═══════════════════════════════════════════════════════════════════════════════

# Background Jobs
Start-Job -ScriptBlock { Get-Process }
Start-Job -FilePath "C:\script.ps1"
Get-Job
Receive-Job -Id 1
Remove-Job -Id 1
Stop-Job -Id 1
Wait-Job -Id 1

# Job Details
Get-Job | Select-Object Id, State, HasMoreData
(Get-Job -Id 1).State

#endregion

#region ERROR HANDLING & DEBUGGING
#═══════════════════════════════════════════════════════════════════════════════

# Error Handling
try {
    Get-Item "C:\NonExistent.txt" -ErrorAction Stop
} catch {
    Write-Host "Error: $($_.Exception.Message)"
}

# Error Actions
Get-Process -Name "NonExistent" -ErrorAction SilentlyContinue
Get-Process -Name "NonExistent" -ErrorAction Stop
Get-Process -Name "NonExistent" -ErrorAction Continue
Get-Process -Name "NonExistent" -ErrorAction Inquire

# Error Variables
$Error
$Error[0]
$Error.Clear()
$?
$LASTEXITCODE

# Debugging
Set-PSBreakpoint -Script "script.ps1" -Line 10
Get-PSBreakpoint
Remove-PSBreakpoint -Id 1
Set-PSDebug -Trace 1
Set-PSDebug -Off

#endregion

#region POWERSHELL PROFILES
#═══════════════════════════════════════════════════════════════════════════════

# Profile Paths
$PROFILE
$PROFILE.AllUsersAllHosts
$PROFILE.AllUsersCurrentHost
$PROFILE.CurrentUserAllHosts
$PROFILE.CurrentUserCurrentHost

# Create/Edit Profile
if (!(Test-Path $PROFILE)) {
    New-Item -Path $PROFILE -ItemType File -Force
}
notepad $PROFILE
code $PROFILE

#endregion

#region ALIASES
#═══════════════════════════════════════════════════════════════════════════════

# Alias Management
Get-Alias
Get-Alias -Name ls
Get-Alias -Definition Get-ChildItem
New-Alias -Name np -Value notepad
Set-Alias -Name list -Value Get-ChildItem
Remove-Alias -Name list
Export-Alias "aliases.txt"
Import-Alias "aliases.txt"

# Common Aliases
# ls = Get-ChildItem
# cd = Set-Location
# pwd = Get-Location
# cat = Get-Content
# ps = Get-Process
# kill = Stop-Process
# dir = Get-ChildItem
# copy = Copy-Item
# move = Move-Item
# del = Remove-Item

#endregion

#region ADDITIONAL UTILITIES
#═══════════════════════════════════════════════════════════════════════════════

# Clipboard
Get-Clipboard
Set-Clipboard -Value "Text"
Set-Clipboard -Path "C:\file.txt"

# Random Numbers
Get-Random
Get-Random -Minimum 1 -Maximum 100
Get-Random -InputObject @("Red","Green","Blue")

# Date/Time Operations
Get-Date
Get-Date -Format "yyyy-MM-dd"
(Get-Date).AddDays(7)
(Get-Date).AddHours(-3)
New-TimeSpan -Start (Get-Date) -End (Get-Date).AddDays(30)

# Measure Command Time
Measure-Command { Get-Process }
Measure-Command { Start-Sleep -Seconds 2 }

# Compare Objects
Compare-Object -ReferenceObject (Get-Content "file1.txt") -DifferenceObject (Get-Content "file2.txt")

# Select Object Properties
Get-Process | Select-Object Name, Id, CPU
Get-Process | Select-Object -First 10
Get-Process | Select-Object -Last 5
Get-Process | Select-Object -Unique Name

# Where Object Filtering
Get-Process | Where-Object {$_.CPU -gt 100}
Get-Process | Where-Object CPU -gt 100
Get-Service | Where-Object {$_.Status -eq "Running"}

# Group Object
Get-Process | Group-Object ProcessName
Get-Service | Group-Object Status

# Sort Object
Get-Process | Sort-Object CPU
Get-Process | Sort-Object CPU -Descending
Get-Process | Sort-Object CPU, Name

# Invoke Web Request
Invoke-WebRequest -Uri "https://example.com"
Invoke-RestMethod -Uri "https://api.example.com/data"
Invoke-WebRequest -Uri "https://example.com/file.zip" -OutFile "file.zip"

# Start Sleep
Start-Sleep -Seconds 5
Start-Sleep -Milliseconds 500

# Clear Screen
Clear-Host
cls

#endregion

<#
═══════════════════════════════════════════════════════════════════════════════
                                END OF REFERENCE
═══════════════════════════════════════════════════════════════════════════════

This comprehensive reference covers 800+ PowerShell 5 commands and operations.
Use this as a quick reference for Windows system administration and automation.

To use specific commands:
1. Copy the command you need
2. Modify parameters as necessary
3. Run in PowerShell (some commands require Admin privileges)

Note: Some sections require additional modules or specific Windows versions.
Always test commands in a safe environment before production use.

═══════════════════════════════════════════════════════════════════════════════
#>
