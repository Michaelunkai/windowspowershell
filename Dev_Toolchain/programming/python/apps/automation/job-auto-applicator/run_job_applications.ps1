# Fully Automated Job Application Sender
# Closes Chrome, runs the application sender, sends to 7 companies

Write-Host "`n$('='*70)" -ForegroundColor Green
Write-Host "FULLY AUTOMATED JOB APPLICATION SENDER" -ForegroundColor Green
Write-Host "$('='*70)" -ForegroundColor Green
Write-Host "`nThis will:"
Write-Host "  1. Close Chrome (required for automation)"
Write-Host "  2. Open Chrome with your profile (already logged into Gmail)"
Write-Host "  3. Send applications to 7 companies with your resume"
Write-Host "  4. Track sent applications (won't send duplicates)"
Write-Host "`n$('='*70)" -ForegroundColor Yellow
Write-Host "IMPORTANT: All Chrome windows will be closed!" -ForegroundColor Yellow
Write-Host "$('='*70)" -ForegroundColor Yellow

$confirm = Read-Host "`nPress ENTER to continue (or type 'n' to cancel)"
if ($confirm -eq 'n') {
    Write-Host "`n[CANCELLED]" -ForegroundColor Red
    exit
}

# Close Chrome
Write-Host "`n[1/3] Closing Chrome..." -ForegroundColor Cyan
$chrome = Get-Process chrome -ErrorAction SilentlyContinue
if ($chrome) {
    Stop-Process -Name chrome -Force
    Write-Host "      [OK] Chrome closed" -ForegroundColor White
    Start-Sleep -Seconds 3
} else {
    Write-Host "      [OK] Chrome not running" -ForegroundColor White
}

# Run the application sender
Write-Host "`n[2/3] Starting job application sender..." -ForegroundColor Cyan
Write-Host "      Using profile: Default (michaelovsky5@gmail.com)" -ForegroundColor White
Write-Host "      Resume: Michael_Fedorovsky_Resume_devops.pdf" -ForegroundColor White
Write-Host "      Companies: 7" -ForegroundColor White

$scriptPath = "F:\study\Dev_Toolchain\programming\python\apps\automation\job-auto-applicator\auto_apply_chrome.py"

# Run Python script
python $scriptPath

Write-Host "`n[3/3] Done!" -ForegroundColor Green
Write-Host "`nPress ENTER to close..." -ForegroundColor Gray
Read-Host
