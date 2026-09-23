# 냥빵이 유튜브 채널 그림 만들기
#
#   marketing\youtube\banner.png            채널 배너 (2048x1152, 유튜브가 요구하는 크기)
#   marketing\youtube\banner-safe-guide.png 확인용. 휴대폰에서 보이는 칸(1235x338)을 점선으로 표시 — 올리지 마세요
#   marketing\youtube\profile.png           채널 프로필 사진 (800x800, 동그랗게 잘려도 얼굴이 가운데)
#
# 유튜브는 한 장으로 TV / PC / 휴대폰에 다르게 잘라 씁니다.
#   - 휴대폰: 가운데 1235x338 만 보임  → 글씨와 냥빵이는 모두 이 칸 안에
#   - PC: 가운데 2048x423, TV: 2048x1152 전체 → 바깥쪽은 배경과 발바닥만
#
# 실행 (프로젝트 폴더에서):
#   powershell -ExecutionPolicy Bypass -File tools\make-youtube-banner.ps1

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'nyangbbang-draw.ps1')

$Out = Join-Path $Root 'marketing\youtube'
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

# 사이트 맨 위의 체크무늬 띠 (style.css 의 .gingham)
function Gingham($g, [single]$x, [single]$y, [single]$w, [single]$h, [single]$cell) {
  $g.FillRectangle((Brush '#FBF3E4'), $x, $y, $w, $h)
  $soft = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(71, 184, 85, 47))
  $state = $g.Save()
  $g.SetClip((New-Object System.Drawing.RectangleF ($x, $y, $w, $h)))
  for ($cx = $x; $cx -lt $x + $w; $cx += $cell) { $g.FillRectangle($soft, $cx, $y, $cell / 2, $h) }
  for ($cy = $y; $cy -lt $y + $h; $cy += $cell) { $g.FillRectangle($soft, $x, $cy, $w, $cell / 2) }
  $g.Restore($state)
}

# 사이트 배경의 발바닥 낙서
function Paw($g, [single]$cx, [single]$cy, [single]$size, [single]$angle) {
  $state = $g.Save()
  $g.TranslateTransform($cx, $cy); $g.RotateTransform($angle)
  $g.ScaleTransform($size / 48, $size / 48); $g.TranslateTransform(-24, -24)
  $b = Brush '#E4CFAD'
  $g.FillPath($b, (Ellipse 24 32 10 8))
  foreach ($toe in @(@(11, 19), @(19, 11), @(29, 11), @(37, 19))) { $g.FillPath($b, (Ellipse $toe[0] $toe[1] 4 4)) }
  $g.Restore($state)
}

# 냥빵이 뒤의 접시
function Plate($g, [single]$cx, [single]$cy, [single]$r) {
  $g.FillEllipse((Brush '#F6E6CB'), $cx - $r, $cy - $r, 2 * $r, 2 * $r)
  $ring = Pen '#E6D0AC' ([Math]::Max(3, $r / 40))
  $ring.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
  $inner = $r * 0.87
  $g.DrawEllipse($ring, $cx - $inner, $cy - $inner, 2 * $inner, 2 * $inner)
}

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


# ── 채널 배너 ────────────────────────────────────────────
# 휴대폰에서 보이는 칸: 가로 406.5~1641.5, 세로 407~745
$W = 2048; $H = 1152
$SafeX = 406.5; $SafeY = 407.0; $SafeW = 1235.0; $SafeH = 338.0

function DrawBanner($g) {
  Gingham $g 0 0 $W 30 34
  Gingham $g 0 ($H - 30) $W 30 34

  # 바깥쪽(TV·PC에서만 보이는 자리)은 발바닥 낙서만
  Paw $g 150 210 78 -16
  Paw $g 330 120 56 12
  Paw $g 232 330 60 22
  Paw $g 1820 190 80 14
  Paw $g 1680 110 54 -12
  Paw $g 1900 350 58 -20
  Paw $g 190 900 74 18
  Paw $g 360 1020 56 -14
  Paw $g 1840 940 76 -10
  Paw $g 1660 1040 58 16
  Paw $g 980 130 52 -8
  Paw $g 1120 1030 56 10

  # 안전 칸 왼쪽: 접시 위 냥빵이 (꼬리·발까지 안전 칸 안에 들어오는 크기)
  Plate $g 610 572 142
  PlaceNyang $g 470 422 0.75 10 10 $true

  # 안전 칸 오른쪽: 이름 + 한 줄 소개 + 주소
  $ink = Brush '#4A3426'
  $g.DrawString('냥빵이의', (Font 46 $true), $ink, 806, 430)
  $g.DrawString('오늘은 뭐 먹지', (Font 84 $true), $ink, 798, 482)
  $g.DrawString('고양이 요리사가 골라 주는 아침·점심·저녁 집밥 레시피', (Font 28 $false), (Brush '#7A6352'), 808, 602)

  $urlFont = Font 27 $true
  $urlText = 'meal-project.pages.dev'
  $size = $g.MeasureString($urlText, $urlFont)
  $g.FillPath((Brush '#B8552F'), (RoundRect 806 652 ($size.Width + 52) 56 28))
  $g.DrawString($urlText, $urlFont, (Brush '#FFFFFF'), 832, (652 + (56 - $size.Height) / 2))
}

$bmp, $g = NewCanvas $W $H
DrawBanner $g
Save $bmp $g 'banner.png'

# 확인용: 휴대폰에서 보이는 칸을 점선으로 그려 둔 것 (유튜브에 올리지 말 것)
$bmp, $g = NewCanvas $W $H
DrawBanner $g
$guide = Pen '#B8552F' 4
$guide.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
$g.DrawRectangle($guide, $SafeX, $SafeY, $SafeW, $SafeH)
$g.DrawString('휴대폰에서 보이는 칸 (1235x338)', (Font 24 $true), (Brush '#B8552F'), $SafeX, ($SafeY - 36))
Save $bmp $g 'banner-safe-guide.png'


# ── 채널 프로필 사진 (800x800, 얼굴 위주) ────────────────
$bmp, $g = NewCanvas 800 800
Plate $g 400 440 334
PlaceNyang $g 80 80 2.13 50 12 $false
Save $bmp $g 'profile.png'

Write-Host "Done: $Out (banner.png 2048x1152, banner-safe-guide.png, profile.png 800x800)"
