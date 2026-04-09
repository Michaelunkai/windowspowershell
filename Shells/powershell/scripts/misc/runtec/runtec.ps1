<#
.SYNOPSIS
    runtec
#>
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd F:\tovtech\histadrut\cv-scout; F:\tovtech\histadrut\cv-scout\venv\Scripts\python.exe -m flask --app app run --host 0.0.0.0 --port 5001"; Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd F:\tovtech\histadrut\histadrut-front; vite"; Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd F:\tovtech\histadrut\semantic-matches; node Graphana_infinity_proxy.js"; Start-Process cmd -ArgumentList "/k", "cd /d F:\tovtech\histadrut\scrapers && run.bat"
