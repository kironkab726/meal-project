# 요리일기 post.txt + 그림 → 네이버 블로그 모바일처럼 보이는 미리보기 한 장 (preview.html, 그림 내장)
# 실행: powershell -ExecutionPolicy Bypass -File tools\make-blog-preview.ps1 -Dir naver-blog\posts\01-dotorimuk
#   (-Dir 는 "뭐 먹지 프로젝트 마케팅" 폴더 기준 경로)
param([string]$Dir)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'marketing-path.ps1')
if (-not [IO.Path]::IsPathRooted($Dir)) { $Dir = Join-Path $MarketingDir $Dir }
$lines = [IO.File]::ReadAllLines((Join-Path $Dir 'post.txt'), [Text.Encoding]::UTF8)
function Enc([string]$s) { [System.Net.WebUtility]::HtmlEncode($s) }

$title = ''; $tags = ''; $body = @(); $mode = ''
for ($i = 0; $i -lt $lines.Count; $i++) {
  $l = $lines[$i]
  if ($l -eq '[제목]') { $title = $lines[$i + 1]; $i++; continue }
  if ($l -like '[태그]*') { $tags = $lines[$i + 1]; $i++; continue }
  if ($l -eq '[본문]  ※ [사진 ...] 줄에는 글 대신 그 사진을 넣으세요. 나머지 줄은 그대로 붙여 넣으면 돼요.') { $mode = 'body'; $i++; continue }
  if ($mode -eq 'body') { $body += $l }
}

$html = New-Object Text.StringBuilder
foreach ($l in $body) {
  $t = $l.Trim()
  if ($t -match '^\[사진 ([^\]]+)\]') {
    $f = Join-Path $Dir $Matches[1]
    $mime = if ($f -like '*.png') { 'image/png' } else { 'image/jpeg' }
    $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($f))
    [void]$html.AppendLine("<figure><img src=""data:$mime;base64,$b64"" alt=""""><figcaption>$(Enc $Matches[1])</figcaption></figure>")
  } elseif ($t -like '■*') {
    [void]$html.AppendLine("<h3>$(Enc $t.TrimStart('■').Trim())</h3>")
  } elseif ($t -match '^https?://') {
    [void]$html.AppendLine("<p><a href=""$(Enc $t)"">$(Enc $t)</a></p>")
  } elseif ($t -like '─*') {
    [void]$html.AppendLine('<hr>')
  } elseif ($t -eq '') {
    [void]$html.AppendLine('<div class="gap"></div>')
  } else {
    [void]$html.AppendLine("<p>$(Enc $t)</p>")
  }
}
$tagHtml = ($tags -split ',' | ForEach-Object { '<span>#' + (Enc $_.Trim()) + '</span>' }) -join ' '

$page = @"
<!doctype html>
<html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>블로그 미리보기</title>
<style>
:root { --bg: #f3f3f3; --card: #ffffff; --text: #222; --muted: #888; --line: #eee; --accent: #03c75a; }
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) { --bg: #111; --card: #1b1b1b; --text: #e8e8e8; --muted: #999; --line: #2a2a2a; } }
body { margin: 0; background: var(--bg); color: var(--text); font-family: 'Malgun Gothic', 'Apple SD Gothic Neo', sans-serif; }
.post { max-width: 480px; margin: 0 auto; background: var(--card); padding: 20px 16px 40px; text-align: center; }
.note { font-size: 12px; color: var(--muted); margin: 0 0 14px; }
h1 { font-size: 20px; line-height: 1.45; text-align: left; margin: 0 0 18px; padding-bottom: 14px; border-bottom: 1px solid var(--line); }
h3 { font-size: 17px; margin: 22px 0 10px; }
p { margin: 0; font-size: 15px; line-height: 1.8; word-break: keep-all; }
a { color: var(--accent); word-break: break-all; }
.gap { height: 14px; }
figure { margin: 10px 0; }
figure img { width: 100%; height: auto; display: block; border-radius: 4px; }
figcaption { font-size: 11px; color: var(--muted); margin-top: 4px; }
hr { border: 0; border-top: 1px solid var(--line); margin: 20px 0; }
.tags { margin-top: 26px; text-align: left; font-size: 13px; color: var(--accent); line-height: 1.9; }
</style></head><body><article class="post">
<p class="note">네이버 블로그 모바일 화면처럼 본 미리보기예요 (사진 아래 작은 글씨는 파일 이름)</p>
<h1>$(Enc $title)</h1>
$($html.ToString())
<div class="tags">$tagHtml</div>
</article></body></html>
"@
[IO.File]::WriteAllText((Join-Path $Dir 'preview.html'), $page, (New-Object System.Text.UTF8Encoding $false))
Write-Host "Done: $(Join-Path $Dir 'preview.html')"
