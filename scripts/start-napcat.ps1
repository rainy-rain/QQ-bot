# 启动 NapCat（后台），日志写到 D:\NapCatRun\run.log
# 用法: .\start-napcat.ps1 [-Quick 1507001621]
param(
  [string]$Quick = ''
)
$ErrorActionPreference = 'Stop'
$root = 'D:\NapCatRun'
if (-not (Test-Path "$root\napcat.bat")) { throw "找不到 $root\napcat.bat，NapCat 未安装或路径不对" }

# 已在跑就不重复启动
$running = Get-CimInstance Win32_Process -Filter "Name='node.exe'" |
  Where-Object { $_.ExecutablePath -like "$root*" }
if ($running) {
  Write-Host "NapCat 已在运行 (PID: $($running.ProcessId -join ', '))"
  exit 0
}

$log = "$root\run.log"
Remove-Item $log -ErrorAction SilentlyContinue
$args = @()
if ($Quick) { $args = @('-q', $Quick) }
Start-Process -FilePath "$root\napcat.bat" -ArgumentList $args -WorkingDirectory $root `
  -RedirectStandardOutput $log -RedirectStandardError "$root\run.err.log" -WindowStyle Hidden
Start-Sleep -Seconds 15

$token = (Select-String -Path $log -Pattern 'WebUi Token: (\w+)' | Select-Object -Last 1).Matches[0].Groups[1].Value
Write-Host "已启动。WebUI: http://127.0.0.1:6099/webui?token=$token"
if ($Quick) { Write-Host "已尝试快速登录 $Quick（可能需要手Q验证，失败会退回二维码，见 $log）" }
