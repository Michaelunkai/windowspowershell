@echo off
:: Run CPU Monitor Pro as Administrator
cd /d "%~dp0"
powershell -Command "Start-Process 'C:\Users\User\AppData\Local\Programs\Python\Python312\pythonw.exe' -ArgumentList 'cpu_monitor.py' -WorkingDirectory '%~dp0' -Verb RunAs"
