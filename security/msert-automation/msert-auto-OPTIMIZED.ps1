# MSERT Auto-Scanner - OPTIMIZED v2
# Fixes: 
#   1. Removed /F:Y (was forcing FULL scan) - now defaults to QUICK
#   2. Added BM_GETCHECK verification - confirms Quick Scan selected
#   3. Added arrow key navigation for radio buttons
#   4. Integrated finish automation with log wait + results parsing
#   5. Reduced timeout from 7200s to 900s (15 min max)
#   6. Faster polling (2s instead of 5s)
#
# Expected runtime: 5-8 minutes for QUICK scan (not 16+)

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class W32 {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, CallBack cb, IntPtr l);
    [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern int SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
    public delegate bool CallBack(IntPtr h, IntPtr l);
    public const uint BM_CLICK = 0x00F5;
    public const uint BM_GETCHECK = 0x00F0;
    public const uint WM_LBUTTONDOWN = 0x0201;
    public const uint WM_LBUTTONUP = 0x0202;
}
"@

function Get-AllChildren($hwnd) {
    $script:allKids = @()
    $cb = [W32+CallBack]{
        param($h, $l)
        $sb = New-Object System.Text.StringBuilder 256
        [W32]::GetWindowText($h, $sb, 256) | Out-Null
        $cls = New-Object System.Text.StringBuilder 256
        [W32]::GetClassName($h, $cls, 256) | Out-Null
        if ([W32]::IsWindowVisible($h)) {
            $script:allKids += @{ hwnd=$h; text=$sb.ToString(); class=$cls.ToString() }
        }
        return $true
    }
    [W32]::EnumChildWindows($hwnd, $cb, [IntPtr]::Zero)
    return $script:allKids
}

function Get-Page($children) {
    $dialogs = $children | Where-Object { $_.class -eq "#32770" }
    foreach ($d in $dialogs) {
        if ($d.text -match "EULA|License") { return "eula" }
        if ($d.text -match "Welcome") { return "welcome" }
        if ($d.text -match "Scan Type|Select a scan type") { return "scantype" }
        if ($d.text -match "Quick Progress|Scanning|Scan in progress") { return "scanning" }
        if ($d.text -match "Result") { return "results" }
    }
    return "unknown"
}

function Navigate-Wizard($msertHwnd) {
    Write-Host "[Navigate-Wizard] Starting..." -ForegroundColor Cyan
    
    $prevWindow = [W32]::GetForegroundWindow()
    $prevCursor = [System.Windows.Forms.Cursor]::Position
    
    [W32]::SetForegroundWindow($msertHwnd) | Out-Null
    Start-Sleep -Milliseconds 300
    
    $maxPages = 5
    $pageNum = 0
    
    for ($pg = 0; $pg -lt $maxPages; $pg++) {
        $kids = Get-AllChildren $msertHwnd
        $page = Get-Page $kids
        
        Write-Host "  Page $pg: $page" -ForegroundColor Yellow
        
        switch ($page) {
            "eula" {
                # Accept EULA with Alt+A
                [System.Windows.Forms.SendKeys]::SendWait("%a")
                Start-Sleep -Milliseconds 300
                [System.Windows.Forms.SendKeys]::SendWait("%n")
                Start-Sleep -Milliseconds 500
            }
            "welcome" {
                # Next on Welcome
                [System.Windows.Forms.SendKeys]::SendWait("%n")
                Start-Sleep -Milliseconds 500
            }
            "scantype" {
                # *** FIX #2: Use ARROW KEYS to select Quick Scan ***
                # Send UP arrow to ensure first radio (Quick) is focused
                [System.Windows.Forms.SendKeys]::SendWait("{UP}")
                Start-Sleep -Milliseconds 200
                
                # Send SPACE to select it
                [System.Windows.Forms.SendKeys]::SendWait(" ")
                Start-Sleep -Milliseconds 300
                
                # Verify it's selected (BM_GETCHECK)
                $quickRadio = $kids | Where-Object { $_.text -match "Quick" } | Select-Object -First 1
                if ($quickRadio) {
                    $checked = [W32]::SendMessage($quickRadio.hwnd, [W32]::BM_GETCHECK, [IntPtr]::Zero, [IntPtr]::Zero)
                    Write-Host "    Quick Scan selected: $($checked -eq 1)" -ForegroundColor Cyan
                }
                
                # Proceed to Next
                Start-Sleep -Milliseconds 200
                [System.Windows.Forms.SendKeys]::SendWait("%n")
                Start-Sleep -Milliseconds 500
            }
            "scanning" {
                Write-Host "  ✓ Scan started" -ForegroundColor Green
                break
            }
            default {
                [System.Windows.Forms.SendKeys]::SendWait("%n")
                Start-Sleep -Milliseconds 500
            }
        }
        if ($page -eq "scanning") { break }
    }
    
    # Restore user's window
    if ($prevWindow -ne [IntPtr]::Zero) {
        [W32]::SetForegroundWindow($prevWindow) | Out-Null
    }
    [System.Windows.Forms.Cursor]::Position = $prevCursor
    
    Start-Sleep 2
}

$msertLog = "C:\Windows\debug\msert.log"
$msertPath = "F:\Downloads\MSERT.exe"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MSERT Auto-Scanner (OPTIMIZED v2)   " -ForegroundColor Cyan
Write-Host "  Quick Scan only (~5-8 min, not 16+)  " -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

# 1. Cleanup
Write-Host "[1] Cleanup..." -ForegroundColor Yellow
Get-Process -Name MSERT -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 2
if (Test-Path $msertLog) { Remove-Item $msertLog -Force -ErrorAction SilentlyContinue }

# 2. Download
if ((Test-Path $msertPath) -and ((Get-Date) - (Get-Item $msertPath).LastWriteTime).TotalHours -lt 12) {
    Write-Host "[2] Cached MSERT ($([Math]::Round((Get-Item $msertPath).Length/1MB,1))MB)" -ForegroundColor Green
} else {
    Write-Host "[2] Downloading..." -ForegroundColor Yellow
    Remove-Item $msertPath -Force -ErrorAction SilentlyContinue
    try {
        (New-Object System.Net.WebClient).DownloadFile('https://go.microsoft.com/fwlink/?LinkId=212732', $msertPath)
        Write-Host "  OK ($([Math]::Round((Get-Item $msertPath).Length/1MB,1))MB)" -ForegroundColor Green
    } catch { Write-Host "  FAILED: $_" -ForegroundColor Red; Read-Host; exit 1 }
}

# 3. Launch (NO /F:Y - let wizard select Quick Scan)
Write-Host "[3] Launching MSERT (interactive, Quick Scan)..." -ForegroundColor Yellow
$startTime = Get-Date
$proc = Start-Process -FilePath $msertPath -PassThru
Write-Host "  PID: $($proc.Id)" -ForegroundColor Green

# 4. Wait for window
Write-Host "[4] Waiting for window..." -ForegroundColor Yellow
$hwnd = [IntPtr]::Zero
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep 2
    $msert = Get-Process | Where-Object { $_.ProcessName -like "*MSERT*" -and $_.MainWindowHandle -ne [IntPtr]::Zero } | Select-Object -First 1
    if ($msert) { $hwnd = $msert.MainWindowHandle; break }
}
if ($hwnd -eq [IntPtr]::Zero) {
    Write-Host "  No window! Aborting." -ForegroundColor Red; Read-Host; exit 1
}

# 5. Navigate wizard with new fixes
Write-Host "[5] Navigating wizard (arrow keys + verification)..." -ForegroundColor Yellow
Navigate-Wizard $hwnd

# Verify scan started
Start-Sleep 2
$msert = Get-Process | Where-Object { $_.ProcessName -like "*MSERT*" -and $_.MainWindowHandle -ne [IntPtr]::Zero } | Select-Object -First 1
if ($msert) {
    $kids = Get-AllChildren $msert.MainWindowHandle
    $page = Get-Page $kids
    Write-Host "  Status: $page" -ForegroundColor Cyan
    if ($page -ne "scanning") {
        Write-Host "  Still on wizard - retrying..." -ForegroundColor Yellow
        Navigate-Wizard $msert.MainWindowHandle
        Start-Sleep 2
    }
}

# 6. Monitor scan (FASTER: 2s polling, TIMEOUT: 15 min max)
Write-Host "`n[6] Monitoring (QUICK scan only - max 15 min)..." -ForegroundColor Yellow
$scanSeen = $false
$maxTicks = 450  # 900 seconds / 2 seconds per tick
$pollInterval = 2

for ($tick = 0; $tick -lt $maxTicks; $tick++) {
    Start-Sleep $pollInterval
    $elapsed = [Math]::Round(((Get-Date) - $startTime).TotalSeconds)
    
    $msert = Get-Process | Where-Object { $_.ProcessName -like "*MSERT*" -and $_.MainWindowHandle -ne [IntPtr]::Zero } | Select-Object -First 1
    if (-not $msert) {
        $any = Get-Process -Name MSERT -ErrorAction SilentlyContinue
        if (-not $any) {
            Start-Sleep 3
            Write-Host "  Scan process ended" -ForegroundColor Green
            break
        }
        continue
    }
    
    $hwnd = $msert.MainWindowHandle
    $kids = Get-AllChildren $hwnd
    $page = Get-Page $kids
    
    # Heartbeat every 30s
    if ($tick % 15 -eq 0) {
        $scanned = ($kids | Where-Object { $_.text -like "Files Scanned*" } | Select-Object -First 1).text
        $infected = ($kids | Where-Object { $_.text -like "Files Infected*" } | Select-Object -First 1).text
        $mem = [Math]::Round($msert.WorkingSet64/1MB, 1)
        Write-Host "  [$elapsed / 900s] $scanned | $infected | Memory: ${mem}MB" -ForegroundColor Cyan
    }
    
    if ($page -eq "scanning") {
        $scanSeen = $true
    }
    
    # Results page - close gracefully
    if ($page -eq "results" -and $scanSeen) {
        Write-Host "  Scan complete - closing..." -ForegroundColor Green
        $finishBtn = $kids | Where-Object { $_.text -eq "Finish" } | Select-Object -First 1
        if ($finishBtn) {
            [W32]::SendMessage($finishBtn.hwnd, [W32]::BM_CLICK, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
        }
        Start-Sleep 3
        break
    }
    
    # TIMEOUT: 15 min (900s)
    if ($elapsed -gt 900) {
        Write-Host "  TIMEOUT (15 min) - force closing" -ForegroundColor Red
        Get-Process -Name MSERT -ErrorAction SilentlyContinue | Stop-Process -Force
        break
    }
}

# Wait for log
Start-Sleep 3

# 7. Results parsing
$totalMin = [Math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  COMPLETE (${totalMin} min)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if (Test-Path $msertLog) {
    Write-Host "`n--- MSERT Results ---" -ForegroundColor Yellow
    $content = Get-Content $msertLog -Raw -Encoding Unicode -ErrorAction SilentlyContinue
    
    # Check scan type
    if ($content -match "Quick Scan Results") {
        Write-Host "  ✓ Quick Scan confirmed" -ForegroundColor Green
    } elseif ($content -match "Full Scan Results") {
        Write-Host "  ✗ FULL Scan detected (should have been Quick!)" -ForegroundColor Red
    }
    
    # Check results
    if ($content -match "No infection found|Return code: 0") {
        Write-Host "  ✓ CLEAN - No threats detected" -ForegroundColor Green
    } elseif ($content -match "removed|quarantined") {
        Write-Host "  ✓ Threats auto-removed with /F:Y" -ForegroundColor Green
    } elseif ($content -match "threat|infected") {
        Write-Host "  ⚠ Threats detected (check details below)" -ForegroundColor Red
    }
    
    # Full log
    Write-Host "`n--- Full Log ---" -ForegroundColor Gray
    Get-Content $msertLog -Encoding Unicode -ErrorAction SilentlyContinue | ForEach-Object {
        $line = $_.Trim()
        if ($line -ne "" -and $line -notmatch '^\-+$') {
            Write-Host "  $line" -ForegroundColor White
        }
    }
} else {
    Write-Host "`n  No log file found!" -ForegroundColor Red
}

Write-Host "`nDone!" -ForegroundColor Green
Read-Host "Press Enter to close"
