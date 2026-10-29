# 启动 NapCat（脱离当前进程树，DSH 关闭 / 命令窗口关闭都不会带走它）
# 用法: .\start-napcat.ps1 [-Quick 1507001621]
param(
  [string]$Quick = '1507001621'
)

$root = 'D:\NapCatRun'
if (-not (Test-Path "$root\napcat.bat")) { throw "找不到 $root\napcat.bat，NapCat 未安装或路径不对" }

# 已在跑就不重复启动
$running = Get-CimInstance Win32_Process -Filter "Name='node.exe'" |
  Where-Object { $_.ExecutablePath -like "$root*" }
if ($running) {
  Write-Host "NapCat 已在运行 (PID: $($running.ProcessId -join ', '))"
  exit 0
}

# 关键：用 WMI 创建进程，父进程是 WmiPrvSE 而不是当前 shell。
# 否则 NapCat 会落在 DSH 命令执行的 job object 里，DSH 一退出就被一起杀掉。
$svc = "$root\napcat-service.bat"
$cmd = "`"C:\Windows\System32\cmd.exe`" /c `"$svc`""
$r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmd }
if ($r.ReturnValue -ne 0) { throw "启动失败，WMI ReturnValue=$($r.ReturnValue)" }

Start-Sleep -Seconds 20
$token = (Select-String -Path "$root\run.log" -Pattern 'WebUi Token: (\w+)' |
  Select-Object -Last 1).Matches[0].Groups[1].Value

Write-Host "已启动（PID $($r.ProcessId)，已脱离当前 shell）"
Write-Host "WebUI: http://127.0.0.1:6099/webui?token=$token"
Write-Host "日志:  $root\run.log"
if ($Quick) { Write-Host "已尝试快速登录 $Quick；失败会退回二维码，见日志" }
