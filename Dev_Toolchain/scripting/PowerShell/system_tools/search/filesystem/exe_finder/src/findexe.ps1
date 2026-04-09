param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$name,
    [switch]$fast
)

# Auto-relaunch under pwsh 7 if running on PS5
if ($PSVersionTable.PSVersion.Major -lt 7) {
    $pwshPath = (Get-Command pwsh -EA SilentlyContinue).Source
    if (-not $pwshPath) {
        Write-Host "`n  ERROR: PowerShell 7 (pwsh) required. Install: winget install Microsoft.PowerShell" -ForegroundColor Red
        return
    }
    $relaunchArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File', $PSCommandPath, '-name', $name)
    if ($fast) { $relaunchArgs += '-fast' }
    & $pwshPath @relaunchArgs
    return
}

$sw = [Diagnostics.Stopwatch]::StartNew()
$allDrives = @((Get-PSDrive -PSProvider FileSystem -EA SilentlyContinue | Where-Object { $_.Free -gt 0 }).Root | Sort-Object)
$skipNames = @('Windows','$Recycle.Bin','$WinREAgent','System Volume Information','Recovery','PerfLogs')

# ═══════════════════════════════════════════════════════════
# Build ALL work items — metadata lookups + filesystem scans
# Everything runs in parallel via ForEach-Object -Parallel
# ═══════════════════════════════════════════════════════════

$workItems = [System.Collections.Generic.List[hashtable]]::new()

# ── Metadata strategies (instant) ──
$workItems.Add(@{ type='where' })
$workItems.Add(@{ type='apppath' })
$workItems.Add(@{ type='startmenu' })
$workItems.Add(@{ type='uninstall' })
$workItems.Add(@{ type='process' })
$workItems.Add(@{ type='service' })
$workItems.Add(@{ type='schedtask' })
$workItems.Add(@{ type='appx' })
$workItems.Add(@{ type='pkgmgr' })
$workItems.Add(@{ type='userlocal' })
$workItems.Add(@{ type='winstore' })

# ── Per-drive standard install dirs ──
foreach ($drv in $allDrives) {
    $workItems.Add(@{ type='installdirs'; path=$drv })
}

# ── Deep filesystem scan: one work item per 2nd-level directory ──
# This gives ~100+ parallel items instead of ~20, so no single dir blocks everything
if (-not $fast) {
    foreach ($drv in $allDrives) {
        $topDirs = try { [System.IO.Directory]::GetDirectories($drv) } catch { @() }
        foreach ($td in $topDirs) {
            $dn = [System.IO.Path]::GetFileName($td)
            if ($skipNames -contains $dn -or $dn.StartsWith('$')) { continue }

            # For large dirs, split into sub-dirs for finer parallelism
            $subDirs = try { [System.IO.Directory]::GetDirectories($td) } catch { @() }
            if ($subDirs.Count -gt 5) {
                foreach ($sd in $subDirs) {
                    $sdn = [System.IO.Path]::GetFileName($sd)
                    if ($sdn.StartsWith('$') -or $sdn -eq 'Windows') { continue }
                    $workItems.Add(@{ type='deepscan'; path=$sd })
                }
            } else {
                $workItems.Add(@{ type='deepscan'; path=$td })
            }
        }
    }
}

# ═══════════════════════════════════════════════════════════
# Execute ALL work items in parallel
# ═══════════════════════════════════════════════════════════

# Track which source found each result (for main exe scoring)
$results = $workItems | ForEach-Object -Parallel {
    $item = $_
    $n = $using:name
    $drives = $using:allDrives

    switch ($item.type) {
        'where' {
            try { where.exe "*$n*" 2>$null | Where-Object { $_ -match '\.exe$' } } catch {}
        }
        'apppath' {
            try { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\*" -EA SilentlyContinue |
                Where-Object { $_.PSChildName -like "*$n*" } | ForEach-Object {
                    $p=$_.'(default)'; if ($p -and $p -match '\.exe$' -and (Test-Path $p)) { $p } } } catch {}
        }
        'startmenu' {
            try { $sh = New-Object -ComObject WScript.Shell
                @("$env:APPDATA\Microsoft\Windows\Start Menu","C:\ProgramData\Microsoft\Windows\Start Menu") | ForEach-Object {
                    if (Test-Path $_) { Get-ChildItem $_ -Filter "*.lnk" -Recurse -EA SilentlyContinue |
                        Where-Object { $_.Name -like "*$n*" } | ForEach-Object {
                            $t = $sh.CreateShortcut($_.FullName).TargetPath
                            if ($t -and $t -match '\.exe$' -and (Test-Path $t)) { $t } } } } } catch {}
        }
        'uninstall' {
            try { @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*") | ForEach-Object {
                Get-ItemProperty $_ -EA SilentlyContinue |
                    Where-Object { $_.DisplayName -like "*$n*" -or $_.PSChildName -like "*$n*" } | ForEach-Object {
                    if ($_.DisplayIcon) { $i=($_.DisplayIcon -split ',')[0].Trim('"')
                        if ($i -match '\.exe$' -and (Test-Path $i)) { $i } }
                    if ($_.InstallLocation -and (Test-Path $_.InstallLocation)) {
                        Get-ChildItem $_.InstallLocation -Filter "*.exe" -Recurse -Depth 3 -EA SilentlyContinue |
                            Select-Object -ExpandProperty FullName } } } } catch {}
        }
        'process' {
            try { Get-Process -EA SilentlyContinue | Where-Object { $_.ProcessName -like "*$n*" } |
                Select-Object -Unique -ExpandProperty Path -EA SilentlyContinue |
                Where-Object { $_ -match '\.exe$' } } catch {}
        }
        'service' {
            try { Get-CimInstance Win32_Service -EA SilentlyContinue |
                Where-Object { $_.Name -like "*$n*" -or $_.DisplayName -like "*$n*" -or $_.PathName -like "*$n*" } | ForEach-Object {
                    $p = ($_.PathName -replace '"','') -replace '\s+(-|/).*$',''
                    if ($p -match '\.exe$' -and (Test-Path $p)) { $p } } } catch {}
        }
        'schedtask' {
            try { Get-ScheduledTask -EA SilentlyContinue | Where-Object { $_.TaskName -like "*$n*" } | ForEach-Object {
                $_.Actions | Where-Object { $_.Execute -and $_.Execute -match '\.exe' } | ForEach-Object {
                    if ($_.Execute -and (Test-Path $_.Execute)) { $_.Execute } } } } catch {}
        }
        'appx' {
            try { Get-AppxPackage -Name "*$n*" -EA SilentlyContinue | ForEach-Object {
                if ($_.InstallLocation -and (Test-Path $_.InstallLocation)) {
                    Get-ChildItem $_.InstallLocation -Filter "*.exe" -Depth 2 -EA SilentlyContinue |
                        Select-Object -ExpandProperty FullName } } } catch {}
        }
        'pkgmgr' {
            @("$env:LOCALAPPDATA\Microsoft\WinGet\Packages","$env:USERPROFILE\scoop\apps","C:\ProgramData\chocolatey\lib") | ForEach-Object {
                if (Test-Path $_) {
                    Get-ChildItem $_ -Filter "*$n*.exe" -Recurse -Depth 4 -EA SilentlyContinue | Select-Object -ExpandProperty FullName
                    Get-ChildItem $_ -Directory -EA SilentlyContinue | Where-Object { $_.Name -like "*$n*" } | ForEach-Object {
                        Get-ChildItem $_.FullName -Filter "*.exe" -Recurse -Depth 3 -EA SilentlyContinue | Select-Object -ExpandProperty FullName } } }
        }
        'userlocal' {
            @("$env:LOCALAPPDATA\Programs","$env:LOCALAPPDATA\Microsoft\WindowsApps","$env:APPDATA") | ForEach-Object {
                if (Test-Path $_) { Get-ChildItem $_ -Filter "*$n*.exe" -Recurse -Depth 5 -EA SilentlyContinue | Select-Object -ExpandProperty FullName } }
        }
        'winstore' {
            if (Test-Path "C:\Program Files\WindowsApps") {
                Get-ChildItem "C:\Program Files\WindowsApps" -Filter "*$n*.exe" -Recurse -Depth 3 -EA SilentlyContinue | Select-Object -ExpandProperty FullName }
        }
        'installdirs' {
            $drv = $item.path
            @("Program Files","Program Files (x86)","ProgramData","tools","apps","portable") | ForEach-Object {
                $p = Join-Path $drv $_; if (Test-Path $p) {
                    Get-ChildItem $p -Filter "*$n*.exe" -Recurse -Depth 5 -EA SilentlyContinue | Select-Object -ExpandProperty FullName } }
        }
        'deepscan' {
            $dir = $item.path
            $opts = [System.IO.EnumerationOptions]::new()
            $opts.RecurseSubdirectories = $true
            $opts.IgnoreInaccessible = $true
            $opts.AttributesToSkip = [System.IO.FileAttributes]::ReparsePoint
            $opts.MaxRecursionDepth = 10

            # exe name match
            try { foreach ($f in [System.IO.Directory]::EnumerateFiles($dir, "*$n*.exe", $opts)) { $f } } catch {}

            # folder name match -> all exes inside
            try {
                foreach ($d in [System.IO.Directory]::EnumerateDirectories($dir, "*$n*", $opts)) {
                    $io = [System.IO.EnumerationOptions]::new()
                    $io.RecurseSubdirectories = $true
                    $io.IgnoreInaccessible = $true
                    $io.AttributesToSkip = [System.IO.FileAttributes]::ReparsePoint
                    try { foreach ($f in [System.IO.Directory]::EnumerateFiles($d, "*.exe", $io)) { $f } } catch {}
                }
            } catch {}
        }
    }
} -ThrottleLimit 30

# ── Deduplicate ──
$seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($r in $results) {
    if ($r -and $r -is [string] -and $r -match '\.exe$') { [void]$seen.Add($r) }
}

$sw.Stop()

# ═══════════════════════════════════════════════════════════
# MAIN EXE DETECTION — smart multi-signal scoring
# ═══════════════════════════════════════════════════════════

function Get-ExeInfo {
    param([string]$path)
    $info = @{ Path=$path; Size=0; IsGUI=$false; ProductName=''; FileDesc=''; Company=''; FileName='' }
    $info.FileName = [System.IO.Path]::GetFileNameWithoutExtension($path).ToLower()
    try { $info.Size = (Get-Item $path -EA SilentlyContinue).Length } catch {}
    try {
        $vi = (Get-Item $path -EA SilentlyContinue).VersionInfo
        $info.ProductName = if ($vi.ProductName) { $vi.ProductName } else { '' }
        $info.FileDesc = if ($vi.FileDescription) { $vi.FileDescription } else { '' }
        $info.Company = if ($vi.CompanyName) { $vi.CompanyName } else { '' }
    } catch {}
    # Check PE subsystem: 2=GUI, 3=Console
    try {
        $fs = [System.IO.File]::OpenRead($path)
        $br = [System.IO.BinaryReader]::new($fs)
        $fs.Seek(0x3C, [System.IO.SeekOrigin]::Begin) | Out-Null
        $peOffset = $br.ReadInt32()
        $fs.Seek($peOffset + 0x5C, [System.IO.SeekOrigin]::Begin) | Out-Null
        $subsystem = $br.ReadUInt16()
        $info.IsGUI = ($subsystem -eq 2)
        $br.Close(); $fs.Close()
    } catch { $info.IsGUI = $false }
    return $info
}

function Score-MainExe {
    param($info, [string]$searchName, $allInfos)

    $score = 0
    $fn = $info.FileName
    $fullLower = $info.Path.ToLower()
    $s = $searchName.ToLower()

    # ═══ SIGNAL 1: Filename match (strongest) ═══
    if ($fn -eq $s) { $score += 200 }
    elseif ($fn -like "$s*" -or $fn -like "*$s") { $score += 100 }
    elseif ($fn -like "*$s*") { $score += 60 }

    # ═══ SIGNAL 2: Version info mentions search term ═══
    $prodLower = $info.ProductName.ToLower()
    $descLower = $info.FileDesc.ToLower()
    $compLower = $info.Company.ToLower()
    $allMeta = "$prodLower $descLower $compLower"

    if ($prodLower -like "*$s*") { $score += 50 }
    if ($descLower -like "*$s*") { $score += 30 }
    if ($compLower -like "*$s*") { $score += 20 }

    # ═══ SIGNAL 3: GUI app (main apps are GUI, helpers often console) ═══
    if ($info.IsGUI) { $score += 40 }

    # ═══ SIGNAL 4: Install location quality ═══
    if ($fullLower -match '^c:\\program files\\') { $score += 35 }
    elseif ($fullLower -match '^c:\\program files \(x86\)\\') { $score += 33 }
    elseif ($fullLower -match '\\windowsapps\\') { $score += 30 }
    elseif ($fullLower -match '\\appdata\\local\\programs\\') { $score += 25 }
    elseif ($fullLower -match '\\appdata\\(local|roaming)\\') { $score += 18 }

    # ═══ SIGNAL 5: Path context — folder name abbreviation match ═══
    # e.g. "Hard Disk Manager 17" folder → hdm17.exe
    $pathParts = $fullLower -split '\\'
    $folderContext = ($pathParts | Select-Object -Skip 1 | Select-Object -SkipLast 1) -join ' '

    # Check if exe name is an abbreviation/acronym of a folder in the path
    # e.g. hdm17 → H(ard) D(isk) M(anager) 17
    # Strategy: split exe name into alpha runs + digit runs, match alpha as initials, digits as literal tokens
    $fnLetters = ($fn -replace '[^a-z]','')       # hdm17 → hdm
    $fnDigits = ($fn -replace '[^0-9]','')         # hdm17 → 17
    $abbrMatched = $false
    foreach ($part in $pathParts) {
        $words = $part -split '[\s_\-\.]' | Where-Object { $_.Length -gt 0 }
        if ($words.Count -lt 2) { continue }

        # Get initials of alpha words only
        $alphaWords = $words | Where-Object { $_ -match '^[a-z]' }
        $initials = ($alphaWords | ForEach-Object { $_[0] }) -join ''

        # Get digit tokens from folder name (e.g. "17" from "Hard Disk Manager 17 Business")
        $digitTokens = ($words | Where-Object { $_ -match '^\d' }) -join ''

        # Match: initials match AND digits match (or no digits in exe)
        $letterMatch = ($fnLetters.Length -ge 2 -and ($fnLetters -eq $initials -or $initials.StartsWith($fnLetters)))
        $digitMatch = ($fnDigits.Length -eq 0 -or $digitTokens.Contains($fnDigits))

        if ($letterMatch -and $digitMatch) {
            $score += 80  # strong: exe is abbreviation of folder name
            $abbrMatched = $true
            break
        }
        # Partial: initials start with exe letters (weaker)
        if ($fnLetters.Length -ge 2 -and $initials.StartsWith($fnLetters) -and $fnDigits.Length -eq 0) {
            $score += 40
            $abbrMatched = $true
            break
        }
    }

    # ═══ SIGNAL 6: Parent folder suggests main program ═══
    $parentName = [System.IO.Path]::GetFileName([System.IO.Path]::GetDirectoryName($info.Path)).ToLower()
    if ($parentName -eq 'program' -or $parentName -eq 'bin' -or $parentName -eq 'app' -or $parentName -eq 'cmd') { $score += 25 }
    if ($parentName -like "*$s*") { $score += 15 }

    # Penalize internal/implementation paths (libexec, usr\bin, usr\lib, mingw64 internals)
    if ($fullLower -match '\\libexec\\|\\usr\\bin\\|\\usr\\lib\\') { $score -= 30 }
    if ($fullLower -match '\\mingw64\\') { $score -= 40 }

    # ═══ SIGNAL 7: Relative file size (biggest exe in same folder group = likely main) ═══
    # Group by the closest ancestor folder containing the search term
    $myAppFolder = ''
    for ($i = $pathParts.Count - 2; $i -ge 0; $i--) {
        if ($pathParts[$i] -like "*$s*") { $myAppFolder = ($pathParts[0..$i] -join '\'); break }
    }
    if ($myAppFolder) {
        $siblings = $allInfos | Where-Object { $_.Path.ToLower().StartsWith($myAppFolder) }
        $maxSize = ($siblings | Measure-Object -Property Size -Maximum).Maximum
        if ($maxSize -gt 0 -and $info.Size -eq $maxSize) { $score += 30 }
        elseif ($maxSize -gt 0 -and $info.Size -ge ($maxSize * 0.5)) { $score += 10 }
    }

    # Also global size bonus
    if ($info.Size -gt 50MB) { $score += 20 }
    elseif ($info.Size -gt 10MB) { $score += 15 }
    elseif ($info.Size -gt 1MB) { $score += 8 }

    # ═══ PENALTIES ═══

    # Helper/tool/updater names
    $helperPatterns = @('update','unins','setup','install','helper','crash','elevation_service',
                        'proxy','repair','diagnostic','telemetry','worker','notification',
                        'pwa_launcher','tunnel','_service','_helper','_agent','_host')
    foreach ($p in $helperPatterns) {
        if ($fn -like "*$p*" -and $fn -ne $s) { $score -= 40; break }
    }

    # "A part of" in description = explicitly a helper component
    if ($descLower -match 'a part of|helper|support|utility service|background') { $score -= 30 }

    # Known bundled tools that are never the main app
    $bundled = @('7z','syslinux','logsaver','netconfig','pdfito','pnpenforce','vimchrange',
                 'winpe_progress','bluescrn','chmview','qtwebengineprocess','hidecmd',
                 'chrmstp','squirrel')
    if ($bundled -contains $fn) { $score -= 50 }

    # Backup/temp/cache/old locations
    if ($fullLower -match '\\backup\\') { $score -= 25 }
    if ($fullLower -match '\\temp\\|\\cache\\|\\old\\|\\archive\\') { $score -= 40 }
    if ($fullLower -match '\\package cache\\') { $score -= 35 }

    # Deep subdirectories (plugins, bluescrn, winpe, syslinux_files)
    if ($fullLower -match '\\plugins\\|\\bluescrn\\|\\winpe|\\syslinux') { $score -= 30 }

    # Prefer newer app versions in path (Discord app-1.0.9229 > app-1.0.9059)
    if ($fullLower -match 'app-(\d+)\.(\d+)\.(\d+)') {
        $verNum = [int]$Matches[1] * 10000 + [int]$Matches[2] * 100 + [int]$Matches[3]
        $score += [math]::Min($verNum * 0.001, 5)
    }

    return [math]::Round($score, 2)
}

# Gather info for all results
$allInfos = @($seen | ForEach-Object { Get-ExeInfo $_ })

# Score and pick best
$mainExe = $null
if ($allInfos.Count -gt 0) {
    $scored = $allInfos | ForEach-Object {
        [PSCustomObject]@{ Path = $_.Path; Score = (Score-MainExe $_ $name $allInfos) }
    } | Sort-Object Score -Descending

    $mainExe = $scored[0].Path
}

# ── Output ──
Write-Host ""
Write-Host "  FindExe - Universal App Locator" -ForegroundColor Cyan
$mode = if ($fast) { "FAST" } else { "FULL" }
Write-Host "  Search: '$name' | Mode: $mode | Time: $($sw.Elapsed.TotalSeconds.ToString('F2'))s | Drives: $($allDrives.Count) | Results: $($seen.Count)" -ForegroundColor DarkGray

if ($seen.Count -eq 0) {
    Write-Host ""
    Write-Host "  Not found: $name" -ForegroundColor Yellow
} elseif ($mainExe) {
    Write-Host ""
    Write-Host "  $mainExe" -ForegroundColor Blue
    Write-Host ""
    $others = $seen | Sort-Object | Where-Object { $_ -ne $mainExe }
    if ($others) {
        foreach ($o in $others) { Write-Host "  $o" -ForegroundColor DarkGray }
    }
}
Write-Host ""
