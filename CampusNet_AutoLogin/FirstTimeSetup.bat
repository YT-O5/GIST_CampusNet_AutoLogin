@echo off
chcp 65001 >nul
title Campus Network - First Time Setup
mode con: cols=70 lines=20

REM ============================================
REM 切换到脚本所在目录（关键修复！）
REM ============================================
cd /d "%~dp0"

cls

echo ========================================
echo   CAMPUS NETWORK - FIRST TIME SETUP
echo ========================================
echo.
echo This wizard will help you configure the auto-login system.
echo You will need:
echo   1. Your student ID
echo   2. Your campus network password
echo.
echo Please ensure you are connected to the campus network
echo (via Ethernet cable or WiFi) before proceeding.
echo.
echo Press any key to start setup...
pause >nul

REM Run PowerShell setup
PowerShell -ExecutionPolicy Bypass -NoProfile -File "CampusNet_Login.ps1" -Setup

echo.
echo Setup complete!
echo You can now use "CampusNet.bat" to auto-login.
echo.
pause