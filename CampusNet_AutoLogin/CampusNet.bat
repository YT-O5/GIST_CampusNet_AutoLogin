@echo off
chcp 65001 >nul
title Campus Network Auto Login System
mode con: cols=80 lines=30

REM ============================================
REM 切换到脚本所在目录（关键修复！）
REM ============================================
cd /d "%~dp0"

cls

echo ========================================
echo   CAMPUS NETWORK AUTO LOGIN SYSTEM
echo   Guangzhou Institute of Science and Technology
echo ========================================
echo.

REM Check if PowerShell script exists
if not exist "CampusNet_Login.ps1" (
    echo ERROR: CampusNet_Login.ps1 not found!
    echo Current directory: %cd%
    echo Please ensure all files are in the same folder.
    echo.
    echo Files in current directory:
    dir /b
    echo.
    pause
    exit /b 1
)

REM Run PowerShell script
echo Starting auto-login system...
echo.

PowerShell -ExecutionPolicy Bypass -NoProfile -File "CampusNet_Login.ps1"

REM Check if PowerShell command succeeded
if %errorlevel% neq 0 (
    echo.
    echo ERROR: PowerShell script failed with error code %errorlevel%
    echo.
    pause
)

exit /b 0