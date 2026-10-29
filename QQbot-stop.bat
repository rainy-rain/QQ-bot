@echo off
chcp 65001 >nul
title QQbot 停止
echo 正在停止 NapCat（不会关闭 DSH 桌面应用，也不会影响你本机主号 QQ）...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\stop-napcat.ps1"
echo.
pause
