# 냥셰프 파비콘 PNG · ICO 만들기
#
# favicon.svg 와 같은 모양을 그려서 아래 파일을 만듭니다.
#   favicon.ico            브라우저 탭용 (16 · 32 · 48px 묶음)
#   apple-touch-icon.png   휴대폰 홈 화면에 추가할 때 쓰는 180px 아이콘 (모서리는 폰이 둥글게 깎음)
#   og-image.png           카카오톡·SNS에 링크를 붙였을 때 뜨는 1200x630 미리보기 그림
#
# 실행 (프로젝트 폴더에서):
#   powershell -ExecutionPolicy Bypass -File tools\make-favicon.ps1
#
# 모양을 바꿀 때는 favicon.svg 와 이 파일의 좌표를 같이 고치세요. (64 x 64 칸 기준)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$Root = Split-Path -Parent $PSScriptRoot

function Color([string]$hex) { [System.Drawing.ColorTranslator]::FromHtml($hex) }
function Brush([string]$hex) { New-Object System.Drawing.SolidBrush (Color $hex) }
function Pen([string]$hex, [single]$width) {
  $p = New-Object System.Drawing.Pen ((Color $hex), $width)
  $p.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
  $p.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $p.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $p
}

function Polygon([single[]]$xy) {
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $points = for ($i = 0; $i -lt $xy.Length; $i += 2) { New-Object System.Drawing.PointF ($xy[$i], $xy[$i + 1]) }
  $path.AddPolygon([System.Drawing.PointF[]]$points)
  $path
}

function Ellipse([single]$cx, [single]$cy, [single]$rx, [single]$ry) {
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddEllipse($cx - $rx, $cy - $ry, 2 * $rx, 2 * $ry)
  $path
}

function RoundRect([single]$x, [single]$y, [single]$w, [single]$h, [single]$r) {
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  if ($r -le 0) { $path.AddRectangle((New-Object System.Drawing.RectangleF ($x, $y, $w, $h))); return $path }
  $d = 2 * $r
  $path.AddArc($x, $y, $d, $d, 180, 90)
  $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
  $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
  $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
  $path.CloseFigure()
  $path
}

# SVG의 "굵은 테두리를 먼저 칠하고 그 위에 색을 덮는" 방식: 겹친 도형이 하나로 이어져 보임
function OutlinedShapes($g, $shapes, [string]$fill) {
  $ink = Brush '#4A3426'
  $pen = Pen '#4A3426' 6
  foreach ($s in $shapes) { $g.FillPath($ink, $s); $g.DrawPath($pen, $s) }
  $brush = Brush $fill
  foreach ($s in $shapes) { $g.FillPath($brush, $s) }
}

# size px 짜리 아이콘 한 장. $square 면 바탕을 둥글리지 않음 (홈 화면 아이콘용)
function DrawIcon([int]$size, [bool]$square) {
  $scale = 8   # 크게 그린 뒤 줄여야 작은 크기에서도 선이 깔끔함
  $big = New-Object System.Drawing.Bitmap ($size * $scale), ($size * $scale), ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($big)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.Clear([System.Drawing.Color]::Transparent)
  $g.ScaleTransform($size * $scale / 64, $size * $scale / 64)

  $radius = if ($square) { 0 } else { 14 }
  $g.FillPath((Brush '#B8552F'), (RoundRect 0 0 64 64 $radius))

  # translate(32 33) scale(0.88) translate(-32 -32)
  $g.TranslateTransform(32, 33)
  $g.ScaleTransform(0.88, 0.88)
  $g.TranslateTransform(-32, -32)

  # 귀와 얼굴
  OutlinedShapes $g @((Polygon 12,42,9,17,27,30), (Polygon 52,42,55,17,37,30), (Ellipse 32 44 21 14)) '#F2B872'

  # 볼, 웃는 눈, 코
  $blush = Brush '#F4A28C'
  $g.FillPath($blush, (Ellipse 18 50 3.5 2.2))
  $g.FillPath($blush, (Ellipse 46 50 3.5 2.2))
  $eye = Pen '#4A3426' 4
  # SVG의 Q(2차 곡선)를 같은 모양의 3차 곡선으로 바꿔 그림
  $g.DrawBezier($eye, 21, 44, 23.667, 41, 26.333, 41, 29, 44)
  $g.DrawBezier($eye, 35, 44, 37.667, 41, 40.333, 41, 43, 44)
  $g.FillPath((Brush '#E7837A'), (Polygon 29.5,49,34.5,49,32,52))

  # 셰프 모자
  OutlinedShapes $g @((Ellipse 25 17 7.5 7.5), (Ellipse 39 17 7.5 7.5), (Ellipse 32 12 9 9), (RoundRect 22 17 20 10 2)) '#FFFFFF'
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

# og-image.png: 크림색 바탕 + 왼쪽 냥셰프 아이콘 + 오른쪽 사이트 이름 (글꼴: 윈도우 기본 맑은 고딕)
$og = New-Object System.Drawing.Bitmap 1200, 630, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($og)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
$g.Clear((Color '#FBF3E4'))

$g.FillEllipse((Brush '#F3E6CF'), 90, 95, 440, 440)
$icon = DrawIcon 330 $false
$g.DrawImage($icon, 145, 150, 330, 330)
$icon.Dispose()

$px = [System.Drawing.GraphicsUnit]::Pixel
$bold = [System.Drawing.FontStyle]::Bold
$ink = Brush '#4A3426'
$muted = Brush '#7A6352'
$g.DrawString('냥셰프의', (New-Object System.Drawing.Font 'Malgun Gothic', 58, $bold, $px), $ink, 575, 118)
$g.DrawString('오늘 뭐 먹지', (New-Object System.Drawing.Font 'Malgun Gothic', 90, $bold, $px), $ink, 568, 190)
$sub = New-Object System.Drawing.Font 'Malgun Gothic', 34, ([System.Drawing.FontStyle]::Regular), $px
$g.DrawString('고양이 요리사가 골라 주는', $sub, $muted, 580, 345)
$g.DrawString('아침·점심·저녁 메뉴와 집밥 레시피', $sub, $muted, 580, 395)

$urlFont = New-Object System.Drawing.Font 'Malgun Gothic', 28, $bold, $px
$urlText = 'meal-project.pages.dev'
$size = $g.MeasureString($urlText, $urlFont)
$g.FillPath((Brush '#B8552F'), (RoundRect 580 478 ($size.Width + 44) 58 29))
$g.DrawString($urlText, $urlFont, (Brush '#FFFFFF'), 602, (478 + (58 - $size.Height) / 2))
$g.Dispose()
$og.Save((Join-Path $Root 'og-image.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$og.Dispose()

Write-Host 'Done: favicon.ico (16, 32, 48px), apple-touch-icon.png (180px), og-image.png (1200x630)'
