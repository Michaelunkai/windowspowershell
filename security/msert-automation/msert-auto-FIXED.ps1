# MSERT Auto-Scan with AUTO-CLICKS (Fixed Edition)
# Auto-navigates wizard + auto-clicks buttons
# FIXES: Remove /F:Y, verify Quick Scan selected, faster polling, 15min timeout
# Expected: 5-8 minutes (NOT 16+)

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

# AUTO-CLICK Wizard Navigation
function Navigate-Wizard($msertHwnd) {
    Write-Host "[Navigate-Wizard] Starting auto-clicks..." -ForegroundColor Cyan
    
    $prevWindow = [W32]::GetForegroundWindow()
    $prevCursor = [System.Windows.Forms.Cursor]::Position
    
    [W32]::SetForegroundWindow($msertHwnd) | Out-Null
    Start-Sleep -Milliseconds 500
    
    $maxPages = 5
    
    for ($pg = 0; $pg -lt $maxPages; $pg++) {
        $kids = Get-AllChildren $msertHwnd
        $page = Get-Page $kids
        
        Write-Host "  Page $($pg): $($page)" -ForegroundColor Yellow
        
        if ($page -eq "eula") {
            Write-Host "    Clicking Accept..." -ForegroundColor Gray
            [System.Windows.Forms.SendKeys]::SendWait("%a")
            Start-Sleep -Milliseconds 300
            [System.Windows.Forms.SendKeys]::SendWait("%n")
            Start-Sleep -Milliseconds 500
        }
        elseif ($page -eq "welcome") {
            Write-Host "    Clicking Next..." -ForegroundColor Gray
            [System.Windows.Forms.SendKeys]::SendWait("%n")
            Start-Sleep -Milliseconds 500
        }
        elseif ($page -eq "scantype") {
            Write-Host "    Selecting Quick Scan (auto-click)..." -ForegroundColor Cyan
            
            $quickRadio = $kids | Where-Object { $_.text -match "Quick" -and $_.class -match "Button" } | Select-Object -First 1
            
            if ($quickRadio) {
                Write-Host "      Found Quick radio" -ForegroundColor Gray
                [W32]::SendMessage($quickRadio.hwnd, [W32]::BM_CLICK, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
                Start-Sleep -Milliseconds 200
                
                $checked = [W32]::SendMessage($quickRadio.hwnd, [W32]::BM_GETCHECK, [IntPtr]::Zero, [IntPtr]::Zero)
                if ($checked -eq 1) {
                    Write-Host "      SELECTED" -ForegroundColor Green
                }
                else {
                    Write-Host "      Retrying..." -ForegroundColor Yellow
                    [System.Windows.Forms.SendKeys]::SendWait("{UP}")
                    Start-Sleep -Milliseconds 200
                    [System.Windows.Forms.SendKeys]::SendWait(" ")
                    Start-Sleep -Milliseconds 300
                }
            }
            else {
                [System.Windows.Forms.SendKeys]::SendWait("{UP}")
                Start-Sleep -Milliseconds 200
                [System.Windows.Forms.SendKeys]::SendWait(" ")
                Start-Sleep -Milliseconds 300
            }
            
            Write-Host "    Clicking Next to start scan..." -ForegroundColor Gray
            Start-Sleep -Milliseconds 200
            [System.Windows.Forms.SendKeys]::SendWait("%n")
            Start-Sleep -Milliseconds 700
        }
        elseif ($page -eq "scanning") {
            Write-Host "  SCAN STARTED" -ForegroundColor Green
            break
        }
        else {
            [System.Windows.Forms.SendKeys]::SendWait("%n")
            Start-Sleep -Milliseconds 500
        }
        
        if ($page -eq "scanning") { break }
    }
    
    if ($prevWindow -ne [IntPtr]::Zero) {
        [W32]::SetForegroundWindow($prevWindow) | Out-Null
    }
    [System.Windows.Forms.Cursor]::Position = $prevCursor
    
    Start-Sleep -Milliseconds 2000
}

$msertLog = "C:\Windows\debug\msert.log"
$msertPath = "F:\Downloads\MSERT.exe"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MSERT Auto-Scan (FIXED Edition)     " -ForegroundColor Cyan
Write-Host "  Auto-clicks + Quick Scan only        " -ForegroundColor Green
Write-Host "  Expected: 5-8 minutes (not 16+)     " -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

# 1. Cleanup
Write-Host "[1] Cleanup..." -ForegroundColor Yellow
Get-Process -Name MSERT -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 2000
if (Test-Path $msertLog) { Remove-Item $msertLog -Force -ErrorAction SilentlyContinue }

# 2. Download MSERT
if ((Test-Path $msertPath) -and ((Get-Date) - (Get-Item $msertPath).LastWriteTime).TotalHours -lt 12) {
    Write-Host "[2] Cached MSERT ($([Math]::Round((Get-Item $msertPath).Length/1MB,1))MB)" -ForegroundColor Green
}
else {
    Write-Host "[2] Downloading MSERT..." -ForegroundColor Yellow
    Remove-Item $msertPath -Force -ErrorAction SilentlyContinue
    try {
        (New-Object System.Net.WebClient).DownloadFile('https://go.microsoft.com/fwlink/?LinkId=212732', $msertPath)
        Write-Host "  OK ($([Math]::Round((Get-Item $msertPath).Length/1MB,1))MB)" -ForegroundColor Green
    }
    catch {
        Write-Host "  FAILED: $_" -ForegroundColor Red
        Read-Host "Press Enter"
        exit 1
    }
}

# 3. Launch MSERT (NO /F:Y - let wizard select Quick)
Write-Host "[3] Launching MSERT..." -ForegroundColor Yellow
$startTime = Get-Date
$proc = Start-Process -FilePath $msertPath -PassThru
Write-Host "  PID: $($proc.Id)" -ForegroundColor Green

# 4. Wait for window
Write-Host "[4] Waiting for window..." -ForegroundColor Yellow
$hwnd = [IntPtr]::Zero
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Milliseconds 1000
    $msert = Get-Process | Where-Object { $_.ProcessName -like "*MSERT*" -and $_.MainWindowHandle -ne [IntPtr]::Zero } | Select-Object -First 1
    if ($msert) { $hwnd = $msert.MainWindowHandle; break }
}

if ($hwnd -eq [IntPtr]::Zero) {
    Write-Host "  ERROR: Window not found!" -ForegroundColor Red
    Read-Host "Press Enter"
    exit 1
}
Write-Host "  FOUND" -ForegroundColor Green

# 5. Navigate wizard with auto-clicks
Write-Host "[5] Auto-clicking wizard..." -ForegroundColor Yellow
Navigate-Wizard $hwnd

# Verify scan started
Start-Sleep -Milliseconds 3000
$msert = Get-Process | Where-Object { $_.ProcessName -like "*MSERT*" -and $_.MainWindowHandle -ne [IntPtr]::Zero } | Select-Object -First 1
if ($msert) {
    $kids = Get-AllChildren $msert.MainWindowHandle
    $page = Get-Page $kids
    Write-Host "  Status: $page" -ForegroundColor Cyan
    if ($page -ne "scanning") {
        Write-Host "  RETRY..." -ForegroundColor Yellow
        Navigate-Wizard $msert.MainWindowHandle
        Start-Sleep -Milliseconds 3000
    }
}

# 6. Monitor scan (FASTER: 2s polling, TIMEOUT: 15 min)
Write-Host "`n[6] Monitoring scan (max 15 min)..." -ForegroundColor Yellow
$scanSeen = $false
$pollInterval = 2
$maxTicks = 450

for ($tick = 0; $tick -lt $maxTicks; $tick++) {
    Start-Sleep -Milliseconds ($pollInterval * 1000)
    $elapsed = [Math]::Round(((Get-Date) - $startTime).TotalSeconds)
    
    $msert = Get-Process | Where-Object { $_.ProcessName -like "*MSERT*" -and $_.MainWindowHandle -ne [IntPtr]::Zero } | Select-Object -First 1
    if (-not $msert) {
        $any = Get-Process -Name MSERT -ErrorAction SilentlyContinue
        if (-not $any) {
            Start-Sleep -Milliseconds 3000
            Write-Host "  Process ended" -ForegroundColor Green
            break
        }
        continue
    }
    
    $hwnd = $msert.MainWindowHandle
    $kids = Get-AllChildren $hwnd
    $page = Get-Page $kids
    
    if ($tick % 15 -eq 0) {
        $scanned = ($kids | Where-Object { $_.text -like "Files Scanned*" } | Select-Object -First 1).text
        $infected = ($kids | Where-Object { $_.text -like "Files Infected*" } | Select-Object -First 1).text
        $mem = [Math]::Round($msert.WorkingSet64/1MB, 1)
        if ($scanned) {
            Write-Host "  [$elapsed/900s] $scanned | $infected | ${mem}MB" -ForegroundColor Cyan
        }
    }
    
    if ($page -eq "scanning") {
        $scanSeen = $true
    }
    
    if ($page -eq "results" -and $scanSeen) {
        Write-Host "  Complete - auto-clicking Finish..." -ForegroundColor Green
        $finishBtn = $kids | Where-Object { $_.text -eq "Finish" } | Select-Object -First 1
        if ($finishBtn) {
            [W32]::SendMessage($finishBtn.hwnd, [W32]::BM_CLICK, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
        }
        Start-Sleep -Milliseconds 3000
        break
    }
    
    if ($elapsed -gt 900) {
        Write-Host "  TIMEOUT" -ForegroundColor Red
        Get-Process -Name MSERT -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        break
    }
}

Start-Sleep -Milliseconds 3000

# 7. Results
$totalMin = [Math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  COMPLETE (${totalMin} min)" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

if (Test-Path $msertLog) {
    Write-Host "`n--- Results ---" -ForegroundColor Yellow
    $content = Get-Content $msertLog -Raw -Encoding Unicode -ErrorAction SilentlyContinue
    
    if ($content -match "Quick Scan Results") {
        Write-Host "  Quick Scan confirmed" -ForegroundColor Green
    }
    elseif ($content -match "Full Scan Results") {
        Write-Host "  FULL Scan detected!" -ForegroundColor Red
    }
    
    if ($content -match "No infection found") {
        Write-Host "  CLEAN" -ForegroundColor Green
    }
    elseif ($content -match "removed") {
        Write-Host "  Threats removed" -ForegroundColor Green
    }
    elseif ($content -match "threat") {
        Write-Host "  Threats found" -ForegroundColor Red
    }
    
    Write-Host "`n--- Log (first 30 lines) ---" -ForegroundColor Gray
    Get-Content $msertLog -Encoding Unicode -ErrorAction SilentlyContinue | Select-Object -First 30 | ForEach-Object {
        $line = $_.Trim()
        if ($line -ne "") { Write-Host "  $line" -ForegroundColor White }
    }
}
else {
    Write-Host "`n  No log file" -ForegroundColor Red
}

Write-Host "`nDone!" -ForegroundColor Green
Read-Host "Press Enter"
