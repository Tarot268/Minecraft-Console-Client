@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Expand-CompletePackage.ps1"
if errorlevel 1 (
    echo Extraction failed. Read the error above.
    pause
    exit /b 1
)
pause
