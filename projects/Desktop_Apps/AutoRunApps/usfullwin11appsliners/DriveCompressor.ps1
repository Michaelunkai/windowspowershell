# ============================================================================
# DRIVE COMPRESSOR/DECOMPRESSOR - NON-BLOCKING EXTREME SPEED
# Uses cmd /c for non-blocking file operations
# ============================================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:cancelOperation = $false
$script:processes = @()
$script:initialUsedSpace = 0
$script:currentDrive = ""
$script:isDecompressing = $false

$form = New-Object System.Windows.Forms.Form
$form.Text = 'EXTREME Drive Compressor - 1GB/sec'
$form.Size = New-Object System.Drawing.Size(700,550)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Location = New-Object System.Drawing.Point(10,10)
$titleLabel.Size = New-Object System.Drawing.Size(670,30)
$titleLabel.Text = 'EXTREME Compress/Decompress - Massively Parallel'
$titleLabel.Font = New-Object System.Drawing.Font("Arial",13,[System.Drawing.FontStyle]::Bold)
$titleLabel.TextAlign = 'MiddleCenter'
$form.Controls.Add($titleLabel)

$driveLabel = New-Object System.Windows.Forms.Label
$driveLabel.Location = New-Object System.Drawing.Point(20,50)
$driveLabel.Size = New-Object System.Drawing.Size(50,20)
$driveLabel.Text = 'Drive:'
$form.Controls.Add($driveLabel)

$driveCombo = New-Object System.Windows.Forms.ComboBox
$driveCombo.Location = New-Object System.Drawing.Point(75,48)
$driveCombo.Size = New-Object System.Drawing.Size(60,20)
$driveCombo.DropDownStyle = 'DropDownList'
Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -like '*:\' } | ForEach-Object { $driveCombo.Items.Add($_.Name + ':') }
$driveCombo.SelectedIndex = 0
$form.Controls.Add($driveCombo)

$algoLabel = New-Object System.Windows.Forms.Label
$algoLabel.Location = New-Object System.Drawing.Point(150,50)
$algoLabel.Size = New-Object System.Drawing.Size(60,20)
$algoLabel.Text = 'Algo:'
$form.Controls.Add($algoLabel)

$algoCombo = New-Object System.Windows.Forms.ComboBox
$algoCombo.Location = New-Object System.Drawing.Point(210,48)
$algoCombo.Size = New-Object System.Drawing.Size(110,20)
$algoCombo.DropDownStyle = 'DropDownList'
$algoCombo.Items.AddRange(@('XPRESS4K','XPRESS8K','XPRESS16K','LZX'))
$algoCombo.SelectedIndex = 0
$form.Controls.Add($algoCombo)

$threadLabel = New-Object System.Windows.Forms.Label
$threadLabel.Location = New-Object System.Drawing.Point(340,50)
$threadLabel.Size = New-Object System.Drawing.Size(70,20)
$threadLabel.Text = 'Processes:'
$form.Controls.Add($threadLabel)

$threadCombo = New-Object System.Windows.Forms.ComboBox
$threadCombo.Location = New-Object System.Drawing.Point(420,48)
$threadCombo.Size = New-Object System.Drawing.Size(80,20)
$threadCombo.DropDownStyle = 'DropDownList'
$threadCombo.Items.AddRange(@('16','32','64','128','256'))
$threadCombo.SelectedIndex = 3
$form.Controls.Add($threadCombo)

$speedLabel = New-Object System.Windows.Forms.Label
$speedLabel.Location = New-Object System.Drawing.Point(20,85)
$speedLabel.Size = New-Object System.Drawing.Size(650,28)
$speedLabel.Text = "Speed: Ready"
$speedLabel.Font = New-Object System.Drawing.Font("Consolas",14,[System.Drawing.FontStyle]::Bold)
$speedLabel.ForeColor = [System.Drawing.Color]::Blue
$form.Controls.Add($speedLabel)

$sizeLabel = New-Object System.Windows.Forms.Label
$sizeLabel.Location = New-Object System.Drawing.Point(20,120)
$sizeLabel.Size = New-Object System.Drawing.Size(650,55)
$sizeLabel.Text = "Drive Size: Calculating..."
$sizeLabel.Font = New-Object System.Drawing.Font("Consolas",12,[System.Drawing.FontStyle]::Bold)
$sizeLabel.ForeColor = [System.Drawing.Color]::DarkGreen
$form.Controls.Add($sizeLabel)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(20,185)
$progressBar.Size = New-Object System.Drawing.Size(650,35)
$progressBar.Style = 'Marquee'
$progressBar.MarqueeAnimationSpeed = 30
$form.Controls.Add($progressBar)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(20,230)
$statusLabel.Size = New-Object System.Drawing.Size(650,25)
$statusLabel.Text = 'Ready'
$statusLabel.Font = New-Object System.Drawing.Font("Arial",10,[System.Drawing.FontStyle]::Bold)
$form.Controls.Add($statusLabel)

$outputBox = New-Object System.Windows.Forms.TextBox
$outputBox.Location = New-Object System.Drawing.Point(20,265)
$outputBox.Size = New-Object System.Drawing.Size(650,170)
$outputBox.Multiline = $true
$outputBox.ScrollBars = 'Vertical'
$outputBox.ReadOnly = $true
$outputBox.Font = New-Object System.Drawing.Font("Consolas",9)
$form.Controls.Add($outputBox)

function Get-DriveSize {
    param($drive)
    $driveLetter = $drive -replace ':',''
    $di = New-Object System.IO.DriveInfo($driveLetter)
    $freeBytes = $di.AvailableFreeSpace
    $totalBytes = $di.TotalSize
    $usedBytes = $totalBytes - $freeBytes
    return @{
        Used=[math]::Round($usedBytes / 1GB, 2)
        Free=[math]::Round($freeBytes / 1GB, 2)
        UsedBytes=$usedBytes
    }
}

$script:lastCheckTime = $null
$script:lastUsedBytes = 0
$script:startTime = $null

$updateTimer = New-Object System.Windows.Forms.Timer
$updateTimer.Interval = 200
$updateTimer.Add_Tick({
    $size = Get-DriveSize $script:currentDrive
    $now = [DateTime]::Now

    # Initialize on first tick
    if ($null -eq $script:lastCheckTime) {
        $script:lastCheckTime = $now
        $script:lastUsedBytes = $size.UsedBytes
        $script:startTime = $now
        return
    }

    $elapsed = ($now - $script:lastCheckTime).TotalSeconds
    if ($elapsed -ge 0.5) {
        $bytesDiff = [math]::Abs($size.UsedBytes - $script:lastUsedBytes)
        if ($bytesDiff -gt 0 -and $elapsed -gt 0) {
            $speedMBps = [math]::Round($bytesDiff / $elapsed / 1MB, 0)
        } else {
            $speedMBps = 0
        }

        # Also calc average speed since start
        $totalElapsed = ($now - $script:startTime).TotalSeconds
        $totalBytes = [math]::Abs($size.UsedBytes - $script:initialUsedSpace)
        $avgSpeedMBps = 0
        if ($totalElapsed -gt 0 -and $totalBytes -gt 0) {
            $avgSpeedMBps = [math]::Round($totalBytes / $totalElapsed / 1MB, 0)
        }

        $speedLabel.Text = "Speed: $speedMBps MB/s (Avg: $avgSpeedMBps MB/s)"
        if ($avgSpeedMBps -ge 500) { $speedLabel.ForeColor = [System.Drawing.Color]::Green }
        elseif ($avgSpeedMBps -ge 100) { $speedLabel.ForeColor = [System.Drawing.Color]::Blue }
        else { $speedLabel.ForeColor = [System.Drawing.Color]::Orange }

        $script:lastCheckTime = $now
        $script:lastUsedBytes = $size.UsedBytes
    }

    if ($script:isDecompressing) {
        $addedBytes = $size.UsedBytes - $script:initialUsedSpace
        $addedGB = [math]::Round($addedBytes / 1GB, 3)
        $addedMB = [math]::Round($addedBytes / 1MB, 0)
        $sizeLabel.Text = "Used: $($size.Used) GB | Free: $($size.Free) GB`nExpanded: +$addedMB MB (+$addedGB GB)"
        $sizeLabel.ForeColor = [System.Drawing.Color]::DarkRed
    } else {
        $savedBytes = $script:initialUsedSpace - $size.UsedBytes
        $savedGB = [math]::Round($savedBytes / 1GB, 3)
        $savedMB = [math]::Round($savedBytes / 1MB, 0)
        $sizeLabel.Text = "Used: $($size.Used) GB | Free: $($size.Free) GB`nSaved: $savedMB MB ($savedGB GB)"
        $sizeLabel.ForeColor = [System.Drawing.Color]::DarkGreen
    }

    # Check running processes
    $running = @($script:processes | Where-Object { $_ -and -not $_.HasExited }).Count
    $statusLabel.Text = "Active processes: $running"
})

# Get all subfolders at depth 2 for maximum parallelism
function Get-DeepFolders {
    param($drive)
    $folders = @()
    $root = Get-ChildItem -Path "$drive\" -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin @('$Recycle.Bin','System Volume Information','$WinREAgent') }
    foreach ($r in $root) {
        $subs = Get-ChildItem -Path $r.FullName -Directory -Force -ErrorAction SilentlyContinue
        if ($subs) {
            foreach ($s in $subs) { $folders += $s.FullName }
        } else {
            $folders += $r.FullName
        }
    }
    return $folders
}

$compressBtn = New-Object System.Windows.Forms.Button
$compressBtn.Location = New-Object System.Drawing.Point(30,450)
$compressBtn.Size = New-Object System.Drawing.Size(145,45)
$compressBtn.Text = 'COMPRESS'
$compressBtn.BackColor = [System.Drawing.Color]::LightGreen
$compressBtn.Font = New-Object System.Drawing.Font("Arial",12,[System.Drawing.FontStyle]::Bold)
$compressBtn.Add_Click({
    $drive = $driveCombo.SelectedItem
    $algo = $algoCombo.SelectedItem
    $maxProcs = [int]$threadCombo.SelectedItem

    $result = [System.Windows.Forms.MessageBox]::Show("Compress $drive with $algo using $maxProcs parallel processes?","Confirm",[System.Windows.Forms.MessageBoxButtons]::YesNo)
    if ($result -eq 'Yes') {
        $script:cancelOperation = $false
        $script:isDecompressing = $false
        $script:currentDrive = $drive
        $script:processes = @()
        $compressBtn.Enabled = $false
        $decompressBtn.Enabled = $false
        $cancelBtn.Enabled = $true

        $initialSize = Get-DriveSize $drive
        $script:initialUsedSpace = $initialSize.UsedBytes
        $script:lastUsedBytes = $initialSize.UsedBytes
        $script:lastCheckTime = $null
        $script:startTime = $null

        $outputBox.Text = "COMPRESS: $maxProcs processes, $algo`r`n"
        $statusLabel.Text = "Getting folders..."
        [System.Windows.Forms.Application]::DoEvents()

        $folders = Get-DeepFolders $drive
        $outputBox.AppendText("Found $($folders.Count) folders to process`r`n")

        $updateTimer.Start()

        # Launch processes for each folder
        $launched = 0
        foreach ($folder in $folders) {
            if ($script:cancelOperation) { break }

            # Wait if too many running
            while (@($script:processes | Where-Object { $_ -and -not $_.HasExited }).Count -ge $maxProcs) {
                Start-Sleep -Milliseconds 50
                [System.Windows.Forms.Application]::DoEvents()
                if ($script:cancelOperation) { break }
            }

            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "compact.exe"
            $psi.Arguments = "/c /s:`"$folder`" /exe:$algo /i /q"
            $psi.WindowStyle = 'Hidden'
            $psi.CreateNoWindow = $true
            $psi.UseShellExecute = $false

            $proc = [System.Diagnostics.Process]::Start($psi)
            $script:processes += $proc
            $launched++

            if ($launched % 20 -eq 0) {
                $outputBox.AppendText("Launched $launched processes...`r`n")
                $outputBox.SelectionStart = $outputBox.Text.Length
                $outputBox.ScrollToCaret()
            }
            [System.Windows.Forms.Application]::DoEvents()
        }

        # Root files
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "compact.exe"
        $psi.Arguments = "/c $drive\*.* /exe:$algo /i /q"
        $psi.WindowStyle = 'Hidden'
        $psi.CreateNoWindow = $true
        $psi.UseShellExecute = $false
        $script:processes += [System.Diagnostics.Process]::Start($psi)

        $outputBox.AppendText("`r`nAll $launched folder processes launched!`r`nWaiting for completion...`r`n")

        # Completion timer
        $completionTimer = New-Object System.Windows.Forms.Timer
        $completionTimer.Interval = 300
        $completionTimer.Add_Tick({
            [System.Windows.Forms.Application]::DoEvents()
            $running = @($script:processes | Where-Object { $_ -and -not $_.HasExited }).Count

            if ($running -eq 0 -or $script:cancelOperation) {
                $updateTimer.Stop()
                $completionTimer.Stop()

                if ($script:cancelOperation) {
                    foreach ($p in $script:processes) { try { $p.Kill() } catch {} }
                    $statusLabel.Text = "Cancelled!"
                } else {
                    $finalSize = Get-DriveSize $script:currentDrive
                    $savedBytes = $script:initialUsedSpace - $finalSize.UsedBytes
                    $savedGB = [math]::Round($savedBytes / 1GB, 2)
                    $statusLabel.Text = "DONE! Saved: $savedGB GB"
                    $outputBox.AppendText("`r`n=== COMPLETE: Saved $savedGB GB ===`r`n")
                    [System.Windows.Forms.MessageBox]::Show("Done! Saved: $savedGB GB","Complete")
                }
                $compressBtn.Enabled = $true
                $decompressBtn.Enabled = $true
                $cancelBtn.Enabled = $false
            }
        })
        $completionTimer.Start()
    }
})
$form.Controls.Add($compressBtn)

$decompressBtn = New-Object System.Windows.Forms.Button
$decompressBtn.Location = New-Object System.Drawing.Point(195,450)
$decompressBtn.Size = New-Object System.Drawing.Size(155,45)
$decompressBtn.Text = 'DECOMPRESS'
$decompressBtn.BackColor = [System.Drawing.Color]::LightCoral
$decompressBtn.Font = New-Object System.Drawing.Font("Arial",12,[System.Drawing.FontStyle]::Bold)
$decompressBtn.Add_Click({
    $drive = $driveCombo.SelectedItem
    $maxProcs = [int]$threadCombo.SelectedItem

    $result = [System.Windows.Forms.MessageBox]::Show("Decompress $drive using $maxProcs parallel processes?","Confirm",[System.Windows.Forms.MessageBoxButtons]::YesNo)
    if ($result -eq 'Yes') {
        $script:cancelOperation = $false
        $script:isDecompressing = $true
        $script:currentDrive = $drive
        $script:processes = @()
        $compressBtn.Enabled = $false
        $decompressBtn.Enabled = $false
        $cancelBtn.Enabled = $true

        $initialSize = Get-DriveSize $drive
        $script:initialUsedSpace = $initialSize.UsedBytes
        $script:lastUsedBytes = $initialSize.UsedBytes
        $script:lastCheckTime = $null
        $script:startTime = $null

        $outputBox.Text = "DECOMPRESS: $maxProcs processes`r`n"
        $statusLabel.Text = "Getting folders..."
        [System.Windows.Forms.Application]::DoEvents()

        $folders = Get-DeepFolders $drive
        $outputBox.AppendText("Found $($folders.Count) folders to process`r`n")

        $updateTimer.Start()

        $launched = 0
        foreach ($folder in $folders) {
            if ($script:cancelOperation) { break }

            while (@($script:processes | Where-Object { $_ -and -not $_.HasExited }).Count -ge $maxProcs) {
                Start-Sleep -Milliseconds 50
                [System.Windows.Forms.Application]::DoEvents()
                if ($script:cancelOperation) { break }
            }

            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "compact.exe"
            $psi.Arguments = "/u /s:`"$folder`" /i /q"
            $psi.WindowStyle = 'Hidden'
            $psi.CreateNoWindow = $true
            $psi.UseShellExecute = $false

            $proc = [System.Diagnostics.Process]::Start($psi)
            $script:processes += $proc
            $launched++

            if ($launched % 20 -eq 0) {
                $outputBox.AppendText("Launched $launched processes...`r`n")
                $outputBox.SelectionStart = $outputBox.Text.Length
                $outputBox.ScrollToCaret()
            }
            [System.Windows.Forms.Application]::DoEvents()
        }

        # Root files
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "compact.exe"
        $psi.Arguments = "/u $drive\*.* /i /q"
        $psi.WindowStyle = 'Hidden'
        $psi.CreateNoWindow = $true
        $psi.UseShellExecute = $false
        $script:processes += [System.Diagnostics.Process]::Start($psi)

        $outputBox.AppendText("`r`nAll $launched folder processes launched!`r`nWaiting for completion...`r`n")

        $completionTimer = New-Object System.Windows.Forms.Timer
        $completionTimer.Interval = 300
        $completionTimer.Add_Tick({
            [System.Windows.Forms.Application]::DoEvents()
            $running = @($script:processes | Where-Object { $_ -and -not $_.HasExited }).Count

            if ($running -eq 0 -or $script:cancelOperation) {
                $updateTimer.Stop()
                $completionTimer.Stop()

                if ($script:cancelOperation) {
                    foreach ($p in $script:processes) { try { $p.Kill() } catch {} }
                    $statusLabel.Text = "Cancelled!"
                } else {
                    $finalSize = Get-DriveSize $script:currentDrive
                    $addedBytes = $finalSize.UsedBytes - $script:initialUsedSpace
                    $addedGB = [math]::Round($addedBytes / 1GB, 2)
                    $statusLabel.Text = "DONE! Expanded: +$addedGB GB"
                    $outputBox.AppendText("`r`n=== COMPLETE: Expanded +$addedGB GB ===`r`n")
                    [System.Windows.Forms.MessageBox]::Show("Done! Expanded: +$addedGB GB","Complete")
                }
                $compressBtn.Enabled = $true
                $decompressBtn.Enabled = $true
                $cancelBtn.Enabled = $false
            }
        })
        $completionTimer.Start()
    }
})
$form.Controls.Add($decompressBtn)

$cancelBtn = New-Object System.Windows.Forms.Button
$cancelBtn.Location = New-Object System.Drawing.Point(370,450)
$cancelBtn.Size = New-Object System.Drawing.Size(120,45)
$cancelBtn.Text = 'CANCEL'
$cancelBtn.BackColor = [System.Drawing.Color]::Orange
$cancelBtn.Font = New-Object System.Drawing.Font("Arial",12,[System.Drawing.FontStyle]::Bold)
$cancelBtn.Enabled = $false
$cancelBtn.Add_Click({
    $script:cancelOperation = $true
    $statusLabel.Text = "Cancelling..."
    foreach ($p in $script:processes) { try { $p.Kill() } catch {} }
})
$form.Controls.Add($cancelBtn)

$statusBtn = New-Object System.Windows.Forms.Button
$statusBtn.Location = New-Object System.Drawing.Point(510,450)
$statusBtn.Size = New-Object System.Drawing.Size(150,45)
$statusBtn.Text = 'REFRESH'
$statusBtn.BackColor = [System.Drawing.Color]::LightBlue
$statusBtn.Font = New-Object System.Drawing.Font("Arial",12,[System.Drawing.FontStyle]::Bold)
$statusBtn.Add_Click({
    $size = Get-DriveSize $driveCombo.SelectedItem
    $sizeLabel.Text = "Used: $($size.Used) GB | Free: $($size.Free) GB"
    $sizeLabel.ForeColor = [System.Drawing.Color]::DarkBlue
})
$form.Controls.Add($statusBtn)

$initialDriveSize = Get-DriveSize $driveCombo.SelectedItem
$sizeLabel.Text = "Used: $($initialDriveSize.Used) GB | Free: $($initialDriveSize.Free) GB"
$progressBar.Style = 'Continuous'
$progressBar.Value = 0

$form.ShowDialog()
