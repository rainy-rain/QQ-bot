# 停止 NapCat（只杀 D:\NapCatRun 下的进程，不碰你本机的 QQ）
$root = 'D:\NapCatRun'
$killed = 0
Get-CimInstance Win32_Process -Filter "Name='node.exe'" |
  Where-Object { $_.ExecutablePath -like "$root*" } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue; $killed++ }
Get-Process -Name 'NapCatWinBootMain' -ErrorAction SilentlyContinue |
  ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue; $killed++ }
Write-Host "已停止 $killed 个 NapCat 进程（你本机的主号 QQ 未受影响）"
