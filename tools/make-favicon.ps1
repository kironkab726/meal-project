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

# SVG 경로 글자(d)를 GDI+ 경로로 바꿈. 절대 좌표 M L C Q Z 만 씀 (index.html 그림과 같은 글자를 그대로 붙여 넣을 수 있음)
function SvgPath([string]$d) {
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $t = ($d -creplace '([MLCQZ])', ' $1 ').Trim() -split '[\s,]+'
  $i = 0
  [single]$x = 0; [single]$y = 0; [single]$sx = 0; [single]$sy = 0
  $cmd = ''
  while ($i -lt $t.Length) {
    if ($t[$i] -cmatch '^[MLCQZ]$') { $cmd = $t[$i]; $i++ }
    if ($cmd -ceq 'Z') { $path.CloseFigure(); $x = $sx; $y = $sy; continue }
    $count = @{ M = 2; L = 2; Q = 4; C = 6 }[$cmd]
    $a = [single[]]$t[$i..($i + $count - 1)]
    switch -CaseSensitive ($cmd) {
      'M' { $x = $a[0]; $y = $a[1]; $sx = $x; $sy = $y; $path.StartFigure(); $i += 2; $cmd = 'L' }
      'L' { $path.AddLine($x, $y, $a[0], $a[1]); $x = $a[0]; $y = $a[1]; $i += 2 }
      'C' { $path.AddBezier($x, $y, $a[0], $a[1], $a[2], $a[3], $a[4], $a[5]); $x = $a[4]; $y = $a[5]; $i += 6 }
      'Q' {
        # 2차 곡선을 같은 모양의 3차 곡선으로
        [single]$c1x = $x + 2 / 3 * ($a[0] - $x); [single]$c1y = $y + 2 / 3 * ($a[1] - $y)
        [single]$c2x = $a[2] + 2 / 3 * ($a[0] - $a[2]); [single]$c2y = $a[3] + 2 / 3 * ($a[1] - $a[3])
        $path.AddBezier($x, $y, $c1x, $c1y, $c2x, $c2y, $a[2], $a[3]); $x = $a[2]; $y = $a[3]; $i += 4
      }
    }
  }
  $path
}

# 냥빵이 한 마리 (400 칸 좌표)
#   $full   : 꼬리와 앞발까지 (공유 그림용). 아니면 머리 쪽만 (아이콘용)
#   $detail : 눈 반짝이와 수염까지. 아이콘은 작아서 빼고 눈을 조금 키움
function DrawNyangbbang($g, [bool]$full, [bool]$detail) {
  $crust = '#C8733A'
  $ink = '#4A3426'
  if ($full) { $g.DrawPath((Pen $crust 24), (SvgPath 'M282 386 C340 394 372 362 362 322 C356 300 340 294 332 306')) }
  foreach ($ear in @('M104 128 L112 44 L178 92 Z', 'M296 128 L288 44 L222 92 Z')) {
    $p = SvgPath $ear
    $g.FillPath((Brush $crust), $p)
    $g.DrawPath((Pen $crust 10), $p)
  }
  $g.FillPath((Brush '#F4A28C'), (SvgPath 'M120 114 L124 66 L160 94 Z'))
  $g.FillPath((Brush '#F4A28C'), (SvgPath 'M280 114 L276 66 L240 94 Z'))
  $g.FillPath((Brush $crust), (SvgPath 'M90 392 L90 214 C52 206 44 130 100 112 C140 70 260 70 300 112 C356 130 348 206 310 214 L310 392 Q310 404 298 404 L102 404 Q90 404 90 392 Z'))
  $g.DrawPath((Pen '#A85A28' 7), (SvgPath 'M68 156 L86 162 M68 178 L88 180 M332 156 L314 162 M332 178 L312 180'))
  $g.FillPath((Brush '#FFE9C2'), (SvgPath 'M108 384 L108 204 C74 196 66 142 114 128 C150 94 250 94 286 128 C334 142 326 196 292 204 L292 384 Q292 390 286 390 L114 390 Q108 390 108 384 Z'))
  if ($full) {
    $g.FillPath((Brush '#E49A5A'), (Ellipse 160 392 30 17))
    $g.FillPath((Brush '#E49A5A'), (Ellipse 240 392 30 17))
    $g.DrawPath((Pen '#B8672F' 4), (SvgPath 'M152 384 L152 395 M168 384 L168 395 M232 384 L232 395 M248 384 L248 395'))
  }

  # 셰프 모자: SVG의 rotate(-8 200 84)
  $state = $g.Save()
  $g.TranslateTransform(200, 84); $g.RotateTransform(-8); $g.TranslateTransform(-200, -84)
  $white = Brush '#FFFFFF'
  $g.FillPath($white, (Ellipse 176 52 20 20))
  $g.FillPath($white, (Ellipse 224 52 20 20))
  $g.FillPath($white, (Ellipse 200 40 24 24))
  $g.FillPath($white, (RoundRect 170 54 60 36 8))
  if ($detail) { $g.DrawPath((Pen '#E6DCCD' 4), (SvgPath 'M186 64 L186 82 M200 62 L200 82 M214 64 L214 82')) }
  $g.Restore($state)

  # 얼굴 (기본 표정)
  $g.FillPath((Brush '#F4A28C'), (Ellipse 136 262 17 10))
  $g.FillPath((Brush '#F4A28C'), (Ellipse 264 262 17 10))
  if ($detail) {
    $g.FillPath((Brush $ink), (Ellipse 152 232 9 11))
    $g.FillPath((Brush $ink), (Ellipse 248 232 9 11))
    $g.FillPath($white, (Ellipse 155 228 3 3))
    $g.FillPath($white, (Ellipse 251 228 3 3))
  } else {
    $g.FillPath((Brush $ink), (Ellipse 152 232 10 12))
    $g.FillPath((Brush $ink), (Ellipse 248 232 10 12))
  }
  $g.FillPath((Brush '#E7837A'), (SvgPath 'M191 250 Q200 246 209 250 L200 259 Z'))
  $g.DrawPath((Pen $ink ($(if ($detail) { 5 } else { 6 }))), (SvgPath 'M200 259 Q196 270 186 268 M200 259 Q204 270 214 268'))
  if ($detail) { $g.DrawPath((Pen $ink 3.5), (SvgPath 'M122 248 L82 242 M122 260 L84 264 M278 248 L318 242 M278 260 L316 264')) }
}

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
