@echo off
:: Run dkill.ps1 with admin privileges (required for diskpart)
powershell -Command "Start-Process powershell -ArgumentList '-ExecutionPolicy Bypass -File \"%~dp0dkill.ps1\"' -Verb RunAs -WindowStyle Normal"
