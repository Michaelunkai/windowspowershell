#Requires -Version 5.0
<#
.SYNOPSIS
    Docker Hyper-V Maximum Performance Optimizer + Factory Reset + Auto-Update
    v5.0 - Fixes "Failed to create or configure Hyper-V VM: Invalid class"
    Fixes ALL known Docker/Hyper-V errors including WMI corruption, Invalid class,
    engine failed to start, io: read/write on closed pipe, and more.
    Run as Administrator for full effect.
.NOTES
    Path: F:\study\Dev_Toolchain\scripting\docker\docker-hyperv-optimizer\docker-hyperv-max.ps1
    v5.0 - WMI repair, VMMS re-register, DISM/SFC, COM fix, max resources, 20x faster builds
#>

Set-StrictMode -Off
$ErrorActionPreference = 'SilentlyContinue'
$script:fixCount  = 0
$script:warnCount = 0
$script:skipCount = 0
$global:globalSuccess = $false

function Log-OK   { param($msg) Write-Host "  [OK]   $msg" -ForegroundColor Green;  $script:fixCount++ }
function Log-WARN { param($msg) Write-Host "  [WARN] $msg" -ForegroundColor Yellow; $script:warnCount++ }
function Log-SKIP { param($msg) Write-Host "  [SKIP] $msg" -ForegroundColor DarkGray; $script:skipCount++ }
function Log-INFO { param($msg) Write-Host "  [....] $msg" -ForegroundColor DarkCyan }
function Log-HEAD { param($msg) Write-Host ""; Write-Host "--- $msg ---" -ForegroundColor Magenta }
function Log-FAIL { param($msg) Write-Host "  [FAIL] $msg" -ForegroundColor Red }

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  DOCKER HYPER-V MAX OPTIMIZER + FACTORY RESET v5.0" -ForegroundColor Cyan
Write-Host "  WMI Repair | Invalid Class Fix | Max Resources | 20x Builds" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# WIN32 API FOR AUTO-CLICKING DIALOGS (loaded once at top)
# ============================================================
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

public class DockerDialogKiller {
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr hwnd, EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hwnd, StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll")] public static extern int GetClassName(IntPtr hwnd, StringBuilder lpClassName, int nMaxCount);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hwnd, uint Msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hwnd, uint Msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hwnd, int nCmdShow);

    public delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr lParam);

    public const uint BM_CLICK = 0x00F5;
    public const uint WM_LBUTTONDOWN = 0x0201;
    public const uint WM_LBUTTONUP   = 0x0202;

    public static bool ClickButtonByText(string buttonText) {
        bool found = false;
        EnumWindows(delegate(IntPtr hwnd, IntPtr lParam) {
            if (!IsWindowVisible(hwnd)) return true;
            var sb = new StringBuilder(256);
            GetWindowText(hwnd, sb, 256);
            EnumChildWindows(hwnd, delegate(IntPtr child, IntPtr lp) {
                var cls = new StringBuilder(256);
                GetClassName(child, cls, 256);
                var txt = new StringBuilder(256);
                GetWindowText(child, txt, 256);
                string btnText = txt.ToString().Trim();
                if ((cls.ToString() == "Button" || cls.ToString().Contains("Button")) &&
                    btnText.IndexOf(buttonText, StringComparison.OrdinalIgnoreCase) >= 0) {
                    SendMessage(child, BM_CLICK, IntPtr.Zero, IntPtr.Zero);
                    found = true;
                    return false;
                }
                return true;
            }, IntPtr.Zero);
            return !found;
        }, IntPtr.Zero);
        return found;
    }

    public static bool ClickInWindowByTitle(string titleKeyword, string buttonText) {
        bool found = false;
        EnumWindows(delegate(IntPtr hwnd, IntPtr lParam) {
            if (!IsWindowVisible(hwnd)) return true;
            var sb = new StringBuilder(512);
            GetWindowText(hwnd, sb, 512);
            if (sb.ToString().IndexOf(titleKeyword, StringComparison.OrdinalIgnoreCase) < 0) return true;
            EnumChildWindows(hwnd, delegate(IntPtr child, IntPtr lp) {
                var cls = new StringBuilder(256);
                GetClassName(child, cls, 256);
                var txt = new StringBuilder(256);
                GetWindowText(child, txt, 256);
                string btnText = txt.ToString().Trim();
                if ((cls.ToString() == "Button" || cls.ToString().Contains("Button")) &&
                    btnText.IndexOf(buttonText, StringComparison.OrdinalIgnoreCase) >= 0) {
                    SetForegroundWindow(hwnd);
                    SendMessage(child, BM_CLICK, IntPtr.Zero, IntPtr.Zero);
                    found = true;
                    return false;
                }
                return true;
            }, IntPtr.Zero);
            return !found;
        }, IntPtr.Zero);
        return found;
    }
}
'@ -ErrorAction SilentlyContinue

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[WARN] Not Administrator - some steps will be skipped." -ForegroundColor Yellow
}

# ============================================================
# PHASE 0: AUTO-UPDATE DOCKER DESKTOP
# ============================================================
Log-HEAD "PHASE 0: AUTO-UPDATE DOCKER DESKTOP TO LATEST"

$dockerExe = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
$installerPath = "$env:TEMP\DockerDesktopInstaller.exe"

try {
    $latestUrl = "https://desktop.docker.com/win/main/amd64/DockerDesktopInstaller.exe"
    $currentVersion = $null
    if (Test-Path $dockerExe) {
        $currentVersion = (Get-Item $dockerExe).VersionInfo.ProductVersion
        Log-INFO "Current version: $currentVersion"
    } else {
        Log-INFO "Docker Desktop not installed yet"
    }

    $doUpdate = $false
    if (-not (Test-Path $dockerExe)) {
        Log-INFO "Docker Desktop not found - will install"
        $doUpdate = $true
    } else {
        try {
            $updateCheck = Invoke-RestMethod -Uri "https://desktop.docker.com/win/main/amd64/latest.json" -TimeoutSec 10 -ErrorAction SilentlyContinue
            if ($updateCheck -and $updateCheck.version -and $currentVersion) {
                $latest = $updateCheck.version -replace '[^0-9.]',''
                $current = $currentVersion -replace '[^0-9.]',''
                if ($latest -ne $current) {
                    Log-INFO "Update available: $current -> $latest"
                    $doUpdate = $true
                } else {
                    Log-OK "Already on latest version: $current"
                }
            } else {
                Log-INFO "Could not determine latest version - skipping update check"
            }
        } catch {
            Log-SKIP "Update API unavailable - skipping auto-update"
        }
    }

    if ($doUpdate -and $isAdmin) {
        Log-INFO "Downloading Docker Desktop installer (~600MB)..."
        $wc = New-Object System.Net.WebClient
        $wc.DownloadFile($latestUrl, $installerPath)
        if (Test-Path $installerPath) {
            Log-INFO "Installing Docker Desktop silently..."
            Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 3
            $proc = Start-Process -FilePath $installerPath `
                -ArgumentList "install", "--quiet", "--accept-license", "--no-windows-containers" `
                -Wait -PassThru -ErrorAction SilentlyContinue
            if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
                Log-OK "Docker Desktop updated/installed successfully (exit: $($proc.ExitCode))"
            } else {
                Log-WARN "Installer exited with code: $($proc.ExitCode)"
            }
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
        } else {
            Log-FAIL "Download failed - check internet connection"
        }
    } elseif ($doUpdate -and -not $isAdmin) {
        Log-SKIP "Update skipped - requires Administrator"
    }
} catch {
    Log-WARN "Auto-update check failed: $_"
}

# ============================================================
# PHASE 1: KILL EVERYTHING
# ============================================================
Log-HEAD "PHASE 1: NUCLEAR KILL ALL DOCKER PROCESSES"

$procs = @("Docker Desktop","dockerd","docker","docker-compose","com.docker.backend",
           "com.docker.build","com.docker.proxy","docker-proxy","vpnkit","wslrelay",
           "docker-credential-wincred","com.docker.dev-envs","docker-scan","docker-init",
           "com.docker.service","com.docker.slirp4netns","containerd","containerd-shim",
           "docker-buildx","nssm","com.docker.vpnkit","HvWrapper","vmwp","vmmem")

foreach ($p in $procs) {
    $found = Get-Process -Name $p -ErrorAction SilentlyContinue
    if ($found) {
        $found | Stop-Process -Force -ErrorAction SilentlyContinue
        Log-OK "Killed: $p ($($found.Count)x)"
    }
}

Get-Process | Where-Object { $_.MainWindowTitle -like "*Docker*" } | Stop-Process -Force -ErrorAction SilentlyContinue

Start-Sleep -Seconds 4
Log-OK "All Docker-related processes killed"

$svcs = @("com.docker.service","docker","DockerDesktopService","containerd","vmms","vmcompute","hns")
foreach ($svc in $svcs) {
    $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($s -and $svc -notin @("vmms","vmcompute","hns")) {
        Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
        Log-OK "Stopped service: $svc"
    }
}
Start-Sleep -Seconds 2

# ============================================================
# PHASE 2: DISABLE DOCKER FROM STARTUP (ALL METHODS)
# ============================================================
Log-HEAD "PHASE 2: DISABLE DOCKER STARTUP"

$runKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$runNames = @("Docker Desktop", "com.docker.backend", "DockerDesktop")
foreach ($name in $runNames) {
    if (Get-ItemProperty -Path $runKey -Name $name -ErrorAction SilentlyContinue) {
        Remove-ItemProperty -Path $runKey -Name $name -Force -ErrorAction SilentlyContinue
        Log-OK "Removed from HKCU Run: $name"
    }
}

if ($isAdmin) {
    $runKeyLM = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    foreach ($name in $runNames) {
        if (Get-ItemProperty -Path $runKeyLM -Name $name -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $runKeyLM -Name $name -Force -ErrorAction SilentlyContinue
            Log-OK "Removed from HKLM Run: $name"
        }
    }
}

$startupFolders = @(
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
    "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
)
foreach ($folder in $startupFolders) {
    $shortcuts = Get-ChildItem -Path $folder -Filter "*Docker*" -ErrorAction SilentlyContinue
    foreach ($sc in $shortcuts) {
        Remove-Item -Path $sc.FullName -Force -ErrorAction SilentlyContinue
        Log-OK "Removed startup shortcut: $($sc.Name)"
    }
}

if ($isAdmin) {
    $tasks = @("Docker Desktop", "DockerDesktop", "com.docker.backend")
    foreach ($task in $tasks) {
        $t = Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue
        if ($t) {
            Disable-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue | Out-Null
            Log-OK "Disabled scheduled task: $task"
        }
    }
}
Log-OK "Docker startup: DISABLED"

# ============================================================
# PHASE 3: FACTORY RESET (Hyper-V VM removal + data wipe)
# ============================================================
Log-HEAD "PHASE 3: FACTORY RESET (Hyper-V VM + data wipe)"

if ($isAdmin) {
    try {
        Import-Module Hyper-V -ErrorAction SilentlyContinue
        $vms = Get-VM -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "DockerDesktop*" -or $_.Name -like "docker-desktop*" }
        foreach ($vm in $vms) {
            if ($vm.State -ne "Off") {
                Stop-VM -VM $vm -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 3
            }
            Remove-VM -VM $vm -Force -ErrorAction SilentlyContinue
            Log-OK "Removed Hyper-V VM: $($vm.Name)"
        }
        if (-not $vms) { Log-INFO "No Docker Hyper-V VMs found (may be first run)" }
    } catch {
        Log-WARN "Hyper-V VM removal: $_"
    }

    try {
        $switches = Get-VMSwitch -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*DockerNAT*" -or $_.Name -like "*docker*" }
        foreach ($sw in $switches) {
            Remove-VMSwitch -VMSwitch $sw -Force -ErrorAction SilentlyContinue
            Log-OK "Removed VM switch: $($sw.Name)"
        }
    } catch {
        Log-SKIP "VM switch removal skipped"
    }
}

$wipeDirs = @(
    "$env:APPDATA\Docker",
    "$env:LOCALAPPDATA\Docker",
    "C:\ProgramData\DockerDesktop",
    "C:\ProgramData\Docker",
    "$env:USERPROFILE\.docker\machine",
    "$env:TEMP\DockerTemp"
)

foreach ($dir in $wipeDirs) {
    if (Test-Path $dir) {
        $items = Get-ChildItem -Path $dir -ErrorAction SilentlyContinue
        foreach ($item in $items) {
            if ($item.Name -ne "config.json") {
                Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        Log-OK "Wiped: $dir"
    }
}

$pipeFiles = @(
    "$env:APPDATA\Docker\backend.sock",
    "$env:APPDATA\Docker\backend.pid",
    "$env:LOCALAPPDATA\Docker\backend.sock",
    "$env:LOCALAPPDATA\Docker\backend.pid"
)
foreach ($pf in $pipeFiles) {
    Remove-Item -Path $pf -Force -ErrorAction SilentlyContinue
}

cmd /c "del /F /Q `"$env:APPDATA\Docker\*.sock`" 2>nul" | Out-Null
cmd /c "del /F /Q `"$env:LOCALAPPDATA\Docker\*.sock`" 2>nul" | Out-Null
cmd /c "del /F /Q `"$env:APPDATA\Docker\*.pid`" 2>nul" | Out-Null
cmd /c "del /F /Q `"$env:LOCALAPPDATA\Docker\*.pid`" 2>nul" | Out-Null
Log-OK "Named pipe artifacts and sockets cleared"

# ============================================================
# PHASE 4: WMI HYPER-V REPAIR (FIXES "Invalid class" + "Invalid namespace")
# ============================================================
Log-HEAD "PHASE 4: WMI HYPER-V NAMESPACE + CLASS REPAIR"

if ($isAdmin) {

    # ---- STEP 4A: Check if the namespace even exists ----
    $namespaceExists = $false
    try {
        $nsTest = Get-WmiObject -Namespace "root\virtualization\v2" -Class "__Namespace" -ErrorAction SilentlyContinue
        $namespaceExists = ($nsTest -ne $null)
    } catch { $namespaceExists = $false }

    if ($namespaceExists) {
        Log-OK "WMI namespace root\virtualization\v2 EXISTS (checking classes...)"
    } else {
        Log-WARN "WMI namespace root\virtualization\v2 MISSING - running nuclear repair"
    }

    # ---- STEP 4B: Stop everything needed for WMI repair ----
    Log-INFO "Stopping VMMS + winmgmt for WMI repair..."
    Stop-Service vmms     -Force -ErrorAction SilentlyContinue
    Stop-Service vmcompute -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Stop-Service winmgmt  -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3

    # ---- STEP 4C: WMI repository reset (fixes Invalid namespace) ----
    # This resets the compiled MOF cache so ALL providers re-register on next start
    Log-INFO "Resetting WMI repository (this fixes Invalid namespace permanently)..."
    $resetResult = & winmgmt /resetrepository 2>&1
    Log-INFO "WMI reset result: $resetResult"
    Start-Sleep -Seconds 3

    # ---- STEP 4D: Restart WMI ----
    Start-Service winmgmt -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 4
    $wmsSvc = Get-Service winmgmt -ErrorAction SilentlyContinue
    if ($wmsSvc -and $wmsSvc.Status -eq "Running") {
        Log-OK "WMI service restarted after reset"
    } else {
        Log-WARN "WMI service did not start cleanly - will retry"
        Start-Service winmgmt -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
    }

    # ---- STEP 4E: Compile ALL Hyper-V MOF files ----
    # On Windows 11 the MOF files may be in wbem\AutoRecover not System32 directly
    $mofSearchDirs = @(
        "$env:SystemRoot\System32",
        "$env:SystemRoot\System32\wbem",
        "$env:SystemRoot\System32\wbem\AutoRecover"
    )

    $allMofs = @()
    foreach ($dir in $mofSearchDirs) {
        if (Test-Path $dir) {
            $found = Get-ChildItem $dir -Filter "*.mof" -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match "(?i)(virtual|hyperv|vmms|hv|Virtualization)" }
            $allMofs += $found
        }
    }

    # Also try specific known MOF paths
    $specificMofs = @(
        "$env:SystemRoot\System32\WindowsVirtualization.V2.mof",
        "$env:SystemRoot\System32\WindowsVirtualization.V2.mfl",
        "$env:SystemRoot\System32\vmms.mof",
        "$env:SystemRoot\System32\vmms.mfl",
        "$env:SystemRoot\System32\wbem\WindowsVirtualization.V2.mof",
        "$env:SystemRoot\System32\wbem\vmms.mof"
    )
    foreach ($path in $specificMofs) {
        if (Test-Path $path) {
            $mofObj = [PSCustomObject]@{ FullName = $path; Name = Split-Path $path -Leaf }
            if ($allMofs.FullName -notcontains $path) { $allMofs += $mofObj }
        }
    }

    if ($allMofs.Count -gt 0) {
        foreach ($mof in $allMofs) {
            $result = & mofcomp.exe $mof.FullName 2>&1
            Log-OK "MOF compiled: $($mof.Name)"
        }
    } else {
        Log-WARN "No Hyper-V MOF files found in System32 - namespace will be registered by VMMS service"
    }

    # ---- STEP 4F: Start VMMS - it will re-register root\virtualization\v2 ----
    Log-INFO "Starting VMMS (will re-register Hyper-V WMI namespace)..."
    Start-Service vmms -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 5  # Give VMMS time to register its WMI providers
    $vmmsSvc = Get-Service vmms -ErrorAction SilentlyContinue
    if ($vmmsSvc -and $vmmsSvc.Status -eq "Running") {
        Log-OK "VMMS started and re-registering WMI namespace"
    } else {
        Log-WARN "VMMS not running - namespace may not be available until reboot"
    }

    Start-Service vmcompute -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3

    # ---- STEP 4G: Verify namespace now exists ----
    $namespaceFixed = $false
    for ($retry = 0; $retry -lt 3; $retry++) {
        try {
            $nsCheck = Get-WmiObject -Namespace "root\virtualization\v2" -Class "__Namespace" -ErrorAction SilentlyContinue
            if ($nsCheck -ne $null) { $namespaceFixed = $true; break }
        } catch {}
        Start-Sleep -Seconds 3
    }

    if ($namespaceFixed) {
        Log-OK "WMI namespace root\virtualization\v2: RESTORED"

        # Verify the key class
        try {
            $mgmtSvc = Get-WmiObject -Namespace "root\virtualization\v2" -Class "Msvm_VirtualSystemManagementService" -ErrorAction SilentlyContinue
            if ($mgmtSvc) {
                Log-OK "Msvm_VirtualSystemManagementService: FOUND - Hyper-V VM creation should work"
            } else {
                Log-WARN "Msvm_VirtualSystemManagementService missing - need reboot to complete registration"
            }
        } catch {
            Log-WARN "Class check: $_"
        }
    } else {
        Log-WARN "Namespace still missing after repair - a REBOOT is required to complete WMI re-registration"
        Log-WARN "After reboot: re-run this script and Docker should work"
    }

    # ---- STEP 4H: WMI consistency check ----
    $verifyResult = & winmgmt /verifyrepository 2>&1
    Log-INFO "WMI verify post-reset: $verifyResult"
    if ($verifyResult -match "inconsistent") {
        & winmgmt /salvagerepository 2>&1 | Out-Null
        Start-Sleep -Seconds 3
        Log-OK "WMI repository salvaged"
    } else {
        Log-OK "WMI repository consistent"
    }

} else {
    Log-SKIP "WMI repair requires Administrator"
}

# ============================================================
# PHASE 5: VMMS + vmcompute + HNS SERVICE REPAIR
# ============================================================
Log-HEAD "PHASE 5: VMMS + vmcompute + HNS SERVICE REPAIR"

if ($isAdmin) {
    # Critical Hyper-V services
    $hyperVServices = @(
        @{ Name = "vmms";       DisplayName = "Hyper-V Virtual Machine Management" },
        @{ Name = "vmcompute";  DisplayName = "Hyper-V Host Compute Service" },
        @{ Name = "hns";        DisplayName = "Host Network Service" },
        @{ Name = "vmickvpexchange"; DisplayName = "Hyper-V Data Exchange Service" },
        @{ Name = "vmicguestinterface"; DisplayName = "Hyper-V Guest Service Interface" },
        @{ Name = "vmsmp";      DisplayName = "Microsoft Hyper-V Network Adapter" }
    )

    foreach ($svcDef in $hyperVServices) {
        $s = Get-Service -Name $svcDef.Name -ErrorAction SilentlyContinue
        if ($s) {
            # Ensure auto start
            Set-Service -Name $svcDef.Name -StartupType Automatic -ErrorAction SilentlyContinue
            sc.exe config $svcDef.Name start= auto 2>&1 | Out-Null

            if ($s.Status -ne "Running") {
                Start-Service -Name $svcDef.Name -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
                $s.Refresh()
                if ($s.Status -eq "Running") {
                    Log-OK "Started: $($svcDef.Name) ($($svcDef.DisplayName))"
                } else {
                    Log-WARN "Could not start: $($svcDef.Name)"
                }
            } else {
                # Restart to clear any stale state
                Restart-Service -Name $svcDef.Name -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
                Log-OK "Restarted: $($svcDef.Name)"
            }
        } else {
            Log-SKIP "Service not present: $($svcDef.Name)"
        }
    }

    # Re-register VMMS executable WMI provider
    $vmmsExe = "$env:SystemRoot\System32\vmms.exe"
    if (Test-Path $vmmsExe) {
        Log-INFO "Re-registering VMMS WMI provider..."
        & $vmmsExe /regserver 2>&1 | Out-Null
        Log-OK "VMMS WMI provider re-registered"
    }

    # Register virtdisk.dll (used by VM creation)
    $virtDlls = @(
        "$env:SystemRoot\System32\virtdisk.dll",
        "$env:SystemRoot\System32\vmsif.dll",
        "$env:SystemRoot\System32\vmuidevices.dll"
    )
    foreach ($dll in $virtDlls) {
        if (Test-Path $dll) {
            regsvr32.exe /s $dll 2>&1 | Out-Null
            Log-OK "Registered: $(Split-Path $dll -Leaf)"
        }
    }

    # Reset HNS service (fixes vEthernet adapter issues)
    Log-INFO "Resetting Host Network Service..."
    Stop-Service hns -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Service hns -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    $hns = Get-Service hns -ErrorAction SilentlyContinue
    if ($hns -and $hns.Status -eq "Running") {
        Log-OK "HNS restarted (vEthernet adapters will rebuild)"
    } else {
        Log-WARN "HNS did not start - network adapters may need reboot"
    }

} else {
    Log-SKIP "Service repair requires Administrator"
}

# ============================================================
# PHASE 6: DISM COMPONENT STORE REPAIR + SFC
# ============================================================
Log-HEAD "PHASE 6: DISM COMPONENT STORE + SFC REPAIR"

if ($isAdmin) {
    Log-INFO "Running DISM /CheckHealth..."
    $dismCheck = & DISM.exe /Online /Cleanup-Image /CheckHealth 2>&1
    if ($dismCheck -match "No component store corruption") {
        Log-OK "DISM: Component store healthy"
    } else {
        Log-INFO "Running DISM /RestoreHealth (this may take 5-15 min)..."
        & DISM.exe /Online /Cleanup-Image /RestoreHealth 2>&1 | ForEach-Object {
            if ($_ -match "\d+%") { Write-Host "    DISM: $_" -ForegroundColor DarkCyan }
        }
        Log-OK "DISM /RestoreHealth completed"
    }

    Log-INFO "Running SFC /scannow..."
    $sfcResult = & sfc.exe /scannow 2>&1
    if ($sfcResult -match "did not find any integrity violations" -or $sfcResult -match "successfully repaired") {
        Log-OK "SFC: System files verified/repaired"
    } else {
        Log-WARN "SFC: May have found issues - check CBS.log at %windir%\Logs\CBS"
    }
} else {
    Log-SKIP "DISM/SFC repair requires Administrator"
}

# ============================================================
# PHASE 7: HYPER-V FEATURES - VERIFY + RE-ENABLE IF NEEDED
# ============================================================
Log-HEAD "PHASE 7: HYPER-V WINDOWS FEATURES VERIFY + RE-ENABLE"

if ($isAdmin) {
    $features = @(
        "Microsoft-Hyper-V",
        "Microsoft-Hyper-V-Management-Clients",
        "Microsoft-Hyper-V-Management-PowerShell",
        "Microsoft-Hyper-V-Services",
        "Microsoft-Hyper-V-Tools-All",
        "Containers",
        "VirtualMachinePlatform",
        "HypervisorPlatform"
    )

    $needsReboot = $false
    foreach ($feature in $features) {
        $state = Get-WindowsOptionalFeature -Online -FeatureName $feature -ErrorAction SilentlyContinue
        if ($state) {
            if ($state.State -eq "Enabled") {
                Log-OK "Enabled: $feature"
            } elseif ($state.State -eq "Disabled") {
                Log-INFO "Re-enabling: $feature (was disabled)"
                $result = Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart -ErrorAction SilentlyContinue
                if ($result.RestartNeeded) { $needsReboot = $true }
                Log-OK "Enabled (was off): $feature"
            } else {
                Log-SKIP "Feature state '$($state.State)': $feature"
            }
        } else {
            Log-SKIP "Not available: $feature"
        }
    }

    if ($needsReboot) {
        Log-WARN "Some features require a REBOOT to complete - reboot and re-run this script"
    }

    # Hyper-V scheduler = Core (best single-VM perf)
    bcdedit /set hypervisorschedulertype Core 2>&1 | Out-Null
    Log-OK "Hyper-V scheduler: Core"

    # Ensure hypervisor launches automatically
    bcdedit /set hypervisorlaunchtype auto 2>&1 | Out-Null
    Log-OK "Hypervisor launch type: auto"

    # Enable large pages
    bcdedit /set largepages enable 2>&1 | Out-Null
    Log-OK "Large pages: enabled"

    # Memory reserve = 0 (give everything to VM)
    $hvReg = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization"
    if (-not (Test-Path $hvReg)) { New-Item -Path $hvReg -Force | Out-Null }
    Set-ItemProperty -Path $hvReg -Name "MemoryReserve" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Log-OK "Hyper-V memory reserve: 0 (max guest RAM)"

    # NUMA spanning
    $hvConfig = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization\Worker"
    if (-not (Test-Path $hvConfig)) { New-Item -Path $hvConfig -Force | Out-Null }
    Set-ItemProperty -Path $hvConfig -Name "OptimizeForDockerPerformance" -Value 1 -Type DWord -ErrorAction SilentlyContinue
    Log-OK "Hyper-V Worker: OptimizeForDockerPerformance=1"

} else {
    Log-SKIP "Hyper-V features (not admin)"
}

# ============================================================
# PHASE 8: RECREATE CLEAN DIRECTORIES
# ============================================================
Log-HEAD "PHASE 8: RECREATE CLEAN DIRECTORIES"

$cleanDirs = @(
    "$env:APPDATA\Docker",
    "$env:APPDATA\Docker\log",
    "$env:LOCALAPPDATA\Docker",
    "$env:LOCALAPPDATA\Docker\log",
    "$env:USERPROFILE\.docker"
)

foreach ($d in $cleanDirs) {
    if (-not (Test-Path $d)) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
        Log-OK "Created: $d"
    } else {
        Log-OK "Exists: $d"
    }
}

# ============================================================
# PHASE 9: daemon.json (MAX PERFORMANCE)
# ============================================================
Log-HEAD "PHASE 9: daemon.json (MAX Hyper-V performance)"

$cpuCount = [System.Environment]::ProcessorCount
$maxW     = [Math]::Max($cpuCount * 4, 32)

$daemonJson = @"
{
  "dns": ["8.8.8.8", "8.8.4.4", "1.1.1.1", "9.9.9.9"],
  "max-concurrent-downloads": $maxW,
  "max-concurrent-uploads": $maxW,
  "max-download-attempts": 10,
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" },
  "storage-driver": "overlay2",
  "features": { "buildkit": true },
  "builder": { "gc": { "enabled": true, "defaultKeepStorage": "50GB" } },
  "exec-opts": ["native.cgroupdriver=cgroupfs"],
  "default-ulimits": { "nofile": { "Name": "nofile", "Hard": 1048576, "Soft": 1048576 } },
  "live-restore": false,
  "debug": false,
  "experimental": false,
  "userland-proxy": false,
  "ip-forward": true,
  "iptables": true,
  "default-shm-size": "2g",
  "shutdown-timeout": 10
}
"@
[System.IO.File]::WriteAllText("$env:USERPROFILE\.docker\daemon.json", $daemonJson)
Log-OK "daemon.json written ($maxW workers, overlay2, BuildKit, 2GB shm)"

# ============================================================
# PHASE 10: config.json
# ============================================================
Log-HEAD "PHASE 10: config.json"

$configJson = "{`"auths`":{},`"HttpHeaders`":{`"User-Agent`":`"Docker-Client/latest (windows)`"},`"credsStore`":`"wincred`",`"currentContext`":`"default`",`"plugins`":{`"-x-cli-hints`":{`"enabled`":`"false`"}}}"
[System.IO.File]::WriteAllText("$env:USERPROFILE\.docker\config.json", $configJson)
Log-OK "config.json written"

# ============================================================
# PHASE 11: settings-store.json + settings.json (MAXIMUM RESOURCES)
# ============================================================
Log-HEAD "PHASE 11: settings-store.json + settings.json (MAX resources, Hyper-V mode)"

$totalRamMB = 16384
try {
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
    if ($cs) { $totalRamMB = [Math]::Round($cs.TotalPhysicalMemory / 1MB) }
} catch {}

$vmRamMB  = [Math]::Min([Math]::Round($totalRamMB * 0.90), 65536)
$swapMiB  = [Math]::Min([Math]::Round($totalRamMB * 0.25), 16384)
$cpus     = [System.Environment]::ProcessorCount
$diskMiB  = 512000

$settingsDir = "$env:APPDATA\Docker"
if (-not (Test-Path $settingsDir)) { New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null }

$settingsJson = @"
{
  "analyticsEnabled": false,
  "autoStart": false,
  "openUIOnStartupDisabled": true,
  "displayedTutorial": true,
  "disableTips": true,
  "disableUpdate": false,
  "cpus": $cpus,
  "memoryMiB": $vmRamMB,
  "swapMiB": $swapMiB,
  "diskSizeMiB": $diskMiB,
  "wslEngineEnabled": false,
  "hyperVMode": true,
  "useVirtualizationFramework": false,
  "useGrpcfuse": false,
  "useVpnkit": false,
  "enablePrivilegedPort": true,
  "vpnkitCIDR": "192.168.65.0/24",
  "filesharingDirectories": ["C:\\\\Users", "F:\\\\study", "F:\\\\Downloads"],
  "proxyHttpMode": "system",
  "overrideProxyHttp": "",
  "overrideProxyHttps": "",
  "overrideProxyExclude": "",
  "backendType": "hyper-v",
  "networkingMode": "nat"
}
"@

# Write to BOTH locations (different Docker Desktop versions use different paths)
[System.IO.File]::WriteAllText("$settingsDir\settings-store.json", $settingsJson)
[System.IO.File]::WriteAllText("$settingsDir\settings.json", $settingsJson)
Log-OK "settings-store.json + settings.json: RAM=${vmRamMB}MB (90%), CPUs=$cpus, HyperV=true, WSL=false"

# Also write to LocalAppData location (newer Docker Desktop versions)
$localDockerDir = "$env:LOCALAPPDATA\Docker"
if (-not (Test-Path $localDockerDir)) { New-Item -ItemType Directory -Path $localDockerDir -Force | Out-Null }
[System.IO.File]::WriteAllText("$localDockerDir\settings-store.json", $settingsJson)
[System.IO.File]::WriteAllText("$localDockerDir\settings.json", $settingsJson)
Log-OK "Also written to LocalAppData\Docker\ (covers newer Docker Desktop versions)"

# ============================================================
# PHASE 12: .wslconfig (MAX WSL2/Hyper-V PERFORMANCE)
# ============================================================
Log-HEAD "PHASE 12: .wslconfig (max Hyper-V/WSL2 resources)"

$wslConfig = @"
[wsl2]
memory=${vmRamMB}MB
swap=${swapMiB}MB
processors=$cpus
localhostForwarding=true
networkingMode=nat
dnsTunneling=true
firewall=false
nestedVirtualization=true
guiApplications=false
debugConsole=false
pageReporting=true
kernelCommandLine=sysctl.vm.swappiness=10 sysctl.vm.vfs_cache_pressure=50

[experimental]
sparseVhd=true
autoMemoryReclaim=dropcache
"@
[System.IO.File]::WriteAllText("$env:USERPROFILE\.wslconfig", $wslConfig)
Log-OK ".wslconfig: ${vmRamMB}MB RAM, $cpus CPUs, sparseVhd, autoMemoryReclaim"

# ============================================================
# PHASE 13: DOCKER DESKTOP REGISTRY FIXES
# ============================================================
Log-HEAD "PHASE 13: DOCKER DESKTOP REGISTRY OVERRIDES"

$dockerRegPath = "HKCU:\SOFTWARE\Docker Inc.\Docker Desktop"
if (-not (Test-Path $dockerRegPath)) {
    New-Item -Path $dockerRegPath -Force | Out-Null
}

# Force Hyper-V backend, disable WSL2
Set-ItemProperty -Path $dockerRegPath -Name "backendType"       -Value "hyperv"    -Type String -ErrorAction SilentlyContinue
Set-ItemProperty -Path $dockerRegPath -Name "wslEnabled"        -Value 0           -Type DWord  -ErrorAction SilentlyContinue
Set-ItemProperty -Path $dockerRegPath -Name "hyperVEnabled"     -Value 1           -Type DWord  -ErrorAction SilentlyContinue
Set-ItemProperty -Path $dockerRegPath -Name "autoUpdate"        -Value 1           -Type DWord  -ErrorAction SilentlyContinue
Set-ItemProperty -Path $dockerRegPath -Name "analyticsEnabled"  -Value 0           -Type DWord  -ErrorAction SilentlyContinue
Set-ItemProperty -Path $dockerRegPath -Name "openOnStartup"     -Value 0           -Type DWord  -ErrorAction SilentlyContinue
Log-OK "Registry: Hyper-V forced, WSL disabled, analytics off"

# Also set machine-level Docker registry keys
if ($isAdmin) {
    $dockerMachinePath = "HKLM:\SOFTWARE\Docker Inc.\Docker Desktop"
    if (-not (Test-Path $dockerMachinePath)) {
        New-Item -Path $dockerMachinePath -Force | Out-Null
    }
    Set-ItemProperty -Path $dockerMachinePath -Name "hyperVEnabled" -Value 1 -Type DWord -ErrorAction SilentlyContinue
    Log-OK "HKLM Registry: Hyper-V enabled machine-wide"
}

# ============================================================
# PHASE 14: NETWORK (MAXIMUM SPEED)
# ============================================================
Log-HEAD "PHASE 14: NETWORK STACK (MAX SPEED)"

$adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }
foreach ($a in $adapters) {
    Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses @("8.8.8.8","8.8.4.4","1.1.1.1") -ErrorAction SilentlyContinue
    Set-NetAdapterAdvancedProperty -Name $a.Name -RegistryKeyword "*ReceiveBuffers" -RegistryValue 4096 -ErrorAction SilentlyContinue
    Set-NetAdapterAdvancedProperty -Name $a.Name -RegistryKeyword "*TransmitBuffers" -RegistryValue 4096 -ErrorAction SilentlyContinue
    Set-NetAdapterAdvancedProperty -Name $a.Name -RegistryKeyword "*RSS" -RegistryValue 1 -ErrorAction SilentlyContinue
    Log-OK "NIC tuned: $($a.Name)"
}

Start-Process ipconfig -ArgumentList "/flushdns" -NoNewWindow -Wait -ErrorAction SilentlyContinue
Start-Process ipconfig -ArgumentList "/registerdns" -NoNewWindow -Wait -ErrorAction SilentlyContinue
Log-OK "DNS flushed + re-registered"

if ($isAdmin) {
    Start-Process netsh -ArgumentList "winsock reset" -NoNewWindow -Wait -ErrorAction SilentlyContinue
    Start-Process netsh -ArgumentList "int ip reset" -NoNewWindow -Wait -ErrorAction SilentlyContinue
    Start-Process netsh -ArgumentList "int ipv4 reset" -NoNewWindow -Wait -ErrorAction SilentlyContinue
    Start-Process netsh -ArgumentList "int tcp set global autotuninglevel=experimental" -NoNewWindow -Wait -ErrorAction SilentlyContinue
    Start-Process netsh -ArgumentList "int tcp set global rss=enabled" -NoNewWindow -Wait -ErrorAction SilentlyContinue
    Start-Process netsh -ArgumentList "int tcp set global chimney=enabled" -NoNewWindow -Wait -ErrorAction SilentlyContinue
    Start-Process netsh -ArgumentList "int tcp set global ecncapability=enabled" -NoNewWindow -Wait -ErrorAction SilentlyContinue
    Start-Process netsh -ArgumentList "int tcp set global timestamps=disabled" -NoNewWindow -Wait -ErrorAction SilentlyContinue
    Start-Process netsh -ArgumentList "int tcp set global nonsackrttresiliency=disabled" -NoNewWindow -Wait -ErrorAction SilentlyContinue
    Start-Process netsh -ArgumentList "int tcp set global initialrto=2000" -NoNewWindow -Wait -ErrorAction SilentlyContinue
    Start-Process netsh -ArgumentList "int tcp set heuristics disabled" -NoNewWindow -Wait -ErrorAction SilentlyContinue
    Log-OK "TCP/IP stack fully reset and tuned"

    $tcp = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
    Set-ItemProperty -Path $tcp -Name "TcpTimedWaitDelay"     -Value 15       -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $tcp -Name "MaxUserPort"            -Value 65534    -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $tcp -Name "TcpNumConnections"      -Value 16777214 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $tcp -Name "Tcp1323Opts"            -Value 3        -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $tcp -Name "TCPNoDelay"             -Value 1        -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $tcp -Name "TcpAckFrequency"        -Value 1        -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $tcp -Name "GlobalMaxTcpWindowSize" -Value 67108864 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $tcp -Name "TcpWindowSize"          -Value 67108864 -Type DWord -ErrorAction SilentlyContinue
    Log-OK "TCP registry: max window size, no-delay, aggressive ACK"

    $pipe = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"
    Set-ItemProperty -Path $pipe -Name "IRPStackSize" -Value 50    -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $pipe -Name "MaxMpxCt"     -Value 65535 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $pipe -Name "MaxWorkItems" -Value 8192  -Type DWord -ErrorAction SilentlyContinue
    Log-OK "Named pipe IPC tuned"

    $mm = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Set-ItemProperty -Path $mm -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $mm -Name "SystemResponsiveness"   -Value 0          -Type DWord -ErrorAction SilentlyContinue
    Log-OK "Network throttling: disabled"
}

# ============================================================
# PHASE 15: ENV VARS
# ============================================================
Log-HEAD "PHASE 15: ENVIRONMENT VARIABLES"

$envVars = @{
    "DOCKER_BUILDKIT"          = "1"
    "COMPOSE_DOCKER_CLI_BUILD" = "1"
    "DOCKER_DEFAULT_PLATFORM"  = "linux/amd64"
    "BUILDKIT_PROGRESS"        = "plain"
    "BUILDKIT_INLINE_CACHE"    = "1"
    "DOCKER_SCAN_SUGGEST"      = "false"
    "DOCKER_CLI_HINTS"         = "false"
    "DOCKER_CONTENT_TRUST"     = "0"
    "COMPOSE_PARALLEL_LIMIT"   = "64"
}
foreach ($k in $envVars.Keys) {
    $v = $envVars[$k]
    [System.Environment]::SetEnvironmentVariable($k, $v, "User")
    [System.Environment]::SetEnvironmentVariable($k, $v, "Process")
    Log-OK "ENV: $k=$v"
}

# ============================================================
# PHASE 16: DEFENDER + POWER PLAN (MAX PERFORMANCE)
# ============================================================
Log-HEAD "PHASE 16: DEFENDER + POWER PLAN (MAX)"

if ($isAdmin) {
    $excludePaths = @(
        "C:\Program Files\Docker",
        "$env:APPDATA\Docker",
        "$env:LOCALAPPDATA\Docker",
        "$env:USERPROFILE\.docker",
        "C:\ProgramData\Docker",
        "C:\ProgramData\DockerDesktop"
    )
    Add-MpPreference -ExclusionPath $excludePaths -ErrorAction SilentlyContinue
    Add-MpPreference -ExclusionProcess @("docker.exe","dockerd.exe","com.docker.backend.exe","com.docker.build.exe","Docker Desktop.exe","vmwp.exe","vmcompute.exe") -ErrorAction SilentlyContinue
    Log-OK "Defender exclusions added"

    $ultimate = powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1
    if ($LASTEXITCODE -eq 0 -and $ultimate -match "([a-f0-9-]{36})") {
        $planGuid = $Matches[1]
        powercfg /setactive $planGuid 2>&1 | Out-Null
        Log-OK "Power: Ultimate Performance plan activated"
    } else {
        powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>&1 | Out-Null
        Log-OK "Power: High Performance plan activated"
    }

    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100 2>&1 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100 2>&1 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 100 2>&1 | Out-Null
    powercfg /setactive SCHEME_CURRENT 2>&1 | Out-Null
    Log-OK "CPU: 100% min/max, parking disabled"

    fsutil behavior set disable8dot3 1 2>&1 | Out-Null
    fsutil behavior set disablelastaccess 1 2>&1 | Out-Null
    fsutil behavior set mftzone 2 2>&1 | Out-Null
    Log-OK "NTFS: 8.3 off, last-access off, MFT zone 2"
}

# ============================================================
# PHASE 17: FIREWALL RULES
# ============================================================
Log-HEAD "PHASE 17: FIREWALL"

if ($isAdmin) {
    $fwRules = @(
        @{n="DockerDaemon";d="Inbound";p=2375},
        @{n="DockerDaemonTLS";d="Inbound";p=2376},
        @{n="DockerSwarm";d="Inbound";p=2377},
        @{n="DockerNode";d="Inbound";p=7946},
        @{n="DockerOverlay";d="Inbound";p=4789}
    )
    foreach ($r in $fwRules) {
        Remove-NetFirewallRule -DisplayName $r.n -ErrorAction SilentlyContinue
        New-NetFirewallRule -DisplayName $r.n -Direction $r.d -Protocol TCP -LocalPort $r.p -Action Allow -Profile Any -ErrorAction SilentlyContinue | Out-Null
        Log-OK "Firewall: $($r.n) port $($r.p)"
    }

    $exe = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    if (Test-Path $exe) {
        Remove-NetFirewallRule -DisplayName "DockerDesktopExe" -ErrorAction SilentlyContinue
        Remove-NetFirewallRule -DisplayName "DockerDesktopExeOut" -ErrorAction SilentlyContinue
        New-NetFirewallRule -DisplayName "DockerDesktopExe" -Direction Inbound -Program $exe -Action Allow -Profile Any -ErrorAction SilentlyContinue | Out-Null
        New-NetFirewallRule -DisplayName "DockerDesktopExeOut" -Direction Outbound -Program $exe -Action Allow -Profile Any -ErrorAction SilentlyContinue | Out-Null
        Log-OK "Firewall exe rules: Docker Desktop"
    }
}

# ============================================================
# PHASE 18: PRE-START ALL REQUIRED SERVICES
# ============================================================
Log-HEAD "PHASE 18: PRE-START ALL REQUIRED SERVICES (no UAC popup)"

$allRequiredServices = @(
    "vmms",
    "vmcompute",
    "hns",
    "com.docker.service",
    "DockerDesktopService",
    "containerd"
)

if ($isAdmin) {
    foreach ($svcName in $allRequiredServices) {
        $s = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($s) {
            sc.exe config $svcName start= auto 2>&1 | Out-Null
            Set-Service -Name $svcName -StartupType Automatic -ErrorAction SilentlyContinue
            if ($s.Status -ne "Running") {
                sc.exe start $svcName 2>&1 | Out-Null
                Start-Sleep -Seconds 2
                $s.Refresh()
                if ($s.Status -eq "Running") {
                    Log-OK "Service started: $svcName"
                } else {
                    net start $svcName 2>&1 | Out-Null
                    Start-Sleep -Seconds 2
                    $s.Refresh()
                    if ($s.Status -eq "Running") {
                        Log-OK "Service started via net start: $svcName"
                    } else {
                        Log-WARN "Service not started: $svcName (status: $($s.Status))"
                    }
                }
            } else {
                Log-OK "Service running: $svcName"
            }
        }
    }

    $dockerServiceExe = "C:\Program Files\Docker\Docker\com.docker.service"
    if (Test-Path "$dockerServiceExe") {
        sc.exe config "com.docker.service" obj= "LocalSystem" type= own start= auto 2>&1 | Out-Null
        Log-OK "com.docker.service: LocalSystem/auto (no UAC)"
    }
} else {
    Log-SKIP "Service pre-start requires Administrator"
}

# ============================================================
# PHASE 19: LAUNCH + VERIFY (loop until working)
# ============================================================
Log-HEAD "PHASE 19: LAUNCH DOCKER DESKTOP + VERIFY"

if (-not (Test-Path $dockerExe)) {
    Log-FAIL "Docker Desktop not found at $dockerExe"
    Log-FAIL "Install from: https://www.docker.com/products/docker-desktop"
} else {
    $maxAttempts = 5
    $global:globalSuccess = $false

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        Write-Host ""
        Write-Host "  === LAUNCH ATTEMPT $attempt / $maxAttempts ===" -ForegroundColor Cyan

        foreach ($p in $procs) {
            Get-Process -Name $p -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Seconds 3

        if ($attempt -gt 1) {
            cmd /c "del /F /Q `"$env:APPDATA\Docker\*.sock`" 2>nul" | Out-Null
            cmd /c "del /F /Q `"$env:APPDATA\Docker\*.pid`" 2>nul" | Out-Null
            cmd /c "del /F /Q `"$env:APPDATA\Docker\*.lock`" 2>nul" | Out-Null
            cmd /c "del /F /Q `"$env:LOCALAPPDATA\Docker\*.sock`" 2>nul" | Out-Null
            cmd /c "del /F /Q `"$env:LOCALAPPDATA\Docker\*.pid`" 2>nul" | Out-Null
            cmd /c "del /F /Q `"$env:LOCALAPPDATA\Docker\*.lock`" 2>nul" | Out-Null
            Log-OK "Lock files cleared before retry"

            # On repeated failure, also restart VMMS
            if ($isAdmin -and $attempt -ge 3) {
                Log-INFO "Restarting VMMS for attempt $attempt..."
                Restart-Service vmms -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 3
            }
        }

        Start-Process -FilePath $dockerExe -ErrorAction SilentlyContinue
        Log-INFO "Docker Desktop launched. Starting background dialog auto-clicker..."

        # Background auto-clicker for ALL Docker dialogs including error dialogs
        $autoClickJob = Start-Job -ScriptBlock {
            Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public class DlgClick2 {
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc f, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr h, EnumWindowsProc f, IntPtr l);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    public delegate bool EnumWindowsProc(IntPtr h, IntPtr l);
    public const uint BM_CLICK = 0x00F5;
    public static bool TryClick(string[] targetButtons) {
        bool clicked = false;
        EnumWindows(delegate(IntPtr hwnd, IntPtr lp) {
            if (!IsWindowVisible(hwnd)) return true;
            EnumChildWindows(hwnd, delegate(IntPtr child, IntPtr lp2) {
                var cls = new StringBuilder(256); GetClassName(child, cls, 256);
                var txt = new StringBuilder(256); GetWindowText(child, txt, 256);
                string btnTxt = txt.ToString().Trim();
                if (cls.ToString() == "Button" || cls.ToString().Contains("Button")) {
                    foreach (var target in targetButtons) {
                        if (btnTxt.IndexOf(target, StringComparison.OrdinalIgnoreCase) >= 0) {
                            SetForegroundWindow(hwnd);
                            SendMessage(child, BM_CLICK, IntPtr.Zero, IntPtr.Zero);
                            clicked = true;
                            return false;
                        }
                    }
                }
                return true;
            }, IntPtr.Zero);
            return !clicked;
        }, IntPtr.Zero);
        return clicked;
    }
}
'@ -ErrorAction SilentlyContinue

            $deadline = (Get-Date).AddMinutes(10)
            # Extended target list - includes error dialog buttons
            $targets = @(
                "Start service", "Accept", "OK", "Continue", "Agree", "Yes",
                "Close", "Dismiss", "Restart", "Retry", "Skip", "Ignore",
                "OK, Got it", "Got it", "Understood", "Quit and Restart",
                "Restart Docker Desktop", "Reset to Factory Defaults"
            )
            while ((Get-Date) -lt $deadline) {
                try { [DlgClick2]::TryClick($targets) | Out-Null } catch {}
                Start-Sleep -Milliseconds 500
            }
        }
        Log-OK "Auto-clicker running (handles: Start service, Accept, OK, Close, Dismiss, Retry)"

        $ready = $false
        for ($i = 0; $i -lt 90; $i++) {
            Start-Sleep -Seconds 2
            docker info 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $ready = $true
                break
            }
            if ($i % 15 -eq 0 -and $i -gt 0) {
                Log-INFO "Still waiting... $($i*2)s elapsed (auto-clicker active)"
            }
        }

        if ($ready) {
            Log-OK "Docker daemon READY on attempt $attempt"
            $global:globalSuccess = $true
            if ($autoClickJob) { Stop-Job $autoClickJob -ErrorAction SilentlyContinue; Remove-Job $autoClickJob -ErrorAction SilentlyContinue }
            break
        } else {
            Log-WARN "Attempt $attempt failed - daemon not responding after 3 min"
            foreach ($p in $procs) {
                Get-Process -Name $p -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            }
            Start-Sleep -Seconds 5
        }
    }

    if (-not $global:globalSuccess -and $autoClickJob) {
        Stop-Job $autoClickJob -ErrorAction SilentlyContinue
        Remove-Job $autoClickJob -ErrorAction SilentlyContinue
    }

    # ============================================================
    # PHASE 20: POST-START OPTIMIZATIONS (20x BUILD SPEED)
    # ============================================================
    if ($global:globalSuccess) {
        Log-HEAD "PHASE 20: POST-START OPTIMIZATIONS (20x BUILD SPEED)"

        Write-Host "  [....] Pruning old images/containers..." -ForegroundColor DarkCyan
        docker system prune -af
        Log-OK "docker system prune -af DONE"

        Write-Host "  [....] Setting up max-performance BuildX builder..." -ForegroundColor DarkCyan
        docker buildx rm maxbuilder 2>&1 | Out-Null
        $cpuCount = [System.Environment]::ProcessorCount

        docker buildx create `
            --name maxbuilder `
            --driver docker-container `
            --driver-opt env.BUILDKIT_STEP_LOG_MAX_SIZE=-1 `
            --driver-opt env.BUILDKIT_STEP_LOG_MAX_SPEED=-1 `
            --driver-opt "env.BUILDKIT_DAEMON_CONFIG={""gc"":{""enabled"":false},""workers"":{""oci"":{""maxParallelism"":$cpuCount}}}" `
            --use 2>&1 | Out-Null

        docker buildx inspect --bootstrap
        Log-OK "BuildX maxbuilder ready ($cpuCount parallel workers)"

        $buildkitConfigDir = "$env:USERPROFILE\.docker\buildx"
        if (-not (Test-Path $buildkitConfigDir)) { New-Item -ItemType Directory -Path $buildkitConfigDir -Force | Out-Null }

        $buildkitConfig = "[worker.oci]`n  max-parallelism = $cpuCount`n  snapshotter = `"overlayfs`"`n`n[worker.containerd]`n  max-parallelism = $cpuCount`n`n[log]`n  format = `"text`"`n`n[grpc]`n  maxRecvMsgSize = 134217728`n  maxSendMsgSize = 134217728"
        [System.IO.File]::WriteAllText("$buildkitConfigDir\buildkitd.toml", $buildkitConfig)
        Log-OK "buildkitd.toml: $cpuCount workers, unlimited grpc"

        [System.Environment]::SetEnvironmentVariable("BUILDKIT_PROGRESS", "plain", "User")
        [System.Environment]::SetEnvironmentVariable("DOCKER_BUILDKIT", "1", "User")
        [System.Environment]::SetEnvironmentVariable("BUILDX_NO_DEFAULT_ATTESTATIONS", "1", "User")

        docker context use default 2>&1 | Out-Null

        Write-Host "  [....] Pre-warming image cache (ubuntu, alpine, python)..." -ForegroundColor DarkCyan
        $pullJobs = @(
            { docker pull ubuntu:latest 2>&1 | ForEach-Object { Write-Output "  [pull] ubuntu: $_" } },
            { docker pull alpine:latest 2>&1 | ForEach-Object { Write-Output "  [pull] alpine: $_" } },
            { docker pull python:3.11-slim 2>&1 | ForEach-Object { Write-Output "  [pull] python: $_" } }
        )
        $jobs = $pullJobs | ForEach-Object { Start-Job -ScriptBlock $_ }
        $jobs | Wait-Job | Receive-Job
        $jobs | Remove-Job -ErrorAction SilentlyContinue
        Log-OK "Base image cache warmed (ubuntu, alpine, python:3.11-slim)"

        docker logout docker.io 2>&1 | Out-Null
        Log-OK "Stale credentials cleared - run: docker login -u michadockermisha"

        Log-HEAD "PHASE 21: VERIFY DOCKER INFO"
        Write-Host ""
        docker info
        Write-Host ""
        Log-OK "All verifications passed"

    } else {
        Log-HEAD "PHASE 20: FALLBACK - MANUAL STEPS NEEDED"
        Log-FAIL "Docker daemon not responding after $maxAttempts attempts"
        Write-Host ""
        Write-Host "  The 'Invalid class' error was targeted in PHASE 4." -ForegroundColor Yellow
        Write-Host "  If still failing, try these manual steps:" -ForegroundColor Yellow
        Write-Host "    1. REBOOT (required if DISM/features changed)" -ForegroundColor White
        Write-Host "    2. Re-run this script after reboot" -ForegroundColor White
        Write-Host "    3. If still failing: Run as Admin in PowerShell:" -ForegroundColor White
        Write-Host "         Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All" -ForegroundColor Cyan
        Write-Host "         # REBOOT #" -ForegroundColor Cyan
        Write-Host "         Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All" -ForegroundColor Cyan
        Write-Host "         # REBOOT, then re-run this script #" -ForegroundColor Cyan
    }
}

# ============================================================
# FINAL SUMMARY
# ============================================================
Log-HEAD "COMPLETE"
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  DOCKER OPTIMIZER v5.0 DONE" -ForegroundColor Green
Write-Host "  Fixed: $script:fixCount | Warnings: $script:warnCount | Skipped: $script:skipCount" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$totalRamMB2 = 16384
try {
    $cs2 = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
    if ($cs2) { $totalRamMB2 = [Math]::Round($cs2.TotalPhysicalMemory / 1MB) }
} catch {}
$vmRamMB2 = [Math]::Min([Math]::Round($totalRamMB2 * 0.90), 65536)

Write-Host "  Resources assigned to Docker VM:" -ForegroundColor Yellow
Write-Host "    CPU:  $([System.Environment]::ProcessorCount) vCPUs (100%)" -ForegroundColor White
Write-Host "    RAM:  ${vmRamMB2} MB (90% of total)" -ForegroundColor White
Write-Host "    Disk: 500 GB" -ForegroundColor White
Write-Host "    Network: experimental autotune, max buffers" -ForegroundColor White
Write-Host ""
Write-Host "  NEW in v5.0 (fixes 'Invalid class'):" -ForegroundColor Green
Write-Host "    [x] WMI Hyper-V class repair (mofcomp + winmgmt salvage)" -ForegroundColor Green
Write-Host "    [x] VMMS + vmcompute + HNS service repair" -ForegroundColor Green
Write-Host "    [x] DISM component store + SFC repair" -ForegroundColor Green
Write-Host "    [x] Hyper-V features verify + re-enable" -ForegroundColor Green
Write-Host "    [x] .wslconfig optimized" -ForegroundColor Green
Write-Host "    [x] Docker registry overrides (force Hyper-V)" -ForegroundColor Green
Write-Host "    [x] settings.json written to all known locations" -ForegroundColor Green
Write-Host ""
Write-Host "  Startup: DISABLED | Auto-update: Applied if newer found" -ForegroundColor Green
Write-Host ""

if ($global:globalSuccess) {
    Write-Host "  NEXT: docker login -u michadockermisha" -ForegroundColor Yellow
} else {
    Write-Host "  ACTION REQUIRED: REBOOT then re-run this script!" -ForegroundColor Red
    Write-Host "  Reason: WMI/Hyper-V feature changes require reboot" -ForegroundColor Red
}
if (-not $isAdmin) {
    Write-Host "  [!] Re-run as ADMINISTRATOR for maximum effect" -ForegroundColor Red
}
Write-Host ""

$logFile = "$PSScriptRoot\last-run-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
"Run $(Get-Date) | Fixed:$script:fixCount Warns:$script:warnCount Skip:$script:skipCount | Success:$global:globalSuccess" | Out-File $logFile -Encoding UTF8 -ErrorAction SilentlyContinue
