@echo off
chcp 65001 >nul
title QQbot 启动器
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\launch.ps1"
echo.
pause
