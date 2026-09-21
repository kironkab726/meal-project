# 냥빵이 그리기 도구 (GDI+). make-favicon.ps1 과 make-blog-images.ps1 이 불러서 씀
#   . (Join-Path $PSScriptRoot 'nyangbbang-draw.ps1')
# 좌표는 index.html 의 냥빵이 그림(400 칸)과 같음. 모양을 바꾸면 index.html(.chef-cat), favicon.svg 도 같이 고치세요.

Add-Type -AssemblyName System.Drawing

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

