@echo off
chcp 65001 >nul
title QQbot environment check
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\check-env.ps1"
echo.
pause