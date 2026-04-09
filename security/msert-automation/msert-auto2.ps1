# MSERT Auto-Scanner - QUICK Scan + Auto-Remove + Non-Intrusive
# Wizard: brief keyboard input (~2s), then fully background monitoring
# Saves/restores mouse position, doesn't block other apps
# Must run as Admin

# Self-elevate
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
    public delegate bool CallBack(IntPtr h, IntPtr l);
    public const uint BM_CLICK = 0x00F5;
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
        if ($d.text -match "EULA") { return "eula" }
        if ($d.text -match "Welcome") { return "welcome" }
        if ($d.text -match "Scan Type") { return "scantype" }
        if ($d.text -match "Quick Progress") { return "scanning" }
        if ($d.text -match "Result") { return "results" }
    }
    return "unknown"
}

# Brief wizard automation: steal focus for ~2s, send keys, restore
function Navigate-Wizard($msertHwnd) {
    # Save what user was doing
    $prevWindow = [W32]::GetForegroundWindow()
    $prevCursor = [System.Windows.Forms.Cursor]::Position
    
    # Bring MSERT to front briefly
    [W32]::SetForegroundWindow($msertHwnd) | Out-Null
    Start-Sleep -Milliseconds 300
    
    # Navigate all wizard pages with keyboard accelerators
    # Alt+A = &Accept EULA checkbox, Alt+N = &Next
    $maxPages = 5
    for ($pg = 0; $pg -lt $maxPages; $pg++) {
        $kids = Get-AllChildren $msertHwnd
        $page = Get-Page $kids
        
        switch ($page) {
            "eula" {
                [System.Windows.Forms.SendKeys]::SendWait("%a")  # Alt+A = Accept
                Start-Sleep -Milliseconds 300
                [System.Windows.Forms.SendKeys]::SendWait("%n")  # Alt+N = Next
                Start-Sleep -Milliseconds 500
            }
            "welcome" {
                [System.Windows.Forms.SendKeys]::SendWait("%n")
                Start-Sleep -Milliseconds 500
            }
            "scantype" {
                # Quick scan is default (first radio). Just hit Next.
                [System.Windows.Forms.SendKeys]::SendWait("%n")
                Start-Sleep -Milliseconds 500
            }
            "scanning" {
                break  # Scan started, we're done with wizard
            }
            default {
                [System.Windows.Forms.SendKeys]::SendWait("%n")
                Start-Sleep -Milliseconds 500
            }
        }
        if ($page -eq "scanning") { break }
    }
    
    # Restore user's previous window and cursor immediately
    if ($prevWindow -ne [IntPtr]::Zero) {
        [W32]::SetForegroundWindow($prevWindow) | Out-Null
    }
    [System.Windows.Forms.Cursor]::Position = $prevCursor
}

$msertLog = "C:\Windows\debug\msert.log"
$msertPath = "F:\Downloads\MSERT.exe"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MSERT Auto-Scanner (QUICK + Remove)  " -ForegroundColor Cyan
Write-Host "  Non-intrusive: ~2s wizard, then background" -ForegroundColor Gray
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

# 3. Launch
Write-Host "[3] Launching MSERT (/F:Y = auto-remove threats)..." -ForegroundColor Yellow
$startTime = Get-Date
$proc = Start-Process -FilePath $msertPath -ArgumentList "/F:Y" -PassThru
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

# 5. Navigate wizard (~2s of keyboard, then restore focus)
Write-Host "[5] Navigating wizard (brief focus steal ~2s)..." -ForegroundColor Yellow
Navigate-Wizard $hwnd

# Verify scan started
Start-Sleep 2
$msert = Get-Process | Where-Object { $_.ProcessName -like "*MSERT*" -and $_.MainWindowHandle -ne [IntPtr]::Zero } | Select-Object -First 1
if ($msert) {
    $kids = Get-AllChildren $msert.MainWindowHandle
    $page = Get-Page $kids
    Write-Host "  Status: $page" -ForegroundColor Cyan
    if ($page -ne "scanning") {
        Write-Host "  Retrying wizard navigation..." -ForegroundColor Yellow
        Navigate-Wizard $msert.MainWindowHandle
        Start-Sleep 2
        $kids = Get-AllChildren $msert.MainWindowHandle
        $page = Get-Page $kids
        Write-Host "  Status: $page" -ForegroundColor Cyan
    }
} else {
    Write-Host "  MSERT closed unexpectedly" -ForegroundColor Red
}

# 6. Monitor scan - FULLY BACKGROUND, no focus stealing
Write-Host "`n[6] Monitoring (background - won't touch your mouse/keyboard)..." -ForegroundColor Yellow
$scanSeen = $false

for ($tick = 0; $tick -lt 1440; $tick++) {
    Start-Sleep 5
    $elapsed = [Math]::Round(((Get-Date) - $startTime).TotalSeconds)
    
    $msert = Get-Process | Where-Object { $_.ProcessName -like "*MSERT*" -and $_.MainWindowHandle -ne [IntPtr]::Zero } | Select-Object -First 1
    if (-not $msert) {
        $any = Get-Process -Name MSERT -ErrorAction SilentlyContinue
        if (-not $any) {
            # Wait a moment for log to flush
            Start-Sleep 3
            Write-Host "  Scan process ended" -ForegroundColor Green
            break
        }
        continue
    }
    
    $hwnd = $msert.MainWindowHandle
    $kids = Get-AllChildren $hwnd
    $page = Get-Page $kids
    
    if ($page -eq "scanning") {
        $scanSeen = $true
        if ($tick % 3 -eq 0) {
            $scanned = ($kids | Where-Object { $_.text -like "Files Scanned*" } | Select-Object -First 1).text
            $infected = ($kids | Where-Object { $_.text -like "Files Infected*" } | Select-Object -First 1).text
            $timeEl = ($kids | Where-Object { $_.text -like "Time elapsed*" } | Select-Object -First 1).text
            $curFile = ($kids | Where-Object { $_.text -like "*:\*" -and $_.class -eq "Static" } | Select-Object -First 1).text
            $mem = [Math]::Round($msert.WorkingSet64/1MB, 1)
            if ($scanned) { Write-Host "  $scanned | $infected | $timeEl | ${mem}MB" -ForegroundColor Yellow }
            if ($curFile) { Write-Host "    $curFile" -ForegroundColor Gray }
        }
    }
    
    if ($page -eq "results" -and $scanSeen) {
        Write-Host "  Scan complete! Closing..." -ForegroundColor Green
        # Click Finish via PostMessage (background, no focus steal)
        $finishBtn = $kids | Where-Object { $_.text -eq "Finish" } | Select-Object -First 1
        if ($finishBtn) {
            [W32]::PostMessage($finishBtn.hwnd, [W32]::BM_CLICK, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
        }
        Start-Sleep 3
        break
    }
    
    if ($elapsed -gt 7200) {
        Write-Host "  TIMEOUT!" -ForegroundColor Red
        Get-Process -Name MSERT -ErrorAction SilentlyContinue | Stop-Process -Force
        break
    }
}

# Wait for log to be written
Start-Sleep 3

# 7. Results
$totalMin = [Math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  COMPLETE (${totalMin} min)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if (Test-Path $msertLog) {
    Write-Host "`n--- MSERT Log ---" -ForegroundColor Yellow
    Get-Content $msertLog -Encoding Unicode -ErrorAction SilentlyContinue | ForEach-Object {
        $line = $_.Trim()
        if ($line -ne "" -and $line -notmatch '^\-+$') {
            if ($line -match "threat|infected" -and $line -notmatch "No infection") {
                Write-Host "  $line" -ForegroundColor Red
            } elseif ($line -match "No infection|Return code: 0") {
                Write-Host "  $line" -ForegroundColor Green
            } else {
                Write-Host "  $line" -ForegroundColor White
            }
        }
    }
    $content = Get-Content $msertLog -Raw -Encoding Unicode -ErrorAction SilentlyContinue
    if ($content -match "No infection found") { Write-Host "`n  RESULT: CLEAN" -ForegroundColor Green }
    elseif ($content -match "removed") { Write-Host "`n  RESULT: THREATS AUTO-REMOVED" -ForegroundColor Green }
    elseif ($content -match "infection") { Write-Host "`n  RESULT: THREATS DETECTED" -ForegroundColor Red }
    else { Write-Host "`n  RESULT: Check log above" -ForegroundColor Yellow }
} else {
    Write-Host "`n  No log file" -ForegroundColor Red
}

Write-Host "`nDone!" -ForegroundColor Green
Read-Host "Press Enter to close"
