@echo off
chcp 65001 >nul
title Directory Test
echo Current directory: %cd%
echo.
echo Script directory: %~dp0
echo.
echo Switching to script directory...
cd /d "%~dp0"
echo.
echo New current directory: %cd%
echo.
echo Files in this directory:
dir /b
echo.
pause