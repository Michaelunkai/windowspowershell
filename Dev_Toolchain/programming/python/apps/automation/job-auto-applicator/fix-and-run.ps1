# Gmail Password Fix & Job Applicator Runner
# Automates the entire process of fixing Gmail credentials and running applications

Write-Host "`n$('='*70)" -ForegroundColor Red
Write-Host "GMAIL PASSWORD FIX REQUIRED" -ForegroundColor Red
Write-Host "$('='*70)`n" -ForegroundColor Red

Write-Host "Your current Gmail app password is INVALID or EXPIRED." -ForegroundColor Yellow
Write-Host "Let's fix it in 3 steps (takes 2 minutes):`n" -ForegroundColor Yellow

Write-Host "STEP 1: Generate New App Password" -ForegroundColor Cyan
Write-Host "-"*70
Write-Host "1. Browser will open to Google App Passwords page"
Write-Host "2. Sign in if prompted"
Write-Host "3. Create app called 'Job Applicator'"
Write-Host "4. COPY the 16-character password (like 'abcd efgh ijkl mnop')"
Write-Host ""

Write-Host "STEP 2: Update config.py" -ForegroundColor Cyan
Write-Host "-"*70
Write-Host "1. Notepad will open config.py"
Write-Host "2. Find line: GMAIL_APP_PASSWORD = ""...""" 
Write-Host "3. Replace with your NEW password"
Write-Host "4. Save (Ctrl+S) and close Notepad"
Write-Host ""

Write-Host "STEP 3: Test & Run" -ForegroundColor Cyan
Write-Host "-"*70
Write-Host "1. Script will test new password"
Write-Host "2. If valid, sends applications to 7 companies"
Write-Host ""

Write-Host "$('='*70)" -ForegroundColor Green
Read-Host "Press ENTER to start"
Write-Host ""

# Step 1: Open browser to app passwords page
Write-Host "[1/3] Opening browser to App Passwords page..." -ForegroundColor Cyan
Start-Process "https://myaccount.google.com/apppasswords"
Start-Sleep -Seconds 2

# Step 2: Open config.py in Notepad
Write-Host "[2/3] Opening config.py in Notepad..." -ForegroundColor Cyan
Write-Host "        Find: GMAIL_APP_PASSWORD = ""..."" " -ForegroundColor Yellow
Write-Host "        Replace with your NEW 16-character password" -ForegroundColor Yellow
Write-Host "        Save (Ctrl+S) and close Notepad when done" -ForegroundColor Yellow
Write-Host ""

$configPath = "F:\study\Dev_Toolchain\programming\python\apps\automation\job-auto-applicator\config.py"
Start-Process "notepad.exe" -ArgumentList $configPath -Wait

Write-Host ""
Write-Host "[3/3] Testing new Gmail credentials..." -ForegroundColor Cyan

# Test credentials
$testResult = python "F:\study\Dev_Toolchain\programming\python\apps\automation\job-auto-applicator\test_gmail_credentials.py" 2>&1

if ($LASTEXITCODE -eq 0 -and $testResult -like "*SUCCESS*") {
    Write-Host ""
    Write-Host "$('='*70)" -ForegroundColor Green
    Write-Host "SUCCESS! Gmail credentials are valid!" -ForegroundColor Green
    Write-Host "$('='*70)" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "Starting job applicator now..." -ForegroundColor Cyan
    Write-Host "$('='*70)`n" -ForegroundColor White
    
    # Run job applicator
    python "F:\study\Dev_Toolchain\programming\python\apps\automation\job-auto-applicator\job_applicator_smtp.py"
    
} else {
    Write-Host ""
    Write-Host "$('='*70)" -ForegroundColor Red
    Write-Host "ERROR: Gmail credentials still invalid" -ForegroundColor Red
    Write-Host "$('='*70)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Possible issues:" -ForegroundColor Yellow
    Write-Host "- Password not copied correctly" -ForegroundColor White
    Write-Host "- Extra spaces in password" -ForegroundColor White
    Write-Host "- 2-Step Verification not enabled" -ForegroundColor White
    Write-Host ""
    Write-Host "Try running this script again:" -ForegroundColor Cyan
    Write-Host 'powershell -ExecutionPolicy Bypass -File "F:\study\Dev_Toolchain\programming\python\apps\automation\job-auto-applicator\fix-and-run.ps1"' -ForegroundColor White
    Write-Host ""
}

Write-Host "`nPress ENTER to close..." -ForegroundColor Gray
Read-Host
