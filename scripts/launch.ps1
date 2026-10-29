# QQbot 启动器：一键拉起 NapCat + DSH 宿主，等待就绪；需要扫码时自动打开 WebUI。
# 由 QQbot.bat 调用（双击即可）。本文件须以 UTF-8 with BOM 保存，否则 PowerShell 5.1 会读乱中文。

$ErrorActionPreference = 'Stop'
$root   = 'D:\NapCatRun'
$dshExe = 'D:\DSH-next\DSH NEXT\DSH NEXT.exe'
$log    = Join-Path $root 'run.log'

function Write-Step($n, $text) {
  Write-Host ''
  Write-Host "[$n] $text" -ForegroundColor Cyan
}
function Test-Port([int]$port) {
  [bool](Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
         Where-Object { $_.LocalPort -eq $port })
}
function Get-NapCatProcess {
  Get-CimInstance Win32_Process -Filter "Name='node.exe'" |
    Where-Object { $_.ExecutablePath -like "$root*" }
}
function Get-WebUiToken {
  $t = ''
  if (Test-Path $log) {
    $m = Select-String -Path $log -Pattern 'WebUi Token: (\w+)' | Select-Object -Last 1
    if ($m) { $t = $m.Matches[0].Groups[1].Value }
  }
  if (-not $t) {
    $wj = Join-Path $root 'napcat\config\webui.json'
    if (Test-Path $wj) { $t = (Get-Content $wj -Raw | ConvertFrom-Json).token }
  }
  return $t
}

Write-Host '======================================' -ForegroundColor DarkCyan
Write-Host '  QQbot  ·  QQ 小号虚拟人物 启动器'      -ForegroundColor DarkCyan
Write-Host '======================================' -ForegroundColor DarkCyan

# ---------------------------------------------------------------- 1. NapCat
Write-Step 1 '检查 NapCat（QQ 登录进程）...'
$napcat = Get-NapCatProcess
if ($napcat) {
  Write-Host "    已在运行 (PID $($napcat.ProcessId -join ', '))，跳过启动" -ForegroundColor Green
} else {
  $svc = Join-Path $root 'napcat-service.bat'
  if (-not (Test-Path $svc)) { throw "找不到 $svc" }
  # 用 WMI 创建进程：父进程是 WmiPrvSE，脱离 DSH 命令的 job object，
  # 关掉本窗口或重启 DSH 都不会把 QQ 一起带走。
  $cmd = "`"C:\Windows\System32\cmd.exe`" /c `"$svc`""
  $r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmd }
  if ($r.ReturnValue -ne 0) { throw "NapCat 启动失败，WMI ReturnValue=$($r.ReturnValue)" }
  Write-Host "    已启动 (PID $($r.ProcessId))，正在登录 QQ..." -ForegroundColor Green
}

# ---------------------------------------------------------------- 2. DSH 宿主
Write-Step 2 '检查 DSH 宿主（插件运行环境）...'
$dsh = Get-Process -Name 'DSH NEXT' -ErrorAction SilentlyContinue
if ($dsh) {
  Write-Host "    已在运行 (PID $($dsh[0].Id))，跳过启动" -ForegroundColor Green
} else {
  if (-not (Test-Path $dshExe)) { throw "找不到 DSH：$dshExe" }
  Start-Process -FilePath $dshExe
  Write-Host '    已启动 DSH 桌面应用（加载需要几秒）' -ForegroundColor Green
}

# ---------------------------------------------------------------- 3. 等待就绪
Write-Step 3 '等待 QQ 上线 + 插件连上...'
$startLine = 0
if (Test-Path $log) { $startLine = @(Get-Content $log -Encoding UTF8 -ErrorAction SilentlyContinue).Count }
$startedAt = Get-Date
# 刚启动的 NapCat 要做快速登录，给 30 秒；已经在跑却只有 6099 没 3001，基本就是在等扫码
if ($napcat) { $graceSec = 4 } else { $graceSec = 30 }
$deadline = (Get-Date).AddSeconds(90)
$okConn = $false
$needScan = $false
while ((Get-Date) -lt $deadline) {
  Start-Sleep -Milliseconds 1500
  Write-Host '.' -NoNewline -ForegroundColor DarkGray

  if (Test-Port 3001) {
    $conn = Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue |
      Where-Object { $_.RemotePort -eq 3001 -or $_.LocalPort -eq 3001 }
    if ($conn) { $okConn = $true; break }
  }
  # 只认本次启动之后新写入的二维码日志：已登录时旧日志里的二维码不算
  if (Test-Path $log) {
    $newLines = @(Get-Content $log -Encoding UTF8 -ErrorAction SilentlyContinue | Select-Object -Skip $startLine)
    if ($newLines -match '二维码已保存') { $needScan = $true; break }
  }
  # 宽限期过后仍只有 WebUI 没有 OneBot = 卡在扫码
  if ((((Get-Date) - $startedAt).TotalSeconds -gt $graceSec) -and (Test-Port 6099) -and -not (Test-Port 3001)) {
    $needScan = $true; break
  }
}
Write-Host ''

# ---------------------------------------------------------------- 4. 结果（重新查询，不用旧变量）
Write-Step 4 '状态'
$napcatNow = Get-NapCatProcess
$p3001 = Test-Port 3001
$p6099 = Test-Port 6099
$connNow = Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue |
  Where-Object { $_.RemotePort -eq 3001 -or $_.LocalPort -eq 3001 }

$cfgFile = Get-ChildItem (Join-Path $root 'napcat\config') -Filter 'onebot11_*.json' -ErrorAction SilentlyContinue |
           Select-Object -First 1
$uin = ''
if ($cfgFile) { $uin = $cfgFile.BaseName -replace 'onebot11_', '' }

$sNapcat = '未运行'
if ($napcatNow) { $sNapcat = '运行中 (PID ' + (($napcatNow.ProcessId) -join ',') + ')' }
$sPort = '未监听'
if ($p3001) { $sPort = '监听中' }
$sUi = '未监听'
if ($p6099) { $sUi = '监听中' }
$sConn = '未连接'
if ($connNow) { $sConn = '已连接' }
$sUin = '未知'
if ($uin) { $sUin = $uin }

@(
  [pscustomobject]@{ 项目 = 'NapCat 进程';  状态 = $sNapcat },
  [pscustomobject]@{ 项目 = 'OneBot 3001'; 状态 = $sPort },
  [pscustomobject]@{ 项目 = 'WebUI 6099';  状态 = $sUi },
  [pscustomobject]@{ 项目 = '插件连接';    状态 = $sConn },
  [pscustomobject]@{ 项目 = '小号 UIN';    状态 = $sUin }
) | Format-Table -AutoSize | Out-String | Write-Host

$webui = 'http://127.0.0.1:6099/webui'
$token = Get-WebUiToken
if ($token) { $webui = $webui + '?token=' + $token }

if ($connNow) {
  Write-Host '  OK  QQbot 已就绪，可以直接在 QQ 里私聊小号了。' -ForegroundColor Green
} elseif ($needScan -or ($p6099 -and -not $p3001)) {
  Write-Host '  !   QQ 登录态失效，需要扫码。' -ForegroundColor Yellow
  Write-Host "      已为你打开扫码页：$webui" -ForegroundColor Yellow
  Write-Host '      用【小号】的手机 QQ 扫，扫完立刻点允许登录。' -ForegroundColor Yellow
  Start-Process $webui
  Write-Host ''
  Write-Host '      扫完后再双击一次 QQbot.bat 即可看到「已就绪」。' -ForegroundColor DarkGray
} elseif ($p3001) {
  Write-Host '  !   NapCat 已登录，但插件还没连上。' -ForegroundColor Yellow
  Write-Host '      若刚启动 DSH，等 1 分钟；否则检查插件是否启用。' -ForegroundColor Yellow
} else {
  Write-Host '  !   NapCat 没起来。看日志：' -ForegroundColor Red
  Write-Host "      $log" -ForegroundColor Red
}

Write-Host ''
Write-Host '  常用命令（在 QQ 里发给小号）：' -ForegroundColor DarkGray
Write-Host '    /new      开新会话（清空上下文）' -ForegroundColor DarkGray
Write-Host '    /status   查看会话状态'           -ForegroundColor DarkGray
Write-Host '    /doctor   体检'                   -ForegroundColor DarkGray
Write-Host ''
Write-Host "  QQ 日志：$log" -ForegroundColor DarkGray
Write-Host '  宿主日志：C:\Users\rzy_r\.dsh\logs\desktop-next.log' -ForegroundColor DarkGray
Write-Host ''
