# 음식 사진 출처표 채우기 (tools/photos.csv)
#
# Supabase menus 테이블의 사진 가운데 photos.csv 에 아직 없는 것만
# 위키미디어 공용에서 작가와 라이선스를 찾아 표에 더합니다. (이미 있는 줄은 손대지 않음)
# 대부분의 사진은 "작가 이름 + 라이선스"를 표시해야 쓸 수 있어서, 사이트는 이 표로 출처를 보여 줍니다.
#
# 실행 (프로젝트 폴더에서):
#   powershell -ExecutionPolicy Bypass -File tools\photo-credits.ps1
# 그다음 tools\build-pages.ps1 을 실행하세요.
#
# 새로 더해진 줄은 한 번 눈으로 확인하세요. 작가 칸이 비었거나 길면 직접 고쳐도 됩니다.
# GFDL, NC(비영리), ND(변경 금지) 라이선스 사진은 수익 사이트에 쓰기 어려우니 다른 사진으로 바꾸세요.

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = 'Tls12'

$Root = Split-Path -Parent $PSScriptRoot
$Utf8 = New-Object System.Text.UTF8Encoding($false)
$CsvPath = Join-Path $PSScriptRoot 'photos.csv'
$UserAgent = 'nyangchef-site-license-check/1.0 (https://meal-project.pages.dev/)'

function Q([string]$s) { '"' + $s.Replace('"', '""') + '"' }
function Strip([string]$html) {
  if (-not $html) { return '' }
  $t = [System.Net.WebUtility]::HtmlDecode([regex]::Replace($html, '<[^>]+>', ' '))
  ([regex]::Replace($t, '\s+', ' ')).Trim()
}

$lines = @('"사진 파일","메뉴","작가","라이선스","라이선스 주소"')
$known = @{}
if (Test-Path -LiteralPath $CsvPath) {
  $text = [IO.File]::ReadAllText($CsvPath, $Utf8).TrimStart([char]0xFEFF)
  foreach ($row in @($text -split "\r?\n" | Where-Object { $_.Trim() } | ConvertFrom-Csv)) {
    $known[[string]$row.'사진 파일'] = $true
    $lines += (Q $row.'사진 파일') + ',' + (Q $row.'메뉴') + ',' + (Q $row.'작가') + ',' + (Q $row.'라이선스') + ',' + (Q $row.'라이선스 주소')
  }
}

$config = [IO.File]::ReadAllText((Join-Path $Root 'config.js'), $Utf8)
$sbUrl = [regex]::Match($config, "supabaseUrl:\s*'([^']+)'").Groups[1].Value
$sbKey = [regex]::Match($config, "supabaseKey:\s*'([^']+)'").Groups[1].Value
$r = Invoke-WebRequest -UseBasicParsing -Uri "$sbUrl/rest/v1/menus?select=id,name,photo&order=id" -Headers @{ apikey = $sbKey }
$menus = @(($Utf8.GetString($r.RawContentStream.ToArray()) | ConvertFrom-Json) | ForEach-Object { $_ })
$missing = @($menus | Where-Object { $_.photo -and -not $known[[string]$_.photo] })

foreach ($m in $missing) {
  $body = @{ action = 'query'; format = 'json'; formatversion = '2'; prop = 'imageinfo'; iiprop = 'extmetadata'; iiextmetadatafilter = 'Artist|LicenseShortName|LicenseUrl'; titles = 'File:' + $m.photo }
  $resp = Invoke-WebRequest -UseBasicParsing -Method Post -Uri 'https://commons.wikimedia.org/w/api.php' -Body $body -UserAgent $UserAgent
  $page = @(($Utf8.GetString($resp.RawContentStream.ToArray()) | ConvertFrom-Json).query.pages)[0]
  $meta = $page.imageinfo[0].extmetadata
  $artist = Strip $meta.Artist.value
  $license = [string]$meta.LicenseShortName.value
  $lines += (Q ([string]$m.photo)) + ',' + (Q ([string]$m.id + ' ' + $m.name)) + ',' + (Q $artist) + ',' + (Q $license) + ',' + (Q ([string]$meta.LicenseUrl.value))
  Write-Host ("added: {0} {1} | {2} | {3}" -f $m.id, $m.name, $artist, $license)
  if ($license -match 'GFDL|NC|ND') { Write-Warning ("{0} {1}: '{2}' 라이선스는 수익 사이트에 쓰기 어려워요. 다른 사진으로 바꾸세요." -f $m.id, $m.name, $license) }
  Start-Sleep -Milliseconds 500
}

[IO.File]::WriteAllText($CsvPath, (($lines -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
Write-Host ("Done: {0} new photo(s) added to tools\photos.csv" -f $missing.Count)
