<#
.SYNOPSIS
    runall
#>
$exeFiles = Get-ChildItem -Path "F:\games" -Recurse -Filter *.exe -File | Where-Object {
        $_.Name -notmatch '(?i)^unins\d*\.exe$' -and
        $_.Name -notmatch '(?i)^uninstall.*\.exe$' -and
        $_.Name -notmatch '(?i)vc_redist|vcredist|quicksfv|dxwebsetup|crashreportclient|crash'
    }
    foreach ($exe in $exeFiles) {
        try {
            Write-Output "`n[RUNNING] $($exe.FullName)"
            $process = Start-Process -FilePath $exe.FullName -PassThru
            Start-Sleep -Seconds 10
            if (!$process.HasExited) {
                Write-Output "[CLOSING] $($exe.Name)"
                Stop-Process -Id $process.Id -Force
            } else {
                Write-Output "[EXITED EARLY] $($exe.Name)"
            }
        } catch {
            Write-Warning "[ERROR] Failed to handle $($exe.FullName): $_"
        }
    }
    Write-Output "`n[DONE] All filtered executables processed."
