# 네이버 블로그 요리일기 표지 (1080x1080, 목록 썸네일로 쓰기 좋은 정사각형)
#
#   위쪽: "냥빵이 요리일기 #번호" 딱지, 메뉴 이름, 한 줄 소개
#   -Layout photo (기본): 아래쪽을 음식 그림으로 꽉 채우고, 냥빵이가 오른쪽 위에서 음식을 내려다봄
#                         (요리 블로그들처럼 음식이 크게 보이는 썸네일)
#   -Layout card        : 사이트의 냥빵이 그림 + 완성 요리 그림을 동그랗게 잘라 넣음
#
# 실행 예 (프로젝트 폴더에서). -Photo, -Out 은 "뭐 먹지 프로젝트 마케팅" 폴더 기준 경로:
#   powershell -ExecutionPolicy Bypass -File tools\make-blog-cover.ps1 -Number 1 -Title 도토리묵무침 `
#     -Sub "양념장 황금비율 초간단 레시피" -Photo naver-blog\posts\01-dotorimuk\01-hero.jpg `
#     -CropX 0 -CropY 380 -CropSize 1280 -Out naver-blog\posts\01-dotorimuk\00-cover.png
#   -CropX/-CropY/-CropSize: 원본 그림에서 가져올 칸 (픽셀, 원본 크기 기준). CropSize 는 칸의 가로 길이.
#     photo 는 가로:세로 = 1080:700 인 칸, card 는 정사각형 칸 (동그라미로 잘림)

param([int]$Number, [string]$Title, [string]$Sub, [string]$Photo, [int]$CropX, [int]$CropY, [int]$CropSize, [string]$Out,
  [ValidateSet('photo', 'card')][string]$Layout = 'photo')
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'nyangbbang-draw.ps1')
. (Join-Path $PSScriptRoot 'marketing-path.ps1')
if (-not [IO.Path]::IsPathRooted($Photo)) { $Photo = Join-Path $MarketingDir $Photo }
if (-not [IO.Path]::IsPathRooted($Out)) { $Out = Join-Path $MarketingDir $Out }

$px = [System.Drawing.GraphicsUnit]::Pixel
function Font([single]$size, [bool]$isBold) {
  $style = if ($isBold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
  New-Object System.Drawing.Font 'Malgun Gothic', $size, $style, $px
}

$S = 1080
$bmp = New-Object System.Drawing.Bitmap $S, $S, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
$g.Clear((Color '#FBF3E4'))

# 체크무늬 띠 (사이트 맨 위와 같은 무늬)
$soft = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(71, 184, 85, 47))
for ($x = 0; $x -lt $S; $x += 36) { $g.FillRectangle($soft, $x, 0, 18, 36) }
$g.FillRectangle($soft, 0, 0, $S, 18)

# 발바닥 낙서
function Paw([single]$cx, [single]$cy, [single]$size, [single]$angle) {
  $state = $g.Save()
  $g.TranslateTransform($cx, $cy); $g.RotateTransform($angle)
  $g.ScaleTransform($size / 48, $size / 48); $g.TranslateTransform(-24, -24)
  $b = Brush '#E4CFAD'
  $g.FillPath($b, (Ellipse 24 32 10 8))
  foreach ($toe in @(@(11, 19), @(19, 11), @(29, 11), @(37, 19))) { $g.FillPath($b, (Ellipse $toe[0] $toe[1] 4 4)) }
  $g.Restore($state)
}
if ($Layout -eq 'card') {
  Paw 960 110 64 14
  Paw 1010 230 44 -12
  Paw 70 560 46 -16
}

# 딱지: 냥빵이 요리일기 #번호
$tagFont = Font 34 $true
$tag = "냥빵이 요리일기 #$Number"
$ts = $g.MeasureString($tag, $tagFont)
$g.FillPath((Brush '#B8552F'), (RoundRect 70 84 ($ts.Width + 48) 60 30))
$g.DrawString($tag, $tagFont, (Brush '#FFFFFF'), 94, (84 + (60 - $ts.Height) / 2))

# 제목 (길면 글씨를 줄여서 한 줄에 맞춤). photo 는 오른쪽에 냥빵이 자리를 비움
$maxW = if ($Layout -eq 'photo') { $S - 360 } else { $S - 130 }
$size = 132
do { $tf = Font $size $true; $w = $g.MeasureString($Title, $tf).Width; $size -= 4 } while ($w -gt $maxW -and $size -gt 60)
$titleY = if ($Layout -eq 'photo') { 146 } else { 160 }
$g.DrawString($Title, $tf, (Brush '#4A3426'), 58, $titleY)
$subSize = 42
do { $sf = Font $subSize $false; $w = $g.MeasureString($Sub, $sf).Width; $subSize -= 2 } while ($w -gt ($maxW + 20) -and $subSize -gt 26)
$subY = if ($Layout -eq 'photo') { 294 } else { 330 }
$g.DrawString($Sub, $sf, (Brush '#7A6352'), 70, $subY)

if ($Layout -eq 'photo') {
  # 아래쪽을 음식 그림으로 꽉 채움 (원본에서 가로:세로 = 1080:$ph 칸을 가져옴)
  $top = 380; $ph = $S - $top
  $src = [System.Drawing.Image]::FromFile($Photo)
  $g.DrawImage($src, (New-Object System.Drawing.RectangleF (0, $top, $S, $ph)), (New-Object System.Drawing.RectangleF ($CropX, $CropY, $CropSize, ($CropSize * $ph / $S))), $px)
  $src.Dispose()
  $g.FillRectangle((Brush '#B8552F'), 0, $top - 6, $S, 6)

  # 냥빵이: 오른쪽 위, 앞발이 그림 윗선에 걸치게
  $sc = 0.64
  $state = $g.Save()
  $g.TranslateTransform(812, ($top + 14 - 404 * $sc)); $g.ScaleTransform($sc, $sc)
  DrawNyangbbang $g $true $true
  $g.Restore($state)

  $g.Dispose()
  $bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  Write-Host "Done: $Out"
  return
}

# 완성 요리 동그라미
$cx = 712; $cy = 748; $r = 280
$g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(40, 74, 52, 38))), $cx - $r + 6, $cy - $r + 14, 2 * $r, 2 * $r)
$g.FillEllipse((Brush '#FFFFFF'), $cx - $r - 14, $cy - $r - 14, 2 * $r + 28, 2 * $r + 28)
$src = [System.Drawing.Image]::FromFile($Photo)
$clip = New-Object System.Drawing.Drawing2D.GraphicsPath
$clip.AddEllipse($cx - $r, $cy - $r, 2 * $r, 2 * $r)
$state = $g.Save()
$g.SetClip($clip)
$g.DrawImage($src, (New-Object System.Drawing.RectangleF (($cx - $r), ($cy - $r), (2 * $r), (2 * $r))), (New-Object System.Drawing.RectangleF ($CropX, $CropY, $CropSize, $CropSize)), $px)
$g.Restore($state)
$src.Dispose()
$ring = Pen '#E6D0AC' 5
$ring.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
$g.DrawEllipse($ring, $cx - $r - 30, $cy - $r - 30, 2 * $r + 60, 2 * $r + 60)

# 사이트의 냥빵이 (전신): 그림 칸 400 단위를 0.92 배로, 왼쪽 아래
$state = $g.Save()
$g.TranslateTransform(40, 676); $g.ScaleTransform(0.92, 0.92); $g.TranslateTransform(-10, -10)
DrawNyangbbang $g $true $true
$g.Restore($state)

$g.Dispose()
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host "Done: $Out"
