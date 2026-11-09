<#
  Windows 시작 시간 비교: Impeller 켬/끔/기본을 같은 조건으로 여러 번 띄워 "창이 보일 때까지" 걸린 시간을 잰다.

  사용법 (먼저 릴리스로 빌드: flutter build windows --release):
    powershell -File tool/startup_ab.ps1 [-Pdf 열PDF경로] [-Runs 5] [-Exe 실행파일]

  Debug 빌드는 JIT라 느려서 비교가 안 된다. 창이 보인 시점은 메인 창 핸들이 생기고 화면에 보일 때(Dart 쪽 show() 뒤)다.
  각 실행은 끝나면 종료한다. 결과는 평균·최소·최대(ms).
#>
param(
  [string]$Pdf = '',
  [int]$Runs = 5,
  [string]$Exe = (Join-Path $PSScriptRoot '..\build\windows\x64\runner\Release\daylight_pdf.exe')
)

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Win { [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h); }
'@

if (-not (Test-Path $Exe)) { throw "실행 파일이 없어요: $Exe  (flutter build windows --release 먼저)" }

function Measure-Start([string]$mode) {
  $env:DAYLIGHT_IMPELLER = $mode          # '' = 기본값
  if ($mode -eq 'default') { Remove-Item Env:DAYLIGHT_IMPELLER -ErrorAction SilentlyContinue }
  $args = @('--new-window'); if ($Pdf) { $args += $Pdf }
  $sw = [Diagnostics.Stopwatch]::StartNew()
  $proc = Start-Process -FilePath $Exe -ArgumentList $args -PassThru
  $ms = $null
  while ($sw.ElapsedMilliseconds -lt 60000) {
    $proc.Refresh()
    if ($proc.HasExited) { break }
    if ($proc.MainWindowHandle -ne [IntPtr]::Zero -and [Win]::IsWindowVisible($proc.MainWindowHandle)) { $ms = $sw.ElapsedMilliseconds; break }
    Start-Sleep -Milliseconds 10
  }
  if (-not $proc.HasExited) { Start-Sleep -Milliseconds 500; $proc.CloseMainWindow() | Out-Null; if (-not $proc.WaitForExit(3000)) { $proc.Kill() } }
  return $ms
}

$modes = @('default', '1', '0')
$labels = @{ 'default' = 'Flutter 기본'; '1' = 'Impeller 켬'; '0' = 'Impeller 끔' }
# 첫 실행은 파일 캐시가 차가워서 버린다.
[void](Measure-Start 'default')
$all = @{}
foreach ($m in $modes) { $all[$m] = @() }
for ($i = 0; $i -lt $Runs; $i++) {
  foreach ($m in $modes) { $all[$m] += Measure-Start $m }   # 섞어서 돌려 캐시·온도 편향을 줄인다
}
Remove-Item Env:DAYLIGHT_IMPELLER -ErrorAction SilentlyContinue
foreach ($m in $modes) {
  $v = $all[$m] | Where-Object { $_ -ne $null }
  if (-not $v) { "{0,-14} 측정 실패" -f $labels[$m]; continue }
  $s = $v | Measure-Object -Average -Minimum -Maximum
  "{0,-14} 평균 {1,6:N0} ms   최소 {2,6:N0}   최대 {3,6:N0}   ({4}회: {5})" -f $labels[$m], $s.Average, $s.Minimum, $s.Maximum, $v.Count, ($v -join ', ')
}
