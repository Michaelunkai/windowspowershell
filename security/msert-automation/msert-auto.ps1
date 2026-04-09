# MSERT Auto-Scanner - Quick Scan + Auto-Remove + GUI Automation
# FIX: Removed /F:Y flag (was FORCING Full scan and bypassing scan type page)
# Now uses UIAutomation to: accept EULA, click Next, SELECT QUICK SCAN radio, start scan
# Quick scan finishes in ~3-7 min. Full scan = hours. This script does QUICK SCAN.
# Must run as Admin

# Self-elevate if needed
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32Mouse {
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    public const uint MOUSEEVENTF_LEFTUP   = 0x0004;
    public static void Click(int x, int y) {
        SetCursorPos(x, y);
        System.Threading.Thread.Sleep(80);
        mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
        System.Threading.Thread.Sleep(50);
        mouse_event(MOUSEEVENTF_LEFTUP,   0, 0, 0, UIntPtr.Zero);
    }
}
"@

$msertLog  = "C:\Windows\debug\msert.log"
$msertPath = "F:\Downloads\MSERT.exe"
$root      = [System.Windows.Automation.AutomationElement]::RootElement
$allCond   = [System.Windows.Automation.Condition]::TrueCondition

# ── Helpers ────────────────────────────────────────────────────────────────────

function Get-MsertWindow {
    for ($i = 0; $i -lt 25; $i++) {
        $wins = $root.FindAll([System.Windows.Automation.TreeScope]::Children, $allCond)
        $w = $wins | Where-Object { $_.Current.Name -like "*Safety Scanner*" } | Select-Object -First 1
        if ($w) { return $w }
        Start-Sleep 1
    }
    return $null
}

function Get-Elements($win) {
    return $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $allCond)
}

function Click-UIA($el) {
    if (-not $el) { return $false }
    try {
        $el.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
        return $true
    } catch {
        $r = $el.Current.BoundingRectangle
        [Win32Mouse]::Click([int]($r.Left + $r.Width/2), [int]($r.Top + $r.Height/2))
        return $true
    }
}

function Get-PageType($els) {
    $hasCheckbox  = ($els | Where-Object { $_.Current.ControlType.ProgrammaticName -eq "ControlType.CheckBox" } | Select-Object -First 1) -ne $null
    $radioCount   = ($els | Where-Object { $_.Current.ControlType.ProgrammaticName -eq "ControlType.RadioButton" }).Count
    $hasProgress  = ($els | Where-Object { $_.Current.ControlType.ProgrammaticName -eq "ControlType.ProgressBar" } | Select-Object -First 1) -ne $null
    $hasFinish    = ($els | Where-Object { $_.Current.ControlType.ProgrammaticName -eq "ControlType.Button" -and $_.Current.Name -eq "Finish" } | Select-Object -First 1) -ne $null
    $hasLinks     = ($els | Where-Object { $_.Current.ControlType.ProgrammaticName -eq "ControlType.Hyperlink" }).Count -gt 0

    if ($hasCheckbox)         { return "eula" }
    if ($radioCount -gt 0)    { return "scantype" }
    if ($hasProgress)         { return "scanning" }
    if ($hasFinish)           { return "results" }
    if ($hasLinks)            { return "welcome" }
    return "unknown"
}

# ── Main ───────────────────────────────────────────────────────────────────────

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  MSERT Auto-Scanner  |  QUICK Scan + Remove" -ForegroundColor Cyan
Write-Host "  Typical finish time: 3–7 minutes" -ForegroundColor Gray
Write-Host "============================================`n" -ForegroundColor Cyan

# 1. Cleanup
Write-Host "[1] Cleanup..." -ForegroundColor Yellow
Get-Process -Name MSERT -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 2
Remove-Item $msertLog -Force -ErrorAction SilentlyContinue

# 2. Download / cache check
if ((Test-Path $msertPath) -and ((Get-Date) - (Get-Item $msertPath).LastWriteTime).TotalHours -lt 12) {
    Write-Host "[2] Cached MSERT ($([Math]::Round((Get-Item $msertPath).Length/1MB,1)) MB)" -ForegroundColor Green
} else {
    Write-Host "[2] Downloading latest MSERT..." -ForegroundColor Yellow
    Remove-Item $msertPath -Force -ErrorAction SilentlyContinue
    try {
        (New-Object System.Net.WebClient).DownloadFile('https://go.microsoft.com/fwlink/?LinkId=212732', $msertPath)
        Write-Host "  Downloaded ($([Math]::Round((Get-Item $msertPath).Length/1MB,1)) MB)" -ForegroundColor Green
    } catch {
        Write-Host "  Download FAILED: $_" -ForegroundColor Red; Read-Host; exit 1
    }
}

# 3. Launch — NO /F:Y FLAG (that flag forces Full scan and skips scan-type page!)
Write-Host "[3] Launching MSERT (no /F:Y — Quick scan mode)..." -ForegroundColor Yellow
$startTime = Get-Date
$proc = Start-Process -FilePath $msertPath -PassThru -Verb RunAs
Write-Host "  PID: $($proc.Id)" -ForegroundColor Green

# 4. Wait for window
Write-Host "[4] Waiting for MSERT window..." -ForegroundColor Yellow
$win = Get-MsertWindow
if (-not $win) { Write-Host "  Window never appeared. Aborting." -ForegroundColor Red; Read-Host; exit 1 }
Write-Host "  Window ready." -ForegroundColor Green

# 5. Wizard navigation via UIAutomation
Write-Host "[5] Auto-navigating wizard..." -ForegroundColor Yellow

for ($step = 0; $step -lt 15; $step++) {
    $win = Get-MsertWindow
    if (-not $win) { break }
    $els = Get-Elements $win
    $page = Get-PageType $els
    Write-Host "  Page detected: $page" -ForegroundColor Cyan

    switch ($page) {
        "eula" {
            $cb = $els | Where-Object { $_.Current.ControlType.ProgrammaticName -eq "ControlType.CheckBox" } | Select-Object -First 1
            if ($cb) {
                $tp = $cb.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
                if ($tp.Current.ToggleState -ne "On") { $tp.Toggle() }
                Write-Host "    EULA checkbox accepted." -ForegroundColor Green
            }
            Start-Sleep -Milliseconds 500
            $next = $els | Where-Object { $_.Current.ControlType.ProgrammaticName -eq "ControlType.Button" -and $_.Current.Name -eq "Next >" } | Select-Object -First 1
            Click-UIA $next | Out-Null
            Start-Sleep 1
        }
        "welcome" {
            $next = $els | Where-Object { $_.Current.ControlType.ProgrammaticName -eq "ControlType.Button" -and $_.Current.Name -eq "Next >" } | Select-Object -First 1
            Click-UIA $next | Out-Null
            Start-Sleep 1
        }
        "scantype" {
            # KEY FIX: explicitly select Quick scan radio button
            $quickRadio = $els | Where-Object {
                $_.Current.ControlType.ProgrammaticName -eq "ControlType.RadioButton" -and
                $_.Current.Name -like "*Quick scan*"
            } | Select-Object -First 1

            if ($quickRadio) {
                try {
                    $quickRadio.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern).Select()
                } catch {
                    $r = $quickRadio.Current.BoundingRectangle
                    [Win32Mouse]::Click([int]($r.Left + $r.Width/2), [int]($r.Top + $r.Height/2))
                }
                Write-Host "    Quick scan selected!" -ForegroundColor Green
            } else {
                Write-Host "    Quick scan radio not found — proceeding with default." -ForegroundColor Yellow
            }
            Start-Sleep -Milliseconds 600

            $next = $els | Where-Object { $_.Current.ControlType.ProgrammaticName -eq "ControlType.Button" -and $_.Current.Name -eq "Next >" } | Select-Object -First 1
            Click-UIA $next | Out-Null
            Start-Sleep 2
        }
        "scanning" {
            Write-Host "    Scan is running!" -ForegroundColor Green
            break
        }
        "results" {
            Write-Host "    Already on results page." -ForegroundColor Yellow
            break
        }
        default {
            # Unknown page — try Next anyway
            $next = $els | Where-Object { $_.Current.ControlType.ProgrammaticName -eq "ControlType.Button" -and $_.Current.Name -eq "Next >" } | Select-Object -First 1
            if ($next) { Click-UIA $next | Out-Null; Start-Sleep 1 } else { break }
        }
    }
    if ($page -in @("scanning","results")) { break }
}

# 6. Monitor scan progress
Write-Host "`n[6] Monitoring Quick scan..." -ForegroundColor Yellow
$lastLine  = ""
$scanSeen  = $false

for ($tick = 0; $tick -lt 360; $tick++) {   # max 30 min safety net
    Start-Sleep 5
    $elapsed    = [int]((Get-Date) - $startTime).TotalSeconds
    $elapsedMin = [Math]::Round($elapsed / 60, 1)

    # --- check if process is gone ---
    $anyProc = Get-Process -Name MSERT -ErrorAction SilentlyContinue
    $wins    = $root.FindAll([System.Windows.Automation.TreeScope]::Children, $allCond)
    $win     = $wins | Where-Object { $_.Current.Name -like "*Safety Scanner*" } | Select-Object -First 1

    if (-not $win -and -not $anyProc) {
        Write-Host "  Process exited at $elapsedMin min." -ForegroundColor Green
        break
    }
    if (-not $win) { continue }

    $els  = Get-Elements $win
    $page = Get-PageType $els

    if ($page -eq "scanning") {
        $scanSeen = $true
        $txts   = $els | Where-Object { $_.Current.ControlType.ProgrammaticName -eq "ControlType.Text" -and $_.Current.Name }
        $scanned  = ($txts | Where-Object { $_.Current.Name -like "Files Scanned*"  } | Select-Object -First 1)?.Current.Name
        $infected = ($txts | Where-Object { $_.Current.Name -like "Files Infected*" } | Select-Object -First 1)?.Current.Name
        $timeEl   = ($txts | Where-Object { $_.Current.Name -like "Time elapsed*"   } | Select-Object -First 1)?.Current.Name
        $curFile  = ($txts | Where-Object { $_.Current.Name -like "*:\\*"           } | Select-Object -First 1)?.Current.Name

        $line = "[$elapsedMin min] $scanned | $infected | $timeEl"
        if ($line -ne $lastLine) {
            Write-Host "  $line" -ForegroundColor Yellow
            if ($curFile) { Write-Host "    > $curFile" -ForegroundColor DarkGray }
            $lastLine = $line
        }
    }

    if ($page -eq "results" -and $scanSeen) {
        Write-Host "`n  *** SCAN COMPLETE at $elapsedMin min! ***" -ForegroundColor Green

        # Print results text
        $txts = $els | Where-Object { $_.Current.ControlType.ProgrammaticName -eq "ControlType.Text" -and $_.Current.Name }
        foreach ($t in $txts) {
            if ($t.Current.Name.Length -lt 300 -and $t.Current.Name.Trim()) {
                Write-Host "  $($t.Current.Name)" -ForegroundColor White
            }
        }

        # Click Finish
        $finish = $els | Where-Object { $_.Current.ControlType.ProgrammaticName -eq "ControlType.Button" -and $_.Current.Name -eq "Finish" } | Select-Object -First 1
        if ($finish) { Click-UIA $finish | Out-Null; Write-Host "  Clicked Finish." -ForegroundColor Green }
        Start-Sleep 3
        break
    }
}

# 7. Parse log & show results
Start-Sleep 3
$totalMin = [Math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "  DONE  |  Total time: $totalMin min" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

if (Test-Path $msertLog) {
    Write-Host "`n--- MSERT Log ---" -ForegroundColor Yellow
    $raw = Get-Content $msertLog -Raw -Encoding Unicode -ErrorAction SilentlyContinue
    if (-not $raw) { $raw = Get-Content $msertLog -Raw -ErrorAction SilentlyContinue }

    ($raw -split "`n") | Where-Object { $_.Trim() -and $_ -notmatch "^-+$" } | ForEach-Object {
        $line = $_.Trim()
        if     ($line -match "threat|infected|removed" -and $line -notmatch "No infection") { Write-Host "  $line" -ForegroundColor Red }
        elseif ($line -match "No infection|Return code: 0")                                  { Write-Host "  $line" -ForegroundColor Green }
        else                                                                                  { Write-Host "  $line" -ForegroundColor White }
    }

    if      ($raw -match "No infection found") { Write-Host "`n  RESULT: SYSTEM CLEAN" -ForegroundColor Green }
    elseif  ($raw -match "removed")            { Write-Host "`n  RESULT: THREATS AUTO-REMOVED" -ForegroundColor Green }
    elseif  ($raw -match "infection")          { Write-Host "`n  RESULT: THREATS DETECTED — check log" -ForegroundColor Red }
    else                                       { Write-Host "`n  RESULT: See log above" -ForegroundColor Yellow }
} else {
    Write-Host "`n  No log file found." -ForegroundColor Yellow
}

Write-Host "`nPress Enter to close..."
Read-Host
