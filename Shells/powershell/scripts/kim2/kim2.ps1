<#
.SYNOPSIS
    kim2
#>
# Authentication headers
    $headers = @{
        "X-AUTH-USER"  = "Michael Fedorovsky"
        "X-AUTH-TOKEN" = "13571357"
        "Content-Type" = "application/json"
    }

    # 1. Get recent timesheets (adjust 'page' / 'size' if needed)
    $uri = "https://time.tovtech.org/api/timesheets?page=1&size=10"
    try {
        $entries = Invoke-RestMethod -Uri $uri -Headers $headers -Method GET
    }
    catch {
        Write-Host "Failed to fetch timesheets: $($_.Exception.Message)"
        return
    }

    if (-not $entries) {
        Write-Host "No timesheets returned."
        return
    }

    # 2. Filter for running entries (no 'end' set)
    $running = $entries | Where-Object { -not $_.end }

    if (-not $running) {
        Write-Host "No active timers found."
        return
    }

    # 3. Take the latest running entry (highest id as approximation)
    $latestEntry = $running | Sort-Object id -Descending | Select-Object -First 1

    # 4. Stop the latest running timer
    $stopUrl = "https://time.tovtech.org/api/timesheets/$($latestEntry.id)/stop"

    try {
        # Kimai uses PATCH for /stop in current API examples; if this fails, try POST.
        Invoke-RestMethod -Uri $stopUrl -Headers $headers -Method PATCH
        Write-Host "Stopped the latest timer (ID: $($latestEntry.id))"
    }
    catch {
        Write-Host "Failed to stop timer $($latestEntry.id): $($_.Exception.Message)"
    }
