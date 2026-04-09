# Test Email Sender
# Sends a test email to yourself to verify automation works

Write-Host "`n$('='*70)" -ForegroundColor Cyan
Write-Host "TEST EMAIL SENDER" -ForegroundColor Cyan
Write-Host "$('='*70)" -ForegroundColor Cyan
Write-Host "`nThis sends a TEST email to YOUR OWN address (michaelovsky5@gmail.com)"
Write-Host "to verify the automation works before sending to companies."
Write-Host "`n$('='*70)" -ForegroundColor Yellow
Write-Host "Chrome will be closed to run this test!" -ForegroundColor Yellow
Write-Host "$('='*70)" -ForegroundColor Yellow

$confirm = Read-Host "`nPress ENTER to run test (or 'n' to cancel)"
if ($confirm -eq 'n') { exit }

# Close Chrome
Write-Host "`nClosing Chrome..." -ForegroundColor Cyan
Stop-Process -Name chrome -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

# Run test
python "F:\study\Dev_Toolchain\programming\python\apps\automation\job-auto-applicator\test_send.py"

Write-Host "`nPress ENTER to close..." -ForegroundColor Gray
Read-Host
