# 一键看状态：NapCat 进程 / 端口 / 登录态 / 插件连接
$root = 'D:\NapCatRun'
Write-Host '=== NapCat 进程 ==='
Get-CimInstance Win32_Process -Filter "Name='node.exe'" |
  Where-Object { $_.ExecutablePath -like "$root*" } |
  Select-Object ProcessId, @{n='Path';e={$_.ExecutablePath}} | Format-Table -AutoSize

Write-Host '=== 端口 ==='
$ports = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
  Where-Object { $_.LocalPort -in 3001, 6099 } | Select-Object LocalAddress, LocalPort
if ($ports) { $ports | Format-Table -AutoSize } else { Write-Host '(3001/6099 都没在监听 → NapCat 没起来或没登录)' }

Write-Host '=== 插件 ↔ NapCat 连接 ==='
$conn = Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue |
  Where-Object { $_.RemotePort -eq 3001 -or $_.LocalPort -eq 3001 }
if ($conn) { Write-Host '已连接' } else { Write-Host '未连接' }

Write-Host '=== 宿主日志最近的 onebot 行 ==='
$log = 'C:\Users\rzy_r\.dsh\logs\desktop-next.log'
if (Test-Path $log) {
  Select-String -Path $log -Pattern '\[dsh-onebot\]' | Select-Object -Last 6 |
    ForEach-Object { $_.Line.Substring(0, [Math]::Min(160, $_.Line.Length)) }
}

Write-Host '=== 登录的小号 ==='
Get-ChildItem "$root\napcat\config" -Filter 'onebot11_*.json' -ErrorAction SilentlyContinue |
  ForEach-Object { $_.BaseName -replace 'onebot11_', 'UIN: ' }
