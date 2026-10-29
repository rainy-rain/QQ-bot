# QQbot 环境自检：检查运行所需的组件是否齐全
# 退出码：0 = 可用（可能有警告）；2 = 缺关键组件，启动会失败

$rows = New-Object System.Collections.ArrayList

function Add-Check {
  param(
    [string]$Name,
    [bool]$Ok,
    [string]$Detail,
    [bool]$Critical = $false
  )
  $state = 'OK'
  if (-not $Ok) { if ($Critical) { $state = 'FAIL' } else { $state = 'WARN' } }
  [void]$rows.Add([pscustomobject]@{
    检查项 = $Name
    结果   = $state
    说明   = $Detail
  })
}

$root   = 'D:\NapCatRun'
$dshExe = 'D:\DSH-next\DSH NEXT\DSH NEXT.exe'
$prof   = 'C:\Users\rzy_r\.dsh\profiles\desktop'

# ---- 1. NapCat 主程序 -------------------------------------------------
$need = @("$root\napcat.bat", "$root\node.exe", "$root\wrapper.node", "$root\index.js")
$miss = @($need | Where-Object { -not (Test-Path $_) })
if ($miss.Count -eq 0) {
  Add-Check 'NapCat 主程序' $true 'D:\NapCatRun 完整' $true
} else {
  Add-Check 'NapCat 主程序' $false ("缺少: " + ($miss -join ', ')) $true
}

# ---- 2. NapCat 账号配置（是否登录过） ---------------------------------
$ob = @(Get-ChildItem (Join-Path $root 'napcat\config') -Filter 'onebot11_*.json' -ErrorAction SilentlyContinue)
if ($ob.Count -gt 0) {
  $uin = $ob[0].BaseName -replace 'onebot11_', ''
  Add-Check '小号配置' $true "已登录过 UIN $uin"
} else {
  Add-Check '小号配置' $false '还没有登录记录，首次启动需扫码'
}

# ---- 3. DSH 桌面应用 ---------------------------------------------------
if (Test-Path $dshExe) {
  Add-Check 'DSH 桌面应用' $true 'D:\DSH-next\DSH NEXT' $true
} else {
  Add-Check 'DSH 桌面应用' $false "找不到 $dshExe" $true
}

# ---- 4. dsh-onebot-qq 插件 --------------------------------------------
$plug = Join-Path $prof 'node_modules\dsh-onebot-qq\lib\index.js'
if (Test-Path $plug) {
  $ver = ''
  $pkg = Join-Path $prof 'node_modules\dsh-onebot-qq\package.json'
  if (Test-Path $pkg) { $ver = (Get-Content $pkg -Raw | ConvertFrom-Json).version }
  Add-Check 'QQ 通道插件' $true "dsh-onebot-qq $ver" $true
} else {
  Add-Check 'QQ 通道插件' $false '未安装（应安装在 desktop profile）' $true
}

# ---- 5. 插件配置是否写进 profile patch --------------------------------
$patchFile = Join-Path $prof 'cordis.patch.yml'
$hasCfg = $false
if (Test-Path $patchFile) {
  $hasCfg = [bool](Select-String -Path $patchFile -Pattern 'dsh-onebot' -Quiet)
}
if ($hasCfg) {
  Add-Check '插件配置' $true 'cordis.patch.yml 已含 dsh-onebot 段'
} else {
  Add-Check '插件配置' $false 'cordis.patch.yml 缺少 dsh-onebot 段' $true
}

# ---- 6. 端口占用 -------------------------------------------------------
foreach ($p in @(3001, 6099)) {
  $owner = Get-NetTCPConnection -State Listen -LocalPort $p -ErrorAction SilentlyContinue |
           Select-Object -First 1
  if (-not $owner) {
    Add-Check "端口 $p" $true '空闲'
  } else {
    $proc = Get-Process -Id $owner.OwningProcess -ErrorAction SilentlyContinue
    $isNapcat = $false
    if ($proc -and $proc.ProcessName -eq 'node') {
      $cmdline = (Get-CimInstance Win32_Process -Filter "ProcessId=$($proc.Id)").ExecutablePath
      if ($cmdline -like "$root*") { $isNapcat = $true }
    }
    if ($isNapcat) {
      Add-Check "端口 $p" $true 'NapCat 正在使用'
    } else {
      Add-Check "端口 $p" $false "被 $($proc.ProcessName) (PID $($owner.OwningProcess)) 占用"
    }
  }
}

# ---- 7. 可选：语音转写依赖 --------------------------------------------
$ff = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($ff) { Add-Check 'ffmpeg（语音转写）' $true $ff.Source }
else { Add-Check 'ffmpeg（语音转写）' $false '未安装，收到语音时只会显示[语音]占位' }

$wh = Get-Command whisper-cli -ErrorAction SilentlyContinue
if (-not $wh) { $wh = Get-Command whisper -ErrorAction SilentlyContinue }
if ($wh) { Add-Check 'whisper（语音转写）' $true $wh.Source }
else { Add-Check 'whisper（语音转写）' $false '未安装，不影响文字/图片聊天' }

# ---- 8. 磁盘空间 -------------------------------------------------------
$dFree = (Get-PSDrive D -ErrorAction SilentlyContinue).Free
if ($dFree -ne $null) {
  $freeGB = [Math]::Round($dFree / 1GB, 1)
  Add-Check 'D 盘剩余空间' ($freeGB -ge 1) "$freeGB GB"
}

# ---- 输出 --------------------------------------------------------------
Write-Host ''
Write-Host '---------- 环境自检 ----------' -ForegroundColor Cyan
$rows | Format-Table -AutoSize | Out-String | Write-Host

$fail = @($rows | Where-Object { $_.结果 -eq 'FAIL' }).Count
$warn = @($rows | Where-Object { $_.结果 -eq 'WARN' }).Count
$okn  = @($rows | Where-Object { $_.结果 -eq 'OK' }).Count

if ($fail -gt 0) {
  Write-Host "  结果：$okn 项通过，$warn 项可选缺失，$fail 项关键缺失" -ForegroundColor Red
  Write-Host '  关键组件缺失，无法启动。按上面「说明」补齐后重试。' -ForegroundColor Red
  exit 2
} elseif ($warn -gt 0) {
  Write-Host "  结果：$okn 项通过，$warn 项可选缺失（不影响文字/图片聊天）" -ForegroundColor Yellow
  exit 0
} else {
  Write-Host "  结果：$okn 项全部通过" -ForegroundColor Green
  exit 0
}
