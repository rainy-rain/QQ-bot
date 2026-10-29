@echo off
chcp 65001 >nul
title QQbot stop
echo Stopping NapCat (DSH and your main QQ are not affected)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\stop-napcat.ps1"
echo.
pause