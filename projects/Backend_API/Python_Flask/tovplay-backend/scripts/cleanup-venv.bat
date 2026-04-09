@echo off
REM Script to clean up virtual environment files from the repository

REM Remove the venv directory from git tracking
git rm -r --cached venv/

REM Add venv to .gitignore if not already there
findstr /C:"venv/" .gitignore >nul
if %errorlevel% neq 0 (
    echo. >> .gitignore
    echo # Virtual environment >> .gitignore
    echo venv/ >> .gitignore
)

echo Virtual environment removed from git tracking. Please commit these changes.