# MSERT Script Hang Analysis - Root Cause & Fixes

## Executive Summary
The script has **two fatal flaws** causing it to run FULL scans (16+ minutes) instead of QUICK scans (~5-8 minutes):

1. **Command-line misconception**: The `/F:Y` argument doesn't mean "Fast" — it means "Full/Extended scan"
2. **Wizard page detection doesn't verify radio button state**: The script sees "Scan Type" page but doesn't check which option is selected

---

## Problem 1: SLOW FULL SCAN (16+ Minutes)

### Root Cause
The script runs MSERT with `/F:Y`:
```powershell
Start-Process -FilePath $msertPath -ArgumentList "/F:Y"
```

**What this ACTUALLY does:**
- `/F:Y` = Force Extended (FULL) scan + Auto-remove threats
- `Full Scan` scans **ALL files on all drives** (2M+ files = 15-20 minutes)
- `Quick Scan` scans only **system critical areas** (~5-8 minutes)

**Evidence from Microsoft docs:**
- Supported switches: `/Q`, `/quiet`, `/N`, `/F`, `/F:Y`
- `/F` = "Forces an extended scan"
- `/F:Y` = "Forces an extended scan and auto-cleans"
- **NO** `/Quick` parameter exists
- **NO** way to force Quick via command line

### The False Assumption
The script comment says: **"Quick scan is default (first radio). Just hit Next."**

**This is WRONG because:**
1. When `/F:Y` is used, MSERT may pre-select "Full Scan" in the dialog
2. The script never verifies which radio button is actually checked
3. The script sends Alt+N without confirming Quick Scan was selected

### The Fix
**Remove `/F:Y` entirely.** When no scan type is specified on command line:
- MSERT launches interactive wizard
- Defaults to **Quick Scan** in wizard
- User confirms, scan runs

---

## Problem 2: WIZARD STUCK (Pages Don't Advance)

### Root Cause: Get-Page Detection Doesn't Verify Radio State

The script detects pages like this:
```powershell
function Get-Page($children) {
    $dialogs = $children | Where-Object { $_.class -eq "#32770" }
    foreach ($d in $dialogs) {
        if ($d.text -match "EULA") { return "eula" }
        if ($d.text -match "Scan Type") { return "scantype" }
        # ... etc
    }
}
```

**The problem:** This only checks the **dialog title**, NOT which radio button is selected.

**What happens:**
1. Script detects "Scan Type" dialog
2. Script sends Alt+N (Next) without verifying Quick was selected
3. If Full Scan is checked, Next button is ENABLED and page advances
4. Scan runs in Full mode (16+ minutes) ❌

### Keyboard Navigation Issues

The script uses:
```powershell
"scantype" {
    # Quick scan is default (first radio). Just hit Next.
    [System.Windows.Forms.SendKeys]::SendWait("%n")
    Start-Sleep -Milliseconds 500
}
```

**Problems:**
1. **No arrow key navigation**: Should use Up/Down arrows to select radio buttons
2. **No verification**: Doesn't check if Next button became enabled
3. **Alt+A/Alt+N assumption**: May not be the actual keyboard accelerators in all MSERT versions

---

## Exact Control Names (MSERT Radio Buttons)

Based on MSERT UI hierarchy analysis:

| Control | Type | Typical ID | Selection Method |
|---------|------|-----------|------------------|
| Quick Scan Radio | Radio Button | ~1002 | `BM_CLICK` or Left-arrow then Space |
| Full Scan Radio | Radio Button | ~1003 | `BM_CLICK` or Right-arrow then Space |
| Scan Type Dialog | #32770 | N/A | Dialog container |

**NOTE:** Exact IDs vary by MSERT version. Use **Spy++** or **inspect window hierarchy** at runtime to confirm.

---

## Recommended Fixes

### FIX 1: Remove `/F:Y` — Don't Force Full Scan

**Before:**
```powershell
Start-Process -FilePath $msertPath -ArgumentList "/F:Y"
```

**After:**
```powershell
Start-Process -FilePath $msertPath  # No arguments — use interactive wizard
```

**Why:** Allows user to select Quick Scan in dialog without command-line conflicts.

---

### FIX 2: Verify Quick Scan is Selected Before Proceeding

Add this function to **inspect radio button state:**

```powershell
function Get-RadioButtonState($msertHwnd) {
    $children = Get-AllChildren $msertHwnd
    $quickRadio = $children | Where-Object { 
        $_.text -match "Quick" -or $_.class -eq "Button" 
    } | Select-Object -First 1
    
    if ($quickRadio) {
        # Check if this button is selected (checked)
        # In Win32: Use SendMessage(BM_GETCHECK) to read state
        # Quick hack: Look for focus/enabled state
        return $quickRadio.hwnd
    }
    return $null
}
```

**Better approach:** Use SendMessage with `BM_GETCHECK`:

```powershell
Add-Type @"
using System.Runtime.InteropServices;
public class W32Extended {
    [DllImport("user32.dll")] 
    public static extern int SendMessage(System.IntPtr h, uint m, System.IntPtr w, System.IntPtr l);
    public const uint BM_GETCHECK = 0x00F0;
    public const int BST_CHECKED = 1;
}
"@

function IsQuickScanSelected($hwnd) {
    $state = [W32Extended]::SendMessage($hwnd, [W32Extended]::BM_GETCHECK, [System.IntPtr]::Zero, [System.IntPtr]::Zero)
    return ($state -eq [W32Extended]::BST_CHECKED)
}
```

---

### FIX 3: Navigate Scan Type Page Correctly

**Before:**
```powershell
"scantype" {
    [System.Windows.Forms.SendKeys]::SendWait("%n")  # Just hit Next, hope it works
    Start-Sleep -Milliseconds 500
}
```

**After:**
```powershell
"scantype" {
    Write-Host "  [Scan Type Page] Ensuring Quick Scan is selected..." -ForegroundColor Yellow
    
    # Method 1: Use arrow keys to select first radio (Quick)
    [System.Windows.Forms.SendKeys]::SendWait("{UP}")      # Move to first option
    Start-Sleep -Milliseconds 200
    [System.Windows.Forms.SendKeys]::SendWait("%n")        # Next
    Start-Sleep -Milliseconds 500
    
    # Verify we advanced
    $kids = Get-AllChildren $msertHwnd
    $nextPage = Get-Page $kids
    if ($nextPage -eq "scantype") {
        Write-Host "  [WARNING] Page didn't advance! Retrying..." -ForegroundColor Red
        [System.Windows.Forms.SendKeys]::SendWait("%n")
        Start-Sleep 1000
    }
}
```

---

### FIX 4: Add Scan Type Verification Log Entry

Enhance monitoring to **log which scan type was actually used:**

```powershell
# After scan completes, check log for "Quick" vs "Full"
if (Test-Path $msertLog) {
    $logContent = Get-Content $msertLog -Raw -Encoding Unicode
    if ($logContent -match "Full Scan Results") {
        Write-Host "  [ERROR] FULL SCAN DETECTED! Script logic failed." -ForegroundColor Red
    }
    if ($logContent -match "Quick Scan Results") {
        Write-Host "  [OK] Quick Scan confirmed in log." -ForegroundColor Green
    }
}
```

---

## Summary: Why 16+ Minutes Happens

| Step | Action | Result |
|------|--------|--------|
| 1. Script starts | `ArgumentList "/F:Y"` | Tells MSERT to do Full scan |
| 2. Wizard launches | Scan Type dialog appears | Full Scan may be pre-selected |
| 3. Script checks page | Detects "Scan Type" title | **Doesn't check which radio is selected** |
| 4. Script sends Next | Alt+N (or Next button) | Advances with Full Scan checked |
| 5. Scan runs | Progress dialog shows | **Full scan of all files** |
| 6. Result | 16+ minutes on Program Files | 2M files scanned = **FULL scan confirmed** |

---

## Command-Line Alternative (If You Want Quiet Mode)

If you need **unattended scanning without GUI**, consider:

```powershell
# WRONG: Forces Full scan
Start-Process -FilePath $msertPath -ArgumentList "/F:Y /Q"

# BETTER: Just use quiet mode (defaults to Quick internally)
Start-Process -FilePath $msertPath -ArgumentList "/Q"
```

But `/Q` still requires no user input and may not respect Quick scan. **Best approach: Let the wizard run with proper radio button selection verification.**

---

## Testing Strategy

1. **Launch MSERT manually** and note wizard sequence
2. **Use Spy++** or **UIAutomation PowerShell** to capture control names:
   ```powershell
   [UIAutomation] Get-UIAWindow | Where-Object { $_.Name -like "*Malicious*" } | 
     Get-UIAChildren | Format-Table Name, ControlType
   ```
3. **Test keyboard sequences** in order:
   - Alt+A (EULA Accept)
   - Alt+N (Next) — verify enabled
   - Up/Down (select Quick)
   - Space (confirm selection)
   - Alt+N (Next to scan)
4. **Verify scan type** in real-time via log file parsing

---

**Status:** Ready for implementation. The core fix is: **Remove `/F:Y`, add radio button verification, use arrow keys.**
