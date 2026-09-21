# 냥셰프 글 페이지 생성기
#
# Supabase의 menus + recipes 데이터를 읽어서 아래 파일을 새로 만듭니다.
#   recipes/<메뉴번호>.html   메뉴별 레시피 페이지
#   recipes/index.html        레시피 모음
#   about.html, privacy.html  사이트 소개, 개인정보처리방침 (본문은 tools/pages/ 에 있음)
#   sitemap.xml               검색엔진에 알려 줄 페이지 목록
#   rss.xml                   레시피 새 글 목록 (네이버 서치어드바이저 RSS 제출용)
#   llms.txt                  AI(ChatGPT, Claude 등)가 읽기 좋은 사이트 안내
#   fridge.html               냉장고 털기 (재료표는 tools/fridge.csv)
#   recipes/pages.json        레시피 페이지가 있는 메뉴 번호 (메인 화면 공유하기가 읽음)
#   recipes/photo-credits.json 음식 사진 출처 (작가, 라이선스. 출처표는 tools/photos.csv)
#   recipes/videos.json       메뉴별 요리 영상 (메인 화면 "오늘은 이걸로 할래!" 도마가 읽음, 영상표는 tools/videos.csv)
#   recipes/shop-links.json   쿠팡 파트너스 재료 링크 (메인 화면 레시피 칸이 읽음)
#   tools/coupang-links.csv   쿠팡 파트너스 링크를 적는 표 (새 메뉴가 생기면 줄을 더해 줌)
#
# 실행 (프로젝트 폴더에서):
#   powershell -ExecutionPolicy Bypass -File tools\build-pages.ps1
#
# Supabase에서 메뉴나 레시피를 고친 뒤에는 이걸 다시 실행하고 GitHub에 올리면 됩니다.

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = 'Tls12'

$Root     = Split-Path -Parent $PSScriptRoot
$SiteUrl  = 'https://meal-project.pages.dev'
$SiteName = '냥셰프의 오늘 뭐 먹지'
$Utf8     = New-Object System.Text.UTF8Encoding($false)
$Today    = (Get-Date).ToString('yyyy-MM-dd')

$MealOrder  = @('아침', '점심', '저녁')
$MealAnchor = @{ '아침' = 'breakfast'; '점심' = 'lunch'; '저녁' = 'dinner' }


# ── 작은 도우미 ─────────────────────────────────────────

function Enc([string]$s) { [System.Net.WebUtility]::HtmlEncode($s) }

function Lines([string]$s) {
  if (-not $s) { return @() }
  @($s -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Save([string]$relPath, [string]$text) {
  $path = Join-Path $Root $relPath
  $dir = Split-Path -Parent $path
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  [IO.File]::WriteAllText($path, $text, $Utf8)
}

function Fill([string]$template, [hashtable]$values) {
  foreach ($k in $values.Keys) { $template = $template.Replace('{{' + $k + '}}', [string]$values[$k]) }
  $template
}

function MealRank([string]$meal) {
  $i = [array]::IndexOf($MealOrder, $meal)
  if ($i -lt 0) { 99 } else { $i }
}

# 레시피 모음 페이지에서 끼니별로 바로 가는 #주소
function MealAnchorOf([string]$meal) {
  if ($MealAnchor[$meal]) { $MealAnchor[$meal] } else { 'meal-' + [Math]::Abs($meal.GetHashCode()) }
}


# ── 아이콘 ─────────────────────────────────────────────

$Ico = @{
  sun   = '<svg class="ico" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="4"></circle><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"></path></svg>'
  bowl  = '<svg class="ico" viewBox="0 0 24 24" aria-hidden="true"><path d="M3 12h18a9 7 0 0 1-18 0z"></path><path d="M8 8c0-1.5 1-2 1-3.5M12 8c0-1.5 1-2 1-3.5M16 8c0-1.5 1-2 1-3.5"></path></svg>'
  moon  = '<svg class="ico" viewBox="0 0 24 24" aria-hidden="true"><path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"></path></svg>'
  clock = '<svg class="ico" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="9"></circle><path d="M12 7v5l3 2"></path></svg>'
  flame = '<svg class="ico" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3c1 3 5 5 5 10a5 5 0 0 1-10 0c0-2 1-3.5 2-4.5 0 2 1 3 2 3 0-3-1-5 1-8.5z"></path></svg>'
  user  = '<svg class="ico" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="8" r="4"></circle><path d="M4 21 C4 16 8 14 12 14 C16 14 20 16 20 21"></path></svg>'
  cart  = '<svg class="ico" viewBox="0 0 24 24" aria-hidden="true"><path d="M2 3h3l2.4 11.5h11.2L21 7H6"></path><circle cx="9" cy="19.5" r="1.5"></circle><circle cx="17.5" cy="19.5" r="1.5"></circle></svg>'
  share = '<svg class="ico" viewBox="0 0 24 24" aria-hidden="true"><circle cx="18" cy="5" r="3"></circle><circle cx="6" cy="12" r="3"></circle><circle cx="18" cy="19" r="3"></circle><path d="M8.6 13.5l6.8 4M15.4 6.5l-6.8 4"></path></svg>'
  fridge = '<svg class="ico" viewBox="0 0 24 24" aria-hidden="true"><rect x="5" y="2" width="14" height="20" rx="2"></rect><path d="M5 10h14M9 5v2M9 13v3"></path></svg>'
}
$MealIcon = @{ '아침' = $Ico.sun; '점심' = $Ico.bowl; '저녁' = $Ico.moon }


# ── 모든 글 페이지가 함께 쓰는 틀 ──────────────────────────
# {{PREFIX}}: 사이트 맨 위 폴더까지의 상대 경로 (루트 페이지는 "", recipes/ 안은 "../")

$HeadTemplate = @'
<!DOCTYPE html>
<html lang="ko">
<head>
<!-- Google tag (gtag.js) -->
<script async src="https://www.googletagmanager.com/gtag/js?id=G-S0G51XCDTL"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());

  gtag('config', 'G-S0G51XCDTL');
</script>
<!-- Microsoft Clarity -->
<script type="text/javascript">
    (function(c,l,a,r,i,t,y){
        c[a]=c[a]||function(){(c[a].q=c[a].q||[]).push(arguments)};
        t=l.createElement(r);t.async=1;t.src="https://www.clarity.ms/tag/"+i;
        y=l.getElementsByTagName(r)[0];y.parentNode.insertBefore(t,y);
    })(window, document, "clarity", "script", "yk8aoaocif");
</script>
<script>
  // 대표 주소는 Cloudflare Pages. 예전 주소(깃허브, Vercel)로 들어오면 같은 페이지의 새 주소로 옮겨 줌
  (function () {
    var host = location.hostname;
    var path = location.pathname;
    if (host === 'kironkab726.github.io') path = path.replace(/^\/meal-project/, '');
    else if (!/\.vercel\.app$/.test(host)) return;
    location.replace('https://meal-project.pages.dev' + path + location.search + location.hash);
  })();
</script>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{{TITLE}}</title>
<meta name="description" content="{{DESCRIPTION}}">
{{CANONICAL_TAGS}}
<meta property="og:type" content="{{OG_TYPE}}">
<meta property="og:site_name" content="냥셰프의 오늘 뭐 먹지">
<meta property="og:locale" content="ko_KR">
<meta property="og:title" content="{{TITLE}}">
<meta property="og:description" content="{{DESCRIPTION}}">
{{OG_IMAGE}}
<link rel="icon" href="{{PREFIX}}favicon.ico" sizes="any">
<link rel="icon" href="{{PREFIX}}favicon.svg" type="image/svg+xml">
<link rel="icon" href="{{PREFIX}}favicon-192.png" type="image/png" sizes="192x192">
<link rel="apple-touch-icon" href="{{PREFIX}}apple-touch-icon.png">
<link rel="alternate" type="application/rss+xml" title="냥셰프 레시피" href="{{PREFIX}}rss.xml">
<script>
  // 화면이 그려지기 전에 저장된 테마를 적용해서, 새로고침할 때 깜빡이지 않게 함
  (function () {
    let theme = null;
    try { theme = localStorage.getItem('menu-picker-theme'); } catch (e) {}
    if (theme !== 'dark' && theme !== 'light') {
      theme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    }
    document.documentElement.dataset.theme = theme;
  })();
</script>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Gaegu:wght@400;700&family=Gowun+Dodum&family=Jua&display=swap">
<link rel="stylesheet" href="{{PREFIX}}style.css?v=6">
<link rel="stylesheet" href="{{PREFIX}}pages.css?v=4">
{{EXTRA_HEAD}}
</head>
<body>

  <div class="gingham gingham-top" aria-hidden="true"></div>

  <div class="page">
    <header class="site-header">
      <a class="brand" href="{{HOME}}">
        <svg class="brand-cat" viewBox="0 0 120 120" aria-hidden="true">
          <path class="ink" d="M22 64 L28 22 L54 46 Z" fill="#F2B872"></path>
          <path class="ink" d="M98 64 L92 22 L66 46 Z" fill="#F2B872"></path>
          <ellipse class="ink" cx="60" cy="72" rx="44" ry="36" fill="#F2B872"></ellipse>
          <circle class="ink" cx="43" cy="30" r="15" fill="#FFFFFF"></circle>
          <circle class="ink" cx="60" cy="21" r="18" fill="#FFFFFF"></circle>
          <circle class="ink" cx="77" cy="30" r="15" fill="#FFFFFF"></circle>
          <rect class="ink" x="38" y="32" width="44" height="18" rx="5" fill="#FFFFFF"></rect>
          <path class="ink-line" d="M40 72 Q47 65 54 72"></path>
          <path class="ink-line" d="M66 72 Q73 65 80 72"></path>
          <ellipse cx="36" cy="82" rx="7" ry="4" fill="#F4A28C"></ellipse>
          <ellipse cx="84" cy="82" rx="7" ry="4" fill="#F4A28C"></ellipse>
          <path d="M56 80 L64 80 L60 85 Z" fill="#E7837A"></path>
        </svg>
        <div class="brand-text">
          <span class="brand-name">냥셰프<span class="wide-only">의 오늘 뭐 먹지</span></span>
          <span class="brand-sub"><span class="wide-only">고양이 요리사가 골라주는 오늘의 한 끼</span><span class="narrow-only">오늘 뭐 먹지</span></span>
        </div>
      </a>
      <div class="header-actions">
        <a class="pill-btn" href="{{HOME}}">메뉴 추천받기</a>
        <button class="icon-btn" id="theme-toggle" type="button" aria-label="다크 모드로 전환" title="다크 모드로 전환">
          <svg class="ico icon-moon" viewBox="0 0 24 24" aria-hidden="true"><path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"></path></svg>
          <svg class="ico icon-sun" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="4"></circle><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"></path></svg>
        </button>
      </div>
    </header>

    <main class="content">
{{BODY}}
    </main>

    <footer class="site-footer">
      <nav aria-label="사이트 안내">
        <a href="{{PREFIX}}recipes/">냥셰프 레시피 모음</a>
        <a href="{{PREFIX}}search.html">레시피 검색</a>
        <a href="{{PREFIX}}fridge.html">냉장고 털기</a>
        <a href="{{PREFIX}}about.html">사이트 소개</a>
        <a href="{{PREFIX}}privacy.html">개인정보처리방침</a>
      </nav>
      <p>음식 사진: 위키미디어 공용 · 레시피: 냥셰프</p>
    </footer>
  </div>

  <div class="gingham gingham-bottom" aria-hidden="true"></div>

<script src="{{PREFIX}}theme.js?v=1"></script>
<script src="{{PREFIX}}site.js?v=2"></script>
{{EXTRA_SCRIPTS}}
</body>
</html>
'@

function Page([hashtable]$p) {
  $prefix = [string]$p.Prefix
  $homeLink = if ($prefix) { $prefix } else { './' }
  # 공유 미리보기 사진: 음식 사진이 없으면 사이트 대표 그림 (og-image.png, 1200x630)
  if ($p.Image) {
    $ogImage = '<meta property="og:image" content="' + (Enc $p.Image) + '">'
  } else {
    $ogImage = @(
      '<meta property="og:image" content="' + $SiteUrl + '/og-image.png">'
      '<meta property="og:image:width" content="1200">'
      '<meta property="og:image:height" content="630">'
    ) -join "`n"
  }
  # 대표 주소가 없는 페이지(404)는 검색엔진에 올리지 않음
  if ($p.Canonical) {
    $canonicalTags = @(
      '<link rel="canonical" href="' + (Enc $p.Canonical) + '">'
      '<meta property="og:url" content="' + (Enc $p.Canonical) + '">'
      # 구글 검색·디스커버에서 사진을 크게 보여 줘도 된다는 표시
      '<meta name="robots" content="max-image-preview:large">'
    ) -join "`n"
  } else {
    $canonicalTags = '<meta name="robots" content="noindex">'
  }
  Fill $HeadTemplate @{
    TITLE       = Enc $p.Title
    DESCRIPTION = Enc $p.Description
    CANONICAL_TAGS = $canonicalTags
    OG_TYPE     = $(if ($p.OgType) { $p.OgType } else { 'website' })
    OG_IMAGE    = $ogImage
    EXTRA_HEAD  = [string]$p.ExtraHead
    EXTRA_SCRIPTS = [string]$p.ExtraScripts
    PREFIX      = $prefix
    HOME        = $homeLink
    BODY        = $p.Body
  }
}


# ── Supabase에서 메뉴와 레시피 읽기 (공개 키로 읽기만) ─────

$config = [IO.File]::ReadAllText((Join-Path $Root 'config.js'), $Utf8)
$sbUrl = [regex]::Match($config, "supabaseUrl:\s*'([^']+)'").Groups[1].Value
$sbKey = [regex]::Match($config, "supabaseKey:\s*'([^']+)'").Groups[1].Value
if (-not $sbUrl -or -not $sbKey) { throw 'config.js에서 Supabase 주소와 키를 찾지 못했어요.' }

$query = 'menus?select=id,meal,category,name,photo,created_at,recipes(minutes,difficulty,servings,ingredients,steps,tip,updated_at)&order=id'
$response = Invoke-WebRequest -UseBasicParsing -Uri "$sbUrl/rest/v1/$query" -Headers @{ apikey = $sbKey }
# Windows PowerShell은 JSON 배열을 한 덩어리로 넘겨주므로, 한 번 더 풀어서 메뉴 하나하나로 만듦
$parsed = $Utf8.GetString($response.RawContentStream.ToArray()) | ConvertFrom-Json
$menus = @($parsed | ForEach-Object { $_ })

# 레시피가 있는 메뉴만, 아침 → 점심 → 저녁, 같은 끼니 안에서는 메뉴 번호 순서로
$items = @($menus | Where-Object { $_.recipes } | Sort-Object @{ Expression = { MealRank $_.meal } }, id)
if ($items.Count -eq 0) { throw '레시피가 있는 메뉴를 하나도 찾지 못했어요.' }


# ── 날짜 (검색엔진에 "언제 만들고 언제 고쳤는지" 알려 줄 때 씀) ──

# Supabase 시간 글자("2026-09-17T05:12:33.12+00:00")를 날짜로
function ParseTime($s) {
  if (-not $s) { return $null }
  try { [DateTimeOffset]::Parse([string]$s, [Globalization.CultureInfo]::InvariantCulture) } catch { $null }
}

# 메뉴나 레시피를 마지막으로 고친 때
function Touched($m) {
  $times = @((ParseTime $m.created_at), (ParseTime $m.recipes.updated_at)) | Where-Object { $_ }
  if ($times) { @($times | Sort-Object -Descending)[0] } else { $null }
}

$Latest = @($items | ForEach-Object { Touched $_ } | Where-Object { $_ } | Sort-Object -Descending) | Select-Object -First 1

function JsonLd($obj) {
  '<script type="application/ld+json">' + (ConvertTo-Json -InputObject $obj -Depth 6 -Compress).Replace('</', '<\/') + '</script>'
}

function Crumb([int]$position, [string]$name, [string]$url) {
  [ordered]@{ '@type' = 'ListItem'; position = $position; name = $name; item = $url }
}


# ── 쿠팡 파트너스 재료 링크 (tools/coupang-links.csv) ─────────
# 쿠팡 파트너스의 "간편 링크 만들기"에 표의 쿠팡 주소를 붙여 넣고, 만들어진 링크를
# "파트너스 링크" 칸에 넣으면 그 메뉴의 레시피 페이지와 메인 화면 레시피 칸에
# "쿠팡에서 재료 보기" 버튼이 생김. 칸이 비어 있으면 버튼도 안내 문구도 없음.
# 링크를 처음 켤 때는 tools/pages/privacy.html 의 시행일도 그날로 바꿀 것.

$LinksPath = Join-Path $PSScriptRoot 'coupang-links.csv'
$ColId     = '번호'
$ColName   = '메뉴'
$ColMeal   = '끼니'
$ColSource = '간편 링크에 붙여 넣을 쿠팡 주소'
$ColLink   = '파트너스 링크'
$AdNote    = '이 포스팅은 쿠팡 파트너스 활동의 일환으로, 이에 따른 일정액의 수수료를 제공받습니다.'

# 엑셀에서 "CSV (쉼표로 분리)"로 저장하면 UTF-8이 아니라 한글 윈도우 글자(CP949)로 저장됨
function ReadCsvText([string]$path) {
  $bytes = [IO.File]::ReadAllBytes($path)
  try { (New-Object System.Text.UTF8Encoding($false, $true)).GetString($bytes).TrimStart([char]0xFEFF) }
  catch { [Text.Encoding]::GetEncoding(949).GetString($bytes) }
}

function CsvField([string]$s) { '"' + $s.Replace('"', '""') + '"' }

$typedSource = @{}   # 메뉴 번호 → 표에 적혀 있던 쿠팡 주소 (직접 바꿨으면 그대로 둠)
$typedLink   = @{}   # 메뉴 번호 → 표에 적혀 있던 파트너스 링크
if (Test-Path -LiteralPath $LinksPath) {
  $oldCsv = ReadCsvText $LinksPath
  foreach ($row in @($oldCsv -split "\r?\n" | Where-Object { $_.Trim() } | ConvertFrom-Csv)) {
    $id = ([string]$row.$ColId).Trim()
    if (-not $id) { continue }
    $typedSource[$id] = ([string]$row.$ColSource).Trim()
    $typedLink[$id]   = ([string]$row.$ColLink).Trim()
  }
} else {
  $oldCsv = ''
}

# ── 음식 사진 출처 (tools/photos.csv: 사진 파일, 메뉴, 작가, 라이선스, 라이선스 주소) ──
# 위키미디어 사진 대부분은 "작가 이름 + 라이선스"를 표시해야 상업적으로 쓸 수 있어서 사진 아래에 보여 줌
# 새 사진이 생기면 tools\photo-credits.ps1 을 먼저 실행해 표를 채우세요.
function LicenseLabel([string]$license) {
  switch ($license) {
    'Public domain' { '퍼블릭 도메인' }
    'KOGL Type 1'   { '공공누리 제1유형' }
    default         { $license }
  }
}

$Credits = @{}
$photosPath = Join-Path $PSScriptRoot 'photos.csv'
if (Test-Path -LiteralPath $photosPath) {
  foreach ($row in @((ReadCsvText $photosPath) -split "\r?\n" | Where-Object { $_.Trim() } | ConvertFrom-Csv)) {
    $Credits[([string]$row.'사진 파일').Trim()] = [ordered]@{ a = ([string]$row.'작가').Trim(); l = (LicenseLabel ([string]$row.'라이선스').Trim()); u = ([string]$row.'라이선스 주소').Trim() }
  }
}

# "사진: 작가 · 라이선스 · 위키미디어" (라이선스와 위키미디어는 링크)
function PhotoCreditHtml([string]$photo) {
  $filePage = 'https://commons.wikimedia.org/wiki/File:' + [Uri]::EscapeDataString($photo)
  $c = $Credits[$photo]
  $parts = @()
  if ($c -and $c.a) { $parts += (Enc $c.a) }
  if ($c -and $c.l) {
    if ($c.u) { $parts += ('<a href="' + (Enc $c.u) + '" target="_blank" rel="noopener license">' + (Enc $c.l) + '</a>') }
    else { $parts += (Enc $c.l) }
  }
  $parts += ('<a href="' + $filePage + '" target="_blank" rel="noopener">위키미디어</a>')
  '사진: ' + ($parts -join ' · ')
}

# ── 요리 영상 (tools/videos.csv: 번호, 영상 ID, 채널, 영상 제목) ─────
# 유튜브에서 "퍼가기"가 허용된 영상만 넣음. 영상이 내려가면 이 표에서 ID만 바꾸면 됨
$Videos = @{}
$videosPath = Join-Path $PSScriptRoot 'videos.csv'
if (Test-Path -LiteralPath $videosPath) {
  foreach ($row in @((ReadCsvText $videosPath) -split "\r?\n" | Where-Object { $_.Trim() } | ConvertFrom-Csv)) {
    $vid = ([string]$row.'영상 ID').Trim()
    if ($vid -match '^[\w-]{11}$') {
      $Videos[([string]$row.'번호').Trim()] = [ordered]@{ v = $vid; c = ([string]$row.'채널').Trim(); t = ([string]$row.'영상 제목').Trim() }
    }
  }
}

$shopLinks = [ordered]@{}   # 메뉴 번호 → 쓸 수 있는 파트너스 링크
$badLinks  = @()
$csvLines  = @((@($ColId, $ColName, $ColMeal, $ColSource, $ColLink) | ForEach-Object { CsvField $_ }) -join ',')
foreach ($m in $items) {
  $id = [string]$m.id
  $source = $typedSource[$id]
  if (-not $source) { $source = 'https://www.coupang.com/np/search?q=' + [Uri]::EscapeDataString([string]$m.name + ' 재료') }
  $link = [string]$typedLink[$id]
  # 파트너스 링크만 받음 (그냥 쿠팡 주소는 수수료가 안 생기니 버튼을 달지 않음)
  if ($link -match '^https://(link\.coupang\.com|coupa\.ng)/\S+$') { $shopLinks[$id] = $link }
  elseif ($link) { $badLinks += ('  ' + $id + ' ' + $m.name + ': ' + $link) }
  $csvLines += (@($id, [string]$m.name, [string]$m.meal, $source, $link) | ForEach-Object { CsvField $_ }) -join ','
}
$newCsv = ($csvLines -join "`r`n") + "`r`n"
if ($newCsv -ne $oldCsv) {
  try {
    # BOM을 붙여야 엑셀이 한글을 안 깨뜨리고 엶
    [IO.File]::WriteAllText($LinksPath, $newCsv, (New-Object System.Text.UTF8Encoding($true)))
  } catch {
    Write-Warning 'tools\coupang-links.csv 를 고치지 못했어요. 엑셀에서 열려 있으면 닫고 다시 실행해 주세요.'
  }
}
if ($badLinks.Count) {
  Write-Warning ("파트너스 링크가 아니라서 뺀 링크 (https://link.coupang.com/... 모양이어야 해요):`n" + ($badLinks -join "`n"))
}

Save 'recipes\shop-links.json' ((ConvertTo-Json -InputObject $shopLinks -Compress) + "`n")


# ── 레시피 링크 카드 ────────────────────────────────────

function RecipeLink($x) {
  $meta = @()
  if ($x.recipes.minutes) { $meta += ([string]$x.recipes.minutes + '분') }
  if ($x.recipes.difficulty) { $meta += [string]$x.recipes.difficulty }
  '<li><a href="' + $x.id + '.html"><span class="name">' + (Enc $x.name) + '</span><span class="meta">' + (Enc ($meta -join ' · ')) + '</span></a></li>'
}


# ── 메뉴별 레시피 페이지 ─────────────────────────────────

Get-ChildItem -LiteralPath (Join-Path $Root 'recipes') -Filter '*.html' -ErrorAction SilentlyContinue | Remove-Item -Force

$Descriptions = @{}   # 메뉴 번호 → 페이지 설명 (rss.xml 에서 다시 씀)

foreach ($m in $items) {
  $r = $m.recipes
  $name = [string]$m.name
  $canonical = "$SiteUrl/recipes/" + $m.id
  $ingredients = Lines $r.ingredients
  $steps = Lines $r.steps

  # 사진 (위키미디어 공용)
  $photoUrl = ''
  $photoHtml = ''
  if ($m.photo) {
    $file = [Uri]::EscapeDataString([string]$m.photo)
    $photoUrl = 'https://commons.wikimedia.org/wiki/Special:FilePath/' + $file + '?width=800'
    $photoHtml = @(
      '      <figure class="photo-hero">'
      '        <img src="' + (Enc $photoUrl) + '" alt="' + (Enc $name) + '" width="800" height="500" loading="eager">'
      '        <figcaption>' + (PhotoCreditHtml ([string]$m.photo)) + '</figcaption>'
      '      </figure>'
    ) -join "`n"
  }

  # 조리 시간 · 난이도 · 인분
  $chips = @()
  if ($r.minutes)    { $chips += ('<span class="chip">' + $Ico.clock + [string]$r.minutes + '분</span>') }
  if ($r.difficulty) { $chips += ('<span class="chip">' + $Ico.flame + (Enc $r.difficulty) + '</span>') }
  if ($r.servings)   { $chips += ('<span class="chip">' + $Ico.user + [string]$r.servings + '인분</span>') }

  # 재료: "양념: ..." 처럼 이름표가 있는 줄은 한 줄 전체로
  $ingredientHtml = foreach ($line in $ingredients) {
    $labelled = [regex]::Match($line, '^([^:]{1,12}):\s*(.+)$')
    if ($labelled.Success) {
      '          <li class="wide"><strong>' + (Enc $labelled.Groups[1].Value) + ':</strong> ' + (Enc $labelled.Groups[2].Value) + '</li>'
    } else {
      '          <li>' + (Enc $line) + '</li>'
    }
  }
  $stepHtml = foreach ($line in $steps) { '          <li>' + (Enc $line) + '</li>' }

  $servingsText = ''
  if ($r.servings) { $servingsText = ' <small>(' + [string]$r.servings + '인분 기준)</small>' }

  $tipHtml = ''
  if ($r.tip) { $tipHtml = '        <p class="tip-note"><strong>냥셰프 팁</strong>' + (Enc $r.tip) + '</p>' }

  # 쿠팡 파트너스 링크가 있으면: 제목 아래에 안내 문구, 재료 아래에 버튼
  $adNoteTop = ''
  $shopHtml = ''
  $shopUrl = $shopLinks[[string]$m.id]
  if ($shopUrl) {
    $adNoteTop = '        <p class="ad-note">' + (Enc $AdNote) + '</p>'
    $shopHtml = @(
      '          <div class="shop-box">'
      '            <a class="pill-btn" href="' + (Enc $shopUrl) + '" target="_blank" rel="sponsored nofollow noopener">' + $Ico.cart + '쿠팡에서 재료 보기</a>'
      '            <p class="ad-note">쿠팡 파트너스 링크예요. 이 링크로 사면 냥셰프가 수수료를 받지만, 내는 가격은 똑같아요.</p>'
      '          </div>'
    ) -join "`n"
  }

  # 요리 영상 (누르기 전에는 미리보기 그림만)
  $videoHtml = ''
  $video = $Videos[[string]$m.id]
  if ($video) {
    $videoHtml = @(
      '      <section class="card" aria-labelledby="video-title">'
      '        <h2 id="video-title">영상으로 보기</h2>'
      '        <div class="video-lite">'
      '          <button class="video-play" type="button" data-video="' + $video.v + '" data-title="' + (Enc $video.t) + '" aria-label="' + (Enc ('요리 영상 재생: ' + $video.t)) + '">'
      '            <img src="https://i.ytimg.com/vi/' + $video.v + '/hqdefault.jpg" alt="" width="480" height="360" loading="lazy">'
      '            <span class="video-play-icon" aria-hidden="true"><svg viewBox="0 0 24 24"><path d="M8 5v14l11-7z"></path></svg></span>'
      '          </button>'
      '        </div>'
      '        <p class="video-credit">냥셰프가 고른 영상이에요. 레시피와 조금 다를 수 있어요. · <a href="https://www.youtube.com/watch?v=' + $video.v + '" target="_blank" rel="noopener">' + (Enc $video.c) + ' · YouTube</a></p>'
      '      </section>'
    ) -join "`n"
  }

  # 같은 종류 메뉴 먼저, 모자라면 같은 끼니의 다른 종류로 채움
  $same   = @($items | Where-Object { $_.meal -eq $m.meal -and $_.category -eq $m.category -and $_.id -ne $m.id })
  $others = @($items | Where-Object { $_.meal -eq $m.meal -and $_.category -ne $m.category })
  $related = @(($same + $others) | Select-Object -First 6)
  $relatedHtml = ($related | ForEach-Object { '          ' + (RecipeLink $_) }) -join "`n"

  $minutesText = ''
  if ($r.minutes) { $minutesText = '집에서 ' + [string]$r.minutes + '분이면 만들 수 있어요. ' }
  $lead = $name + ', ' + $minutesText + '냥셰프가 정리한 ' + $m.meal + ' ' + $m.category + ' 집밥 레시피예요.'
  # 카톡 등으로 공유할 때 링크 앞에 붙는 한마디
  $shareText = $name + ' 레시피, 냥셰프가 알려 줄게냥!'
  if ($r.minutes) { $shareText += ' ' + [string]$r.minutes + '분이면 뚝딱.' }

  $descParts = @()
  if ($r.minutes)    { $descParts += ('조리 시간 ' + [string]$r.minutes + '분') }
  if ($r.difficulty) { $descParts += ('난이도 ' + [string]$r.difficulty) }
  if ($r.servings)   { $descParts += ([string]$r.servings + '인분 기준') }
  # 설명에 주재료를 넣어서 페이지마다 다르고 구체적인 설명이 되게 함 ("양념: ..." 같은 줄은 뺌)
  $mainIngredients = @($ingredients | Where-Object { $_ -notmatch '^[^:]{1,12}:' } | Select-Object -First 3)
  $ingredientText = '재료와 만드는 법'
  if ($mainIngredients.Count) { $ingredientText = '재료(' + ($mainIngredients -join ', ') + ' 등)와 만드는 법' }
  $description = $name + ' 레시피: ' + ($descParts -join ', ') + '. ' + $ingredientText + ', 냥셰프 팁까지 한눈에 볼 수 있어요.'
  $Descriptions[[string]$m.id] = $description

  # 검색엔진용 레시피 정보 (schema.org Recipe)
  $ld = [ordered]@{
    '@context'         = 'https://schema.org'
    '@type'            = 'Recipe'
    name               = $name
    description        = $description
    recipeCategory     = [string]$m.meal
    recipeCuisine      = [string]$m.category
    recipeIngredient   = @($ingredients)
    recipeInstructions = @($steps | ForEach-Object { [ordered]@{ '@type' = 'HowToStep'; text = $_ } })
    author             = [ordered]@{ '@type' = 'Organization'; name = $SiteName; url = "$SiteUrl/" }
  }
  if ($photoUrl)     { $ld.image = @($photoUrl) }
  if ($r.minutes)    { $ld.totalTime = 'PT' + [string]$r.minutes + 'M' }
  if ($r.servings)   { $ld.recipeYield = [string]$r.servings + '인분' }
  $ld.keywords = $name + ', ' + $name + ' 레시피, ' + $m.meal + ' 메뉴, ' + $m.category + ', 집밥 레시피'
  $published = ParseTime $m.created_at
  $touched = Touched $m
  if ($published) { $ld.datePublished = $published.ToString('yyyy-MM-dd') }
  if ($touched)   { $ld.dateModified = $touched.ToString('yyyy-MM-dd') }

  # 검색 결과에 "홈 > 레시피 모음 > ..." 경로로 보이게 하는 정보
  $crumbLd = [ordered]@{
    '@context'      = 'https://schema.org'
    '@type'         = 'BreadcrumbList'
    itemListElement = @(
      (Crumb 1 '홈' "$SiteUrl/"),
      (Crumb 2 '레시피 모음' "$SiteUrl/recipes/"),
      (Crumb 3 ($name + ' 레시피') $canonical)
    )
  }

  $body = @"
      <nav class="breadcrumb" aria-label="현재 위치">
        <a href="../">홈</a><span aria-hidden="true">›</span>
        <a href="./">레시피 모음</a><span aria-hidden="true">›</span>
        <a href="./#$(MealAnchorOf $m.meal)">$(Enc $m.meal)</a><span aria-hidden="true">›</span>
        <span>$(Enc $m.category)</span>
      </nav>

      <div>
        <h1 class="page-title">$(Enc $name) 레시피</h1>
        <p class="page-lead">$(Enc $lead)</p>
$adNoteTop
      </div>

      <div class="page-actions">
        <button class="pill-btn" type="button" data-share="recipe" data-share-item="$(Enc $name)" data-share-text="$(Enc $shareText)">$($Ico.share)레시피 공유하기</button>
      </div>

$photoHtml

      <article class="card">
        <div class="chips">$($chips -join '')</div>

        <section>
          <h2>재료$servingsText</h2>
          <ul class="ingredient-list">
$($ingredientHtml -join "`n")
          </ul>
$shopHtml
        </section>

        <section>
          <h2>만드는 법</h2>
          <ol class="step-list">
$($stepHtml -join "`n")
          </ol>
        </section>

$tipHtml
        <a class="search-more" href="https://www.10000recipe.com/recipe/list.html?q=$([Uri]::EscapeDataString($name))" target="_blank" rel="noopener">다른 레시피도 찾아보기 →</a>
      </article>

$videoHtml

      <section class="card cta-card">
        <p class="cta-text">오늘 뭐 먹을지 아직 못 정했냥?</p>
        <a class="accent-btn" href="../" data-track="cta_pick_menu">냥셰프에게 메뉴 추천받기</a>
        <a href="../fridge.html" data-track="cta_fridge">냉장고에 있는 재료로 찾아보기 →</a>
      </section>

      <section>
        <h2>같이 보면 좋은 레시피</h2>
        <ul class="recipe-links-list">
$relatedHtml
        </ul>
      </section>
"@

  $html = Page @{
    Prefix      = '../'
    Title       = "$name 레시피 | $SiteName"
    Description = $description
    Canonical   = $canonical
    OgType      = 'article'
    Image       = $photoUrl
    ExtraHead   = (JsonLd $ld) + "`n" + (JsonLd $crumbLd)
    Body        = $body
  }
  Save ("recipes\" + $m.id + ".html") $html
}


# ── 레시피 모음 ─────────────────────────────────────────

$presentMeals = @($items | ForEach-Object { $_.meal } | Select-Object -Unique)

$mealSections = foreach ($meal in $presentMeals) {
  $inMeal = @($items | Where-Object { $_.meal -eq $meal })
  $anchor = MealAnchorOf $meal
  $icon = $MealIcon[$meal]
  if (-not $icon) { $icon = $Ico.bowl }

  $blocks = foreach ($category in @($inMeal | ForEach-Object { $_.category } | Select-Object -Unique)) {
    $links = (@($inMeal | Where-Object { $_.category -eq $category }) | ForEach-Object { '            ' + (RecipeLink $_) }) -join "`n"
    @"
        <div class="category-block">
          <h3>$(Enc $category)</h3>
          <ul class="recipe-links-list">
$links
          </ul>
        </div>
"@
  }

  @"
      <section class="card meal-section" id="$anchor">
        <h2>$icon$(Enc $meal) 레시피 <small>$($inMeal.Count)가지</small></h2>
$($blocks -join "`n")
      </section>
"@
}

$jump = ($presentMeals | ForEach-Object {
  $icon = $MealIcon[$_]
  if (-not $icon) { $icon = $Ico.bowl }
  '<a class="chip" href="#' + (MealAnchorOf $_) + '">' + $icon + (Enc $_) + '</a>'
}) -join ''

$indexBody = @"
      <nav class="breadcrumb" aria-label="현재 위치">
        <a href="../">홈</a><span aria-hidden="true">›</span>
        <span>레시피 모음</span>
      </nav>

      <div>
        <h1 class="page-title">냥셰프 레시피 모음</h1>
        <p class="page-lead">아침·점심·저녁 집밥 레시피 $($items.Count)가지를 모았어요. 메뉴를 누르면 재료와 만드는 법을 볼 수 있어요.</p>
      </div>

      <form class="card search-form" action="../search.html" method="get" role="search">
        <label for="index-search">찾는 메뉴가 있냥?</label>
        <div class="search-field">
          <input id="index-search" name="q" type="search" placeholder="메뉴 이름이나 재료 (예: 김치, 두부)" autocomplete="off" enterkeyhint="search">
          <button type="submit">검색</button>
        </div>
      </form>

      <nav class="chips" aria-label="끼니 바로가기">$jump</nav>

      <div class="page-actions">
        <a class="pill-btn" href="../fridge.html">$($Ico.fridge)냉장고에 있는 재료로 찾기</a>
      </div>

$($mealSections -join "`n`n")
"@

# 레시피 목록 정보 (구글 레시피 캐러셀용) + 경로 정보
$listLd = [ordered]@{
  '@context'      = 'https://schema.org'
  '@type'         = 'ItemList'
  itemListElement = @(for ($i = 0; $i -lt $items.Count; $i++) {
    [ordered]@{ '@type' = 'ListItem'; position = $i + 1; url = "$SiteUrl/recipes/" + $items[$i].id }
  })
}
$indexCrumbLd = [ordered]@{
  '@context'      = 'https://schema.org'
  '@type'         = 'BreadcrumbList'
  itemListElement = @((Crumb 1 '홈' "$SiteUrl/"), (Crumb 2 '레시피 모음' "$SiteUrl/recipes/"))
}

Save 'recipes\index.html' (Page @{
  Prefix      = '../'
  Title       = "냥셰프 레시피 모음 | 집밥 레시피 $($items.Count)가지"
  Description = "김치찌개부터 파스타, 샤브샤브까지. 아침·점심·저녁 집밥 레시피 $($items.Count)가지를 재료와 만드는 법, 냥셰프 팁과 함께 모았어요."
  Canonical   = "$SiteUrl/recipes/"
  ExtraHead   = (JsonLd $listLd) + "`n" + (JsonLd $indexCrumbLd)
  Body        = $indexBody
})


# ── 공유용 레시피 페이지 번호 목록 (메인 화면 "친구에게 공유하기"가 읽음) ──
# 페이지가 있는 메뉴는 레시피 페이지 주소를 공유함 (카톡 미리보기에 음식 사진이 뜸)

Save 'recipes\pages.json' ((ConvertTo-Json -InputObject @($items | ForEach-Object { [int]$_.id }) -Compress) + "`n")

# 메인 화면 "오늘은 이걸로 할래!" 도마에서 쓰는 요리 영상 목록 (메뉴 번호 → 영상 ID, 채널, 제목)
$videoMap = [ordered]@{}
foreach ($m in $items) { if ($Videos[[string]$m.id]) { $videoMap[[string]$m.id] = $Videos[[string]$m.id] } }
Save 'recipes\videos.json' ((ConvertTo-Json -InputObject $videoMap -Depth 3 -Compress) + "`n")

# 메인 화면이 사진 아래에 보여 줄 출처 (사진 파일 이름 → 작가, 라이선스, 라이선스 주소)
$creditMap = [ordered]@{}
$noCredit = @()
foreach ($m in $menus) {
  $photo = [string]$m.photo
  if (-not $photo) { continue }
  if ($Credits[$photo]) { $creditMap[$photo] = $Credits[$photo] } else { $noCredit += ('  ' + $m.id + ' ' + $m.name + ': ' + $photo) }
}
Save 'recipes\photo-credits.json' ((ConvertTo-Json -InputObject $creditMap -Depth 3 -Compress) + "`n")
if ($noCredit.Count) { Write-Warning ("tools\photos.csv 에 출처가 없는 사진 (tools\photo-credits.ps1 을 실행하세요):`n" + ($noCredit -join "`n")) }


# ── 냉장고 털기 (fridge.html) ─────────────────────────────
# 레시피마다 "꼭 필요한 재료 / 있으면 좋은 재료"는 tools/fridge.csv 에 사람이 정리해 둠
# (재료 글에서 자동으로 뽑으면 "토마토소스"가 "토마토"로, "김밥용 김"이 "밥"으로 잡히는 식으로 틀려서)
# 아래 목록에 있는 이름만 고를 수 있는 버튼이 되고, 나머지(춘장, 중화면 등)는 "더 필요"로만 보여 줌
# 소금·설탕·간장·고추장·된장·식용유·마늘 같은 기본 양념은 집에 있다고 보고 표에 적지 않음
# 새 메뉴를 추가하면 tools/fridge.csv 에도 한 줄 더해야 냉장고 털기에 나옴

$FridgeGroups = [ordered]@{
  '고기·달걀'    = @('달걀', '돼지고기', '소고기', '닭고기', '햄·소시지')
  '해산물'       = @('새우', '오징어', '조개', '어묵', '참치캔', '생선회')
  '채소'         = @('양파', '대파·쪽파', '감자', '고구마', '당근', '애호박', '버섯', '양배추', '배추', '콩나물', '숙주', '시금치', '부추', '청경채', '오이', '토마토', '깻잎', '상추·양상추', '청양고추', '파프리카', '무')
  '밥·면·빵·떡'  = @('밥', '쌀', '라면', '국수·소면', '쌀국수 면', '파스타면', '당면', '떡', '만두피', '식빵·빵')
  '그 밖의 재료' = @('김치', '두부', '치즈', '우유', '버터', '김', '미역', '카레', '토마토소스')
}
$chipSet = @{}
foreach ($g in $FridgeGroups.Keys) { foreach ($k in $FridgeGroups[$g]) { $chipSet[$k] = $true } }

function SplitItems([string]$s) { @($s -split '/' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }

$fridgeRows = @{}
$fridgePath = Join-Path $PSScriptRoot 'fridge.csv'
if (Test-Path -LiteralPath $fridgePath) {
  foreach ($row in @((ReadCsvText $fridgePath) -split "\r?\n" | Where-Object { $_.Trim() } | ConvertFrom-Csv)) {
    $id = ([string]$row.'번호').Trim()
    if ($id) { $fridgeRows[$id] = @{ Need = (SplitItems $row.'꼭 필요한 재료'); Nice = (SplitItems $row.'있으면 좋은 재료') } }
  }
}

$fridgeRecipes = @()
$noFridge = @()
foreach ($m in $items) {
  $row = $fridgeRows[[string]$m.id]
  if (-not $row) { $noFridge += ('  ' + $m.id + ' ' + $m.name); continue }
  $fridgeRecipes += [ordered]@{
    id         = [int]$m.id
    name       = [string]$m.name
    meal       = [string]$m.meal
    category   = [string]$m.category
    minutes    = $(if ($m.recipes.minutes) { [int]$m.recipes.minutes } else { $null })
    difficulty = [string]$m.recipes.difficulty
    need       = @($row.Need | Where-Object { $chipSet[$_] })
    needExtra  = @($row.Need | Where-Object { -not $chipSet[$_] })
    nice       = @($row.Nice | Where-Object { $chipSet[$_] })
    niceExtra  = @($row.Nice | Where-Object { -not $chipSet[$_] })
  }
}
if ($noFridge.Count) { Write-Warning ("tools\fridge.csv 에 재료가 없어서 냉장고 털기에서 빠진 메뉴:`n" + ($noFridge -join "`n")) }

# 레시피에서 실제로 쓰이는 재료만 버튼으로 보여 줌
$usedChips = @{}
foreach ($x in $fridgeRecipes) { foreach ($k in (@($x.need) + @($x.nice))) { $usedChips[$k] = $true } }

$groupHtml = @()
$gi = 0
foreach ($g in $FridgeGroups.Keys) {
  $names = @($FridgeGroups[$g] | Where-Object { $usedChips[$_] })
  if (-not $names.Count) { continue }
  $gi++
  $buttons = ($names | ForEach-Object { '            <button class="fridge-chip" type="button" data-key="' + (Enc $_) + '" aria-pressed="false">' + (Enc $_) + '</button>' }) -join "`n"
  $groupHtml += @"
        <div class="fridge-group" role="group" aria-labelledby="fridge-group-$gi">
          <h3 id="fridge-group-$gi">$(Enc $g)</h3>
          <div class="fridge-chips">
$buttons
          </div>
        </div>
"@
}

$fridgeJson = (ConvertTo-Json -InputObject ([ordered]@{ recipes = $fridgeRecipes }) -Depth 5 -Compress).Replace('</', '<\/')

$fridgeBody = @"
      <nav class="breadcrumb" aria-label="현재 위치">
        <a href="./">홈</a><span aria-hidden="true">›</span>
        <span>냉장고 털기</span>
      </nav>

      <div>
        <h1 class="page-title">냉장고 털기</h1>
        <p class="page-lead">집에 있는 재료를 골라 주세요. 냥셰프 레시피 $($fridgeRecipes.Count)가지 중에서 지금 만들 수 있는 메뉴를 찾아 줄게요.</p>
        <p class="fridge-note">소금·설탕·간장·고추장·된장·식용유·마늘 같은 기본 양념은 집에 있다고 칠게요.</p>
      </div>

      <section class="card fridge-picker" aria-labelledby="fridge-picker-title">
        <div class="fridge-head">
          <h2 id="fridge-picker-title">우리 집 냉장고에는…</h2>
          <button class="text-btn" id="fridge-reset" type="button" hidden>다 지우기</button>
        </div>
$($groupHtml -join "`n")
      </section>

      <p class="fridge-status" id="fridge-status" role="status"></p>
      <div class="fridge-results" id="fridge-results">
        <p class="fridge-empty">재료를 하나 이상 고르면 여기에 만들 수 있는 메뉴가 나와요.</p>
      </div>

      <script type="application/json" id="fridge-data">$fridgeJson</script>
"@

$fridgeCrumbLd = [ordered]@{
  '@context'      = 'https://schema.org'
  '@type'         = 'BreadcrumbList'
  itemListElement = @((Crumb 1 '홈' "$SiteUrl/"), (Crumb 2 '냉장고 털기' "$SiteUrl/fridge"))
}

Save 'fridge.html' (Page @{
  Prefix       = ''
  Title        = "냉장고 털기: 있는 재료로 메뉴 찾기 | $SiteName"
  Description  = '집에 있는 재료를 고르면 냥셰프 집밥 레시피 중에서 바로 만들 수 있는 메뉴와, 한두 가지만 더 있으면 되는 메뉴를 찾아 줘요. 김치, 달걀, 두부, 돼지고기로 오늘 뭐 먹을지 정해 보세요.'
  Canonical    = "$SiteUrl/fridge"
  ExtraHead    = JsonLd $fridgeCrumbLd
  ExtraScripts = '<script src="fridge.js?v=1"></script>'
  Body         = $fridgeBody
})


# ── 레시피 검색 (search.html) ─────────────────────────────
# 레시피 전체를 목록으로 미리 넣어 두고 (자바스크립트가 없어도 전체 목록은 보임),
# search.js 가 검색어·끼니·조리 시간·난이도에 맞게 거르고 순서를 바꿈.
# 검색 결과 페이지는 검색엔진에 올리지 않는 게 권장이라 noindex (대표 주소 없이 만듦)

$searchItems = foreach ($m in $items) {
  $r = $m.recipes
  $meta = @([string]$m.meal, [string]$m.category)
  if ($r.minutes) { $meta += ([string]$r.minutes + '분') }
  if ($r.difficulty) { $meta += [string]$r.difficulty }
  $ingredientData = (Lines $r.ingredients) -join '|'
  '          <li data-name="' + (Enc $m.name) + '" data-meal="' + (Enc $m.meal) + '" data-category="' + (Enc $m.category) + '" data-minutes="' + [string]$r.minutes + '" data-difficulty="' + (Enc $r.difficulty) + '" data-ingredients="' + (Enc $ingredientData) + '">' +
    '<a href="recipes/' + $m.id + '.html"><span class="name">' + (Enc $m.name) + '</span><span class="meta">' + (Enc ($meta -join ' · ')) + '</span><span class="snippet" hidden></span></a></li>'
}

function FilterChips([string]$filter, [string]$label, [string[]]$values, [string[]]$labels) {
  $buttons = for ($i = 0; $i -lt $values.Count; $i++) {
    $pressed = if ($i -eq 0) { 'true' } else { 'false' }
    '<button class="filter-chip" type="button" data-filter="' + $filter + '" data-value="' + (Enc $values[$i]) + '" aria-pressed="' + $pressed + '">' + (Enc $labels[$i]) + '</button>'
  }
  '          <div class="filter-group" role="group" aria-label="' + (Enc $label) + '"><span class="filter-group-label" aria-hidden="true">' + (Enc $label) + '</span>' + ($buttons -join '') + '</div>'
}

$mealValues = @('') + @($presentMeals)
$searchFilters = @(
  (FilterChips 'meal' '끼니' $mealValues (@('전체') + @($presentMeals)))
  (FilterChips 'time' '조리 시간' @('', '15', '30', '60') @('상관없이', '15분 이내', '30분 이내', '1시간 이내'))
  (FilterChips 'difficulty' '난이도' @('', '쉬움', '보통', '어려움') @('전체', '쉬움', '보통', '어려움'))
) -join "`n"

$suggestions = (@('김치', '달걀', '두부', '닭고기', '면', '찌개', 'ㄱㅊㅉㄱ') | ForEach-Object { '<button class="chip suggest-chip" type="button" data-q="' + (Enc $_) + '">' + (Enc $_) + '</button>' }) -join ''

$searchBody = @"
      <nav class="breadcrumb" aria-label="현재 위치">
        <a href="./">홈</a><span aria-hidden="true">›</span>
        <span>레시피 검색</span>
      </nav>

      <div>
        <h1 class="page-title">레시피 검색</h1>
        <p class="page-lead">메뉴 이름이나 재료로 냥셰프 레시피 $($items.Count)가지를 찾아보세요. "ㄱㅊㅉㄱ"처럼 초성으로도 찾을 수 있어요.</p>
      </div>

      <section class="card search-panel">
        <form class="search-form" id="search-form" action="search.html" method="get" role="search">
          <label for="search-q">무엇을 찾고 있냥?</label>
          <div class="search-field">
            <input id="search-q" name="q" type="search" placeholder="예: 김치찌개, 두부, 파스타" autocomplete="off" enterkeyhint="search">
            <button type="submit">검색</button>
          </div>
        </form>
        <div class="search-filters">
$searchFilters
        </div>
        <div class="search-suggest"><span class="filter-group-label">이런 건 어때요?</span>$suggestions</div>
      </section>

      <p class="search-status" id="search-status" role="status">레시피 $($items.Count)개</p>
      <ul class="recipe-links-list search-results" id="search-results">
$($searchItems -join "`n")
      </ul>
      <div class="search-empty" id="search-empty" hidden>
        <p>찾는 레시피가 아직 없어요. 다른 말로 찾아보거나, 가진 재료로 찾아보세요.</p>
        <div class="page-actions">
          <button class="pill-btn" id="search-reset" type="button" hidden>끼니·시간·난이도 조건 풀기</button>
          <a class="pill-btn" href="fridge.html">$($Ico.fridge)냉장고 털기</a>
          <a class="pill-btn" href="board.html">메뉴 건의하기</a>
        </div>
      </div>
"@

Save 'search.html' (Page @{
  Prefix       = ''
  Title        = "레시피 검색 | $SiteName"
  Description  = "메뉴 이름, 재료, 초성으로 냥셰프 집밥 레시피 $($items.Count)가지를 찾아보세요. 끼니와 조리 시간, 난이도로도 고를 수 있어요."
  ExtraScripts = '<script src="search.js?v=1"></script>'
  Body         = $searchBody
})


# ── 사이트 소개, 개인정보처리방침 (본문은 tools/pages/*.html) ──

$staticPages = @(
  @{ File = 'about';   Title = "사이트 소개 | $SiteName";     Description = '고양이 요리사 냥셰프가 아침·점심·저녁 메뉴를 골라 주고, 집에서 따라 하기 쉬운 레시피를 알려 주는 사이트예요.' }
  @{ File = 'privacy'; Title = "개인정보처리방침 | $SiteName"; Description = ($SiteName + '가 어떤 개인정보를 왜 모으고 어떻게 보호하는지 알려 드려요.') }
)
# 광고·제휴 안내: 쿠팡 파트너스 링크가 하나라도 켜져 있을 때와 아닐 때 문구가 다름
if ($shopLinks.Count) {
  $affiliateAbout = @(
    '        <p>일부 레시피에는 "쿠팡에서 재료 보기" 버튼이 있어요. 쿠팡 파트너스 제휴 링크라서, 이 버튼을 거쳐 쿠팡에서 물건을 사면 냥셰프가 쿠팡에게서 일정액의 수수료를 받아요. 사는 분이 내는 가격은 똑같아요.</p>'
    '        <p>' + $AdNote + '</p>'
    '        <p>쿠팡으로 이동한 뒤의 정보 처리는 <a href="privacy.html">개인정보처리방침</a>에 적어 두었어요.</p>'
  ) -join "`n"
  $affiliatePrivacy = @(
    '        <p>일부 레시피의 "쿠팡에서 재료 보기" 버튼은 쿠팡 파트너스 제휴 링크예요.</p>'
    '        <ul>'
    '          <li>이 사이트는 버튼을 누르기 전까지 쿠팡에 어떤 정보도 보내지 않아요.</li>'
    '          <li>버튼을 누르면 쿠팡으로 이동하고, 쿠팡이 어느 사이트를 거쳐 왔는지 쿠키로 기록해요. 그다음부터는 <a href="https://privacy.coupang.com/ko/center/coupang/" target="_blank" rel="noopener">쿠팡의 개인정보처리방침</a>이 적용돼요.</li>'
    '          <li>냥셰프는 쿠팡에서 어떤 상품이 몇 개 팔렸는지 같은 통계만 받고, 누가 샀는지는 알 수 없어요.</li>'
    '        </ul>'
    '        <p>그 밖의 광고는 아직 없어요. 새 광고를 넣게 되면 광고 업체와 광고용 쿠키 사용 내용을 이 방침에 먼저 추가할게요.</p>'
  ) -join "`n"
} else {
  $affiliateAbout = '        <p>사이트를 계속 운영하기 위해 앞으로 광고나 제휴 링크가 들어갈 수 있어요. 광고가 들어가면 광고임을 알아볼 수 있게 표시하고, <a href="privacy.html">개인정보처리방침</a>도 함께 고칠게요.</p>'
  $affiliatePrivacy = '        <p>지금은 사이트에 광고가 없어요. 앞으로 광고나 제휴 링크를 넣게 되면, 광고 업체와 광고용 쿠키 사용 내용을 이 방침에 추가하고 사이트에 미리 알릴게요.</p>'
}

foreach ($p in $staticPages) {
  $bodyPath = Join-Path $Root ('tools\pages\' + $p.File + '.html')
  $body = [IO.File]::ReadAllText($bodyPath, $Utf8).TrimEnd()
  $body = Fill $body @{ AFFILIATE_ABOUT = $affiliateAbout; AFFILIATE_PRIVACY = $affiliatePrivacy }
  Save ($p.File + '.html') (Page @{
    Prefix      = ''
    Title       = $p.Title
    Description = $p.Description
    Canonical   = "$SiteUrl/" + $p.File
    Body        = $body
  })
}


# ── 404 페이지 (없는 주소로 오면 Cloudflare가 보여 줌) ──────
# 어느 폴더 주소에서든 보여야 해서 링크를 사이트 맨 위 기준(/)으로 씀

$notFoundBody = [IO.File]::ReadAllText((Join-Path $Root 'tools\pages\404.html'), $Utf8).TrimEnd()
Save '404.html' (Page @{
  Prefix      = '/'
  Title       = "페이지를 찾을 수 없어요 | $SiteName"
  Description = '주소가 바뀌었거나 잘못 입력된 것 같아요.'
  Body        = $notFoundBody
})


# ── sitemap.xml ─────────────────────────────────────────

# lastmod(마지막 수정일)는 실제로 레시피를 고친 날만 적음. 매번 오늘 날짜를 적으면 구글이 믿지 않음
# 손으로 고치는 페이지(홈, 소개, 개인정보처리방침)는 날짜를 적지 않음
$latestDay = if ($Latest) { $Latest.ToString('yyyy-MM-dd') } else { $Today }
$entries = @(
  @{ Loc = "$SiteUrl/" }
  @{ Loc = "$SiteUrl/recipes/"; Mod = $latestDay }
  @{ Loc = "$SiteUrl/fridge"; Mod = $latestDay }
  @{ Loc = "$SiteUrl/about" }
  @{ Loc = "$SiteUrl/privacy" }
) + @($items | ForEach-Object {
  $t = Touched $_
  @{ Loc = "$SiteUrl/recipes/" + $_.id; Mod = $(if ($t) { $t.ToString('yyyy-MM-dd') } else { $latestDay }) }
})
$sitemap = @('<?xml version="1.0" encoding="UTF-8"?>', '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">')
$sitemap += $entries | ForEach-Object {
  if ($_.Mod) { "  <url><loc>$($_.Loc)</loc><lastmod>$($_.Mod)</lastmod></url>" } else { "  <url><loc>$($_.Loc)</loc></url>" }
}
$sitemap += '</urlset>'
Save 'sitemap.xml' (($sitemap -join "`n") + "`n")


# ── rss.xml (네이버 서치어드바이저 "RSS 제출"용, 새 레시피가 위로) ─────

function Xml([string]$s) { [Security.SecurityElement]::Escape($s) }
function RssDate($t) { $t.UtcDateTime.ToString('ddd, dd MMM yyyy HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture) + ' +0000' }

$rssItems = $items | Sort-Object @{ Expression = { $t = ParseTime $_.created_at; if ($t) { $t.UtcTicks } else { 0 } }; Descending = $true }, @{ Expression = { [int]$_.id }; Descending = $true }
$rss = @(
  '<?xml version="1.0" encoding="UTF-8"?>'
  '<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">'
  '<channel>'
  '  <title>' + (Xml ($SiteName + ' 레시피')) + '</title>'
  '  <link>' + $SiteUrl + '/</link>'
  '  <description>고양이 요리사 냥셰프가 정리한 아침·점심·저녁 집밥 레시피</description>'
  '  <language>ko</language>'
  '  <atom:link href="' + $SiteUrl + '/rss.xml" rel="self" type="application/rss+xml"/>'
)
if ($Latest) { $rss += '  <lastBuildDate>' + (RssDate $Latest) + '</lastBuildDate>' }
foreach ($m in $rssItems) {
  $link = "$SiteUrl/recipes/" + $m.id
  $rss += '  <item>'
  $rss += '    <title>' + (Xml ([string]$m.name + ' 레시피')) + '</title>'
  $rss += '    <link>' + $link + '</link>'
  $rss += '    <guid isPermaLink="true">' + $link + '</guid>'
  $rss += '    <description>' + (Xml $Descriptions[[string]$m.id]) + '</description>'
  $rss += '    <category>' + (Xml ([string]$m.meal)) + '</category>'
  $rss += '    <category>' + (Xml ([string]$m.category)) + '</category>'
  $published = ParseTime $m.created_at
  if ($published) { $rss += '    <pubDate>' + (RssDate $published) + '</pubDate>' }
  $rss += '  </item>'
}
$rss += '</channel>'
$rss += '</rss>'
Save 'rss.xml' (($rss -join "`n") + "`n")


# ── llms.txt (AI가 사이트를 한눈에 이해하도록 쓴 안내, https://llmstxt.org 형식) ──

$llms = @(
  '# ' + $SiteName
  ''
  '> 고양이 요리사 캐릭터 "냥셰프"가 아침·점심·저녁 메뉴를 골라 주고, 집에서 따라 하기 쉬운 집밥 레시피 ' + $items.Count + '가지를 알려 주는 한국어 사이트입니다.'
  ''
  '- 메뉴 추천: 끼니(아침·점심·저녁)와 음식 종류를 고르면 메뉴 하나를 무작위로 추천합니다. 로그인하면 좋아요/별로예요에 맞춰 추천이 달라집니다.'
  '- 레시피: 메뉴마다 조리 시간, 난이도, 인분, 재료, 만드는 법, 요리 팁을 정리한 페이지가 있습니다.'
  '- 음식 사진은 위키미디어 공용의 자유 라이선스 사진이고, 레시피는 이 사이트가 직접 정리했습니다.'
  ''
  '## 주요 페이지'
  ''
  '- [메뉴 추천 (홈)](' + $SiteUrl + '/): 냥셰프에게 오늘의 메뉴 추천받기'
  '- [레시피 모음](' + $SiteUrl + '/recipes/): 끼니와 종류별 전체 레시피 목록'
  '- [냉장고 털기](' + $SiteUrl + '/fridge): 집에 있는 재료를 고르면 바로 만들 수 있는 레시피를 찾아 주는 도구'
  '- [레시피 검색](' + $SiteUrl + '/search): 메뉴 이름, 재료, 초성으로 레시피를 찾는 검색 (예: ' + $SiteUrl + '/search?q=두부)'
  '- [사이트 소개](' + $SiteUrl + '/about): 사이트가 하는 일, 사진 출처, 문의처'
)
foreach ($meal in $presentMeals) {
  $llms += ''
  $llms += '## ' + $meal + ' 레시피'
  $llms += ''
  foreach ($x in @($items | Where-Object { $_.meal -eq $meal })) {
    $meta = @([string]$x.category)
    if ($x.recipes.minutes) { $meta += ([string]$x.recipes.minutes + '분') }
    if ($x.recipes.difficulty) { $meta += [string]$x.recipes.difficulty }
    $llms += '- [' + $x.name + ' 레시피](' + $SiteUrl + '/recipes/' + $x.id + '): ' + ($meta -join ' · ')
  }
}
$llms += ''
$llms += '## 그 밖의 안내'
$llms += ''
$llms += '- [개인정보처리방침](' + $SiteUrl + '/privacy)'
$llms += '- [사이트맵](' + $SiteUrl + '/sitemap.xml)'
Save 'llms.txt' (($llms -join "`n") + "`n")

Write-Host ("Done: {0} recipe pages, recipes/index.html, about.html, privacy.html, sitemap.xml ({1} URLs), rss.xml, llms.txt, coupang links {2}, videos {3}" -f $items.Count, $entries.Count, $shopLinks.Count, $videoMap.Count)
