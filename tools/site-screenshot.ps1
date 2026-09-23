# 실제 사이트 화면을 휴대폰 크기로 캡처 (블로그·SNS용). 백그라운드 크롬(DevTools)으로 버튼까지 눌러 줌
#   -Mode pick : 메인 페이지에서 -Meal(아침/점심/저녁), -Cat(한식 등)을 고르고 -Target 메뉴가 나올 때까지 추천받기를 눌러 결과를 찍음
#   -Mode page : -Url 페이지를 열어 위쪽(-ScrollTo px 로 내려서)을 찍음
#   -Out 은 "뭐 먹지 프로젝트 마케팅" 폴더 기준 경로 (tools\marketing-path.ps1)
# 예: powershell -ExecutionPolicy Bypass -File tools\site-screenshot.ps1 -Meal 저녁 -Cat 가볍게 -Target 도토리묵무침 `
#       -Out naver-blog\posts\01-dotorimuk\02-site-pick.png
# 이 스크립트가 띄운 크롬(cdp-shot-profile)만 끄고, 평소 쓰는 크롬은 건드리지 않음
param([string]$Mode = 'pick', [string]$Url = 'https://meal-project.pages.dev/', [string]$Meal = '', [string]$Cat = '',
      [string]$Target = '', [string]$Out, [int]$W = 390, [int]$H = 844, [int]$ScrollTo = -1)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'marketing-path.ps1')
if (-not [IO.Path]::IsPathRooted($Out)) { $Out = Join-Path $MarketingDir $Out }
New-Item -ItemType Directory -Force (Split-Path -Parent $Out) | Out-Null
$chrome = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
$port = 9231
$prof = Join-Path $env:TEMP 'cdp-shot-profile'
$proc = Start-Process $chrome -ArgumentList @('--headless=new', "--remote-debugging-port=$port", "--user-data-dir=$prof", '--no-first-run', '--hide-scrollbars', "--window-size=$W,$H", 'about:blank') -PassThru
try {
  $targets = $null
  for ($i = 0; $i -lt 40 -and -not $targets; $i++) { Start-Sleep -Milliseconds 250; try { $targets = Invoke-RestMethod "http://127.0.0.1:$port/json" } catch {} }
  $page = @($targets | Where-Object { $_.type -eq 'page' })[0]
  $ws = New-Object System.Net.WebSockets.ClientWebSocket
  $ws.Options.KeepAliveInterval = [TimeSpan]::FromSeconds(30)
  $ws.ConnectAsync([Uri]$page.webSocketDebuggerUrl, [Threading.CancellationToken]::None).Wait()
  $script:id = 0
  function Send($method, $params) {
    $script:id++
    $msg = @{ id = $script:id; method = $method; params = $(if ($params) { $params } else { @{} }) } | ConvertTo-Json -Depth 10 -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($msg)
    $ws.SendAsync((New-Object ArraySegment[byte] (, $bytes)), 'Text', $true, [Threading.CancellationToken]::None).Wait()
    $want = $script:id
    while ($true) {
      $ms = New-Object IO.MemoryStream
      do {
        $buf = New-Object byte[] 65536
        $seg = New-Object ArraySegment[byte] (, $buf)
        $r = $ws.ReceiveAsync($seg, [Threading.CancellationToken]::None).Result
        $ms.Write($buf, 0, $r.Count)
      } while (-not $r.EndOfMessage)
      $obj = [Text.Encoding]::UTF8.GetString($ms.ToArray()) | ConvertFrom-Json
      if ($obj.id -eq $want) { return $obj }
    }
  }
  function Eval($js) { (Send 'Runtime.evaluate' @{ expression = $js; awaitPromise = $true; returnByValue = $true }).result.result.value }

  Send 'Emulation.setDeviceMetricsOverride' @{ width = $W; height = $H; deviceScaleFactor = 3; mobile = $true } | Out-Null
  Send 'Page.enable' $null | Out-Null
  Send 'Page.navigate' @{ url = $Url } | Out-Null
  Start-Sleep -Seconds 4

  if ($Mode -eq 'pick') {
    $js = @"
(async () => {
  const sleep = ms => new Promise(r => setTimeout(r, ms));
  const byText = (sel, t) => Array.from(document.querySelectorAll(sel)).find(b => b.textContent.trim() === t);
  for (let i = 0; i < 40 && document.getElementById('pick-btn').disabled; i++) await sleep(250);
  if ('$Meal') { byText('#meal-tabs button', '$Meal').click(); await sleep(400); }
  if ('$Cat') { const c = byText('#filters button', '$Cat'); if (c) { c.click(); await sleep(400); } }
  let name = '';
  for (let i = 0; i < 40; i++) {
    document.getElementById('pick-btn').click();
    await sleep(2600);
    name = document.getElementById('menu').textContent.trim();
    if (!'$Target' || name === '$Target') break;
  }
  const img = document.querySelector('#photo img');
  for (let i = 0; i < 40 && img && !(img.complete && img.naturalWidth); i++) await sleep(250);
  await sleep(600);
  const card = document.querySelector('section.card');
  window.scrollTo(0, card.getBoundingClientRect().top + window.scrollY - 12);
  await sleep(500);
  return name;
})()
"@
    $name = Eval $js
    Write-Host "picked: $name"
  } elseif ($ScrollTo -ge 0) {
    Eval "window.scrollTo(0, $ScrollTo); 1" | Out-Null
    Start-Sleep -Milliseconds 800
  }
  $shot = Send 'Page.captureScreenshot' @{ format = 'png' }
  [IO.File]::WriteAllBytes($Out, [Convert]::FromBase64String($shot.result.data))
  Write-Host "saved $Out"
} finally {
  try { $ws.Dispose() } catch {}
  Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
  # only the headless Chrome started here (its own profile folder), never the user's Chrome
  Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" | Where-Object { $_.CommandLine -like '*cdp-shot-profile*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}
