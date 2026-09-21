# 냥빵이 파비콘 PNG · ICO · 공유 미리보기 그림 만들기
#
# index.html 의 냥빵이 그림과 같은 좌표(400 칸)로 그려서 아래 파일을 만듭니다.
#   favicon.ico            브라우저 탭용 (16 · 32 · 48px 묶음)
#   favicon-192.png        구글 검색 결과용 큰 파비콘 (구글은 48px보다 큰 것을 권장)
#   apple-touch-icon.png   휴대폰 홈 화면에 추가할 때 쓰는 180px 아이콘 (모서리는 폰이 둥글게 깎음)
#   og-image.png           카카오톡·SNS에 링크를 붙였을 때 뜨는 1200x630 미리보기 그림
#
# 실행 (프로젝트 폴더에서):
#   powershell -ExecutionPolicy Bypass -File tools\make-favicon.ps1
#
# 모양을 바꿀 때는 index.html(.chef-cat), favicon.svg 와 이 파일의 좌표를 같이 고치세요.

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot

# 냥빵이 그리는 함수들 (Color, Brush, Pen, Ellipse, RoundRect, SvgPath, DrawNyangbbang)
. (Join-Path $PSScriptRoot 'nyangbbang-draw.ps1')

# size px 짜리 아이콘 한 장 (favicon.svg 와 같은 모양). $square 면 바탕을 둥글리지 않음 (홈 화면 아이콘용)
function DrawIcon([int]$size, [bool]$square) {
  $scale = 8   # 크게 그린 뒤 줄여야 작은 크기에서도 선이 깔끔함
  $big = New-Object System.Drawing.Bitmap ($size * $scale), ($size * $scale), ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($big)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.Clear([System.Drawing.Color]::Transparent)
  $g.ScaleTransform($size * $scale / 64, $size * $scale / 64)

  $radius = if ($square) { 0 } else { 14 }
  $g.FillPath((Brush '#4A3426'), (RoundRect 0 0 64 64 $radius))

  # translate(2 2) scale(0.2) translate(-50 -12): 400 칸 그림의 머리 쪽(50,12 ~ 350,312)을 64 칸 안에
  $g.TranslateTransform(2, 2)
  $g.ScaleTransform(0.2, 0.2)
  $g.TranslateTransform(-50, -12)
  DrawNyangbbang $g $false $false
  $g.Dispose()

  $out = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g2 = [System.Drawing.Graphics]::FromImage($out)
  $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g2.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g2.Clear([System.Drawing.Color]::Transparent)
  $g2.DrawImage($big, 0, 0, $size, $size)
  $g2.Dispose()
  $big.Dispose()
  $out
}

function PngBytes($bitmap) {
  $ms = New-Object System.IO.MemoryStream
  $bitmap.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
  $bytes = $ms.ToArray()
  $ms.Dispose()
  , $bytes   # 바이트 배열을 한 덩어리로 돌려줌
}

# favicon-192.png
$big192 = DrawIcon 192 $false
$big192.Save((Join-Path $Root 'favicon-192.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$big192.Dispose()

# apple-touch-icon.png
$touch = DrawIcon 180 $true
$touch.Save((Join-Path $Root 'apple-touch-icon.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$touch.Dispose()

# favicon.ico: PNG 여러 장을 ICO 한 파일에 담음
$sizes = @(16, 32, 48)
$images = foreach ($s in $sizes) { $b = DrawIcon $s $false; , (PngBytes $b); $b.Dispose() }
$ms = New-Object System.IO.MemoryStream
$w = New-Object System.IO.BinaryWriter $ms
$w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
  $w.Write([byte]$sizes[$i]); $w.Write([byte]$sizes[$i]); $w.Write([byte]0); $w.Write([byte]0)
  $w.Write([uint16]1); $w.Write([uint16]32)
  $w.Write([uint32]$images[$i].Length); $w.Write([uint32]$offset)
  $offset += $images[$i].Length
}
foreach ($img in $images) { $w.Write([byte[]]$img) }
$w.Flush()
[IO.File]::WriteAllBytes((Join-Path $Root 'favicon.ico'), $ms.ToArray())
$w.Dispose()

# og-image.png: 크림색 바탕 + 왼쪽 접시 위 냥빵이 + 오른쪽 사이트 이름 (글꼴: 윈도우 기본 맑은 고딕)
$og = New-Object System.Drawing.Bitmap 1200, 630, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($og)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
$g.Clear((Color '#FBF3E4'))

$g.FillEllipse((Brush '#F3E6CF'), 90, 95, 440, 440)
$state = $g.Save()
$g.TranslateTransform(120, 100)
$g.TranslateTransform(-10, -10)   # 그림의 (10, 10)을 (120, 100)에
DrawNyangbbang $g $true $true
$g.Restore($state)

$px = [System.Drawing.GraphicsUnit]::Pixel
$bold = [System.Drawing.FontStyle]::Bold
$ink = Brush '#4A3426'
$muted = Brush '#7A6352'
$g.DrawString('냥빵이의', (New-Object System.Drawing.Font 'Malgun Gothic', 58, $bold, $px), $ink, 575, 112)
$g.DrawString('오늘은 뭐 먹지', (New-Object System.Drawing.Font 'Malgun Gothic', 84, $bold, $px), $ink, 568, 186)
$sub = New-Object System.Drawing.Font 'Malgun Gothic', 34, ([System.Drawing.FontStyle]::Regular), $px
$g.DrawString('식빵 고양이 요리사가 골라 주는', $sub, $muted, 580, 352)
$g.DrawString('아침·점심·저녁 메뉴와 집밥 레시피', $sub, $muted, 580, 402)

$urlFont = New-Object System.Drawing.Font 'Malgun Gothic', 28, $bold, $px
$urlText = 'meal-project.pages.dev'
$size = $g.MeasureString($urlText, $urlFont)
$g.FillPath((Brush '#B8552F'), (RoundRect 580 482 ($size.Width + 44) 58 29))
$g.DrawString($urlText, $urlFont, (Brush '#FFFFFF'), 602, (482 + (58 - $size.Height) / 2))
$g.Dispose()
$og.Save((Join-Path $Root 'og-image.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$og.Dispose()

Write-Host 'Done: favicon.ico (16, 32, 48px), favicon-192.png, apple-touch-icon.png (180px), og-image.png (1200x630)'
