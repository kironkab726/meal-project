# 냥빵이 네이버 블로그 그림 만들기 (저장: 바탕 화면 "뭐 먹지 프로젝트 마케팅" 폴더, tools\marketing-path.ps1)
#
#   naver-blog\profile.png        프로필 사진 (600x600 정사각형, 동그랗게 잘려도 얼굴이 가운데 오게)
#   naver-blog\title-pc.png       PC 블로그 맨 위 타이틀 (966x300)
#   naver-blog\cover-mobile.png   모바일 앱 커버 (1080x1300, 아래쪽은 네이버가 블로그 이름을 얹으니 비워 둠)
#
# 실행 (프로젝트 폴더에서):
#   powershell -ExecutionPolicy Bypass -File tools\make-blog-images.ps1

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'nyangbbang-draw.ps1')
. (Join-Path $PSScriptRoot 'marketing-path.ps1')

$Out = Join-Path $MarketingDir 'naver-blog'
New-Item -ItemType Directory -Force $Out | Out-Null

$px = [System.Drawing.GraphicsUnit]::Pixel
function Font([single]$size, [bool]$isBold) {
  $style = if ($isBold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
  New-Object System.Drawing.Font 'Malgun Gothic', $size, $style, $px
}

function NewCanvas([int]$w, [int]$h) {
  $bmp = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
  $g.Clear((Color '#FBF3E4'))
  $bmp, $g
}

# 사이트 맨 위의 체크무늬 띠: 크림 바탕에 토마토색 반투명 줄을 세로·가로로 겹침 (style.css 의 .gingham)
function Gingham($g, [single]$x, [single]$y, [single]$w, [single]$h, [single]$cell) {
  $g.FillRectangle((Brush '#FBF3E4'), $x, $y, $w, $h)
  $soft = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(71, 184, 85, 47))
  $state = $g.Save()
  $g.SetClip((New-Object System.Drawing.RectangleF ($x, $y, $w, $h)))
  for ($cx = $x; $cx -lt $x + $w; $cx += $cell) { $g.FillRectangle($soft, $cx, $y, $cell / 2, $h) }
  for ($cy = $y; $cy -lt $y + $h; $cy += $cell) { $g.FillRectangle($soft, $x, $cy, $w, $cell / 2) }
  $g.Restore($state)
}

# 사이트 배경의 발바닥 낙서 (48 칸 그림을 size px 로, angle 도 기울여서)
function Paw($g, [single]$cx, [single]$cy, [single]$size, [single]$angle) {
  $state = $g.Save()
  $g.TranslateTransform($cx, $cy); $g.RotateTransform($angle)
  $g.ScaleTransform($size / 48, $size / 48); $g.TranslateTransform(-24, -24)
  $b = Brush '#E4CFAD'
  $g.FillPath($b, (Ellipse 24 32 10 8))
  foreach ($toe in @(@(11, 19), @(19, 11), @(29, 11), @(37, 19))) { $g.FillPath($b, (Ellipse $toe[0] $toe[1] 4 4)) }
  $g.Restore($state)
}

# 냥빵이 뒤의 접시: 크림 원 + 점선 테두리 (index.html 의 .plate, .plate-ring)
function Plate($g, [single]$cx, [single]$cy, [single]$r) {
  $g.FillEllipse((Brush '#F6E6CB'), $cx - $r, $cy - $r, 2 * $r, 2 * $r)
  $ring = Pen '#E6D0AC' ([Math]::Max(3, $r / 40))
  $ring.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
  $inner = $r * 0.87
  $g.DrawEllipse($ring, $cx - $inner, $cy - $inner, 2 * $inner, 2 * $inner)
}

# 냥빵이 한 마리: 그림의 (ox, oy)를 (x, y)에 두고 scale 배로
function PlaceNyang($g, [single]$x, [single]$y, [single]$scale, [single]$ox, [single]$oy, [bool]$full) {
  $state = $g.Save()
  $g.TranslateTransform($x, $y); $g.ScaleTransform($scale, $scale); $g.TranslateTransform(-$ox, -$oy)
  DrawNyangbbang $g $full $true
  $g.Restore($state)
}

function Save($bmp, $g, [string]$name) {
  $g.Dispose()
  $bmp.Save((Join-Path $Out $name), [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
}


# 1) 프로필 사진: 얼굴 쪽(그림의 50,12 ~ 350,312)을 크게. 몸은 아래로 이어지다 잘림
$bmp, $g = NewCanvas 600 600
Plate $g 300 330 250
PlaceNyang $g 60 60 1.6 50 12 $false
Save $bmp $g 'profile.png'


# 2) PC 타이틀 (966 x 300): 왼쪽 접시 위 냥빵이, 오른쪽 블로그 이름
$bmp, $g = NewCanvas 966 300
Gingham $g 0 0 966 14 18
Plate $g 185 166 118
PlaceNyang $g 71 42 0.6 10 10 $true
$ink = Brush '#4A3426'
$g.DrawString('냥빵이의', (Font 30 $true), $ink, 345, 56)
$g.DrawString('오늘은 뭐 먹지', (Font 60 $true), $ink, 338, 90)
$g.DrawString('고양이 요리사가 골라 주는 아침·점심·저녁 집밥 레시피', (Font 21 $false), (Brush '#7A6352'), 346, 182)
$urlFont = Font 19 $true
$urlText = 'meal-project.pages.dev'
$size = $g.MeasureString($urlText, $urlFont)
$g.FillPath((Brush '#B8552F'), (RoundRect 346 224 ($size.Width + 36) 40 20))
$g.DrawString($urlText, $urlFont, (Brush '#FFFFFF'), 364, (224 + (40 - $size.Height) / 2))
Paw $g 872 62 40 -18
Paw $g 926 112 30 14
Paw $g 914 250 36 10
Save $bmp $g 'title-pc.png'


# 3) 모바일 커버 (1080 x 1300): 가운데 위쪽에 크게. 아래쪽 3분의 1은 네이버가 이름을 얹으니 비워 둠
$bmp, $g = NewCanvas 1080 1300
Gingham $g 0 0 1080 36 36
Plate $g 540 560 400
PlaceNyang $g 198 190 1.8 10 10 $true
Paw $g 120 300 50 12
Paw $g 960 230 56 -10
Paw $g 140 1080 70 -18
Paw $g 930 1010 60 16
Paw $g 820 1190 54 8
Paw $g 230 1230 50 20
Save $bmp $g 'cover-mobile.png'

Write-Host "Done: $Out (profile.png 600x600, title-pc.png 966x300, cover-mobile.png 1080x1300)"
