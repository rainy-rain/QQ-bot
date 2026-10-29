@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title QQbot 启动器

set "ROOT=D:\NapCatRun"
set "PROF=C:\Users\rzy_r\.dsh\profiles\desktop"
set /a FAIL=0
set /a WARN=0

echo ======================================
echo    QQbot  ·  QQ 小号虚拟人物
echo ======================================
echo.
echo [0] 环境自检
echo --------------------------------------

call :need "NapCat napcat.bat" "%ROOT%\napcat.bat"
call :need "NapCat node.exe" "%ROOT%\node.exe"
call :need "NapCat wrapper.node" "%ROOT%\wrapper.node"
call :need "NapCat index.js" "%ROOT%\index.js"
call :need "DSH 桌面应用" "D:\DSH-next\DSH NEXT\DSH NEXT.exe"
call :need "QQ 通道插件" "%PROF%\node_modules\dsh-onebot-qq\lib\index.js"

set "UIN="
for %%f in ("%ROOT%\napcat\config\onebot11_*.json") do (
  if exist "%%~f" set "UIN=%%~nf"
)
if defined UIN (
  set "UIN=!UIN:onebot11_=!"
  echo   [OK]   小号配置     已登录过 UIN !UIN!
) else (
  echo   [WARN] 小号配置     没有登录记录，首次启动需要扫码
  set /a WARN+=1
)

findstr /C:"dsh-onebot" "%PROF%\cordis.patch.yml" >nul 2>&1
if errorlevel 1 (
  echo   [FAIL] 插件配置     cordis.patch.yml 缺少 dsh-onebot 段
  set /a FAIL+=1
) else (
  echo   [OK]   插件配置     已含 dsh-onebot 段
)

call :port 3001
call :port 6099

where ffmpeg >nul 2>&1
if errorlevel 1 (
  echo   [WARN] ffmpeg       未安装，语音只会显示占位
  set /a WARN+=1
) else (
  echo   [OK]   ffmpeg       已安装
)

set "WH="
where whisper-cli >nul 2>&1 && set "WH=1"
where whisper >nul 2>&1 && set "WH=1"
if defined WH (
  echo   [OK]   whisper      已安装
) else (
  echo   [WARN] whisper      未安装，不影响文字和图片
  set /a WARN+=1
)

echo --------------------------------------
if %FAIL% GTR 0 (
  echo    关键组件缺失 %FAIL% 项，已中止启动，按上面的说明补齐后重试。
  echo.
  pause
  exit /b 2
)
echo    自检通过，可选缺失 %WARN% 项
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\launch.ps1"
echo.
pause
exit /b 0

:need
if exist "%~2" (
  echo   [OK]   %~1
) else (
  echo   [FAIL] %~1 缺失，应位于 %~2
  set /a FAIL+=1
)
exit /b 0

:port
netstat -ano | findstr /C:LISTENING | findstr /C:":%~1 " >nul
if errorlevel 1 (
  echo   [OK]   端口 %~1      空闲
) else (
  echo   [--]   端口 %~1      已在使用，可能是 NapCat 已经在跑
)
exit /b 0