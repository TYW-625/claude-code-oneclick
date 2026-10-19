@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"

title Claude Code One-Click Installer

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*

if errorlevel 1 (
    echo.
    echo Installer finished with errors. Please read the messages above.
    pause
)
endlocal
