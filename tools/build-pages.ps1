# 냥셰프 글 페이지 생성기
#
# Supabase의 menus + recipes 데이터를 읽어서 아래 파일을 새로 만듭니다.
#   recipes/<메뉴번호>.html   메뉴별 레시피 페이지
#   recipes/index.html        레시피 모음
#   about.html, privacy.html  사이트 소개, 개인정보처리방침 (본문은 tools/pages/ 에 있음)
#   sitemap.xml               검색엔진에 알려 줄 페이지 목록
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
<link rel="stylesheet" href="{{PREFIX}}style.css?v=4">
<link rel="stylesheet" href="{{PREFIX}}pages.css?v=2">
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
        <a href="{{PREFIX}}about.html">사이트 소개</a>
        <a href="{{PREFIX}}privacy.html">개인정보처리방침</a>
      </nav>
      <p>음식 사진: 위키미디어 공용 · 레시피: 냥셰프</p>
    </footer>
  </div>

  <div class="gingham gingham-bottom" aria-hidden="true"></div>

<script src="{{PREFIX}}theme.js?v=1"></script>
</body>
</html>
'@

function Page([hashtable]$p) {
  $prefix = [string]$p.Prefix
  $homeLink = if ($prefix) { $prefix } else { './' }
  $ogImage = ''
  if ($p.Image) { $ogImage = '<meta property="og:image" content="' + (Enc $p.Image) + '">' }
  # 대표 주소가 없는 페이지(404)는 검색엔진에 올리지 않음
  if ($p.Canonical) {
    $canonicalTags = '<link rel="canonical" href="' + (Enc $p.Canonical) + '">' + "`n" + '<meta property="og:url" content="' + (Enc $p.Canonical) + '">'
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

$query = 'menus?select=id,meal,category,name,photo,recipes(minutes,difficulty,servings,ingredients,steps,tip)&order=id'
$response = Invoke-WebRequest -UseBasicParsing -Uri "$sbUrl/rest/v1/$query" -Headers @{ apikey = $sbKey }
# Windows PowerShell은 JSON 배열을 한 덩어리로 넘겨주므로, 한 번 더 풀어서 메뉴 하나하나로 만듦
$parsed = $Utf8.GetString($response.RawContentStream.ToArray()) | ConvertFrom-Json
$menus = @($parsed | ForEach-Object { $_ })

# 레시피가 있는 메뉴만, 아침 → 점심 → 저녁, 같은 끼니 안에서는 메뉴 번호 순서로
$items = @($menus | Where-Object { $_.recipes } | Sort-Object @{ Expression = { MealRank $_.meal } }, id)
if ($items.Count -eq 0) { throw '레시피가 있는 메뉴를 하나도 찾지 못했어요.' }


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
      '        <figcaption><a href="https://commons.wikimedia.org/wiki/File:' + $file + '" target="_blank" rel="noopener">사진: 위키미디어 공용</a></figcaption>'
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

  # 같은 종류 메뉴 먼저, 모자라면 같은 끼니의 다른 종류로 채움
  $same   = @($items | Where-Object { $_.meal -eq $m.meal -and $_.category -eq $m.category -and $_.id -ne $m.id })
  $others = @($items | Where-Object { $_.meal -eq $m.meal -and $_.category -ne $m.category })
  $related = @(($same + $others) | Select-Object -First 6)
  $relatedHtml = ($related | ForEach-Object { '          ' + (RecipeLink $_) }) -join "`n"

  $minutesText = ''
  if ($r.minutes) { $minutesText = '집에서 ' + [string]$r.minutes + '분이면 만들 수 있어요. ' }
  $lead = $name + ', ' + $minutesText + '냥셰프가 정리한 ' + $m.meal + ' ' + $m.category + ' 집밥 레시피예요.'

  $descParts = @()
  if ($r.minutes)    { $descParts += ('조리 시간 ' + [string]$r.minutes + '분') }
  if ($r.difficulty) { $descParts += ('난이도 ' + [string]$r.difficulty) }
  if ($r.servings)   { $descParts += ([string]$r.servings + '인분 기준') }
  $description = $name + ' 레시피: ' + ($descParts -join ', ') + '. 재료와 만드는 법, 냥셰프 팁까지 한눈에 볼 수 있어요.'

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
  $ldJson = ($ld | ConvertTo-Json -Depth 6 -Compress).Replace('</', '<\/')

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

      <section class="card cta-card">
        <p class="cta-text">오늘 뭐 먹을지 아직 못 정했냥?</p>
        <a class="accent-btn" href="../">냥셰프에게 메뉴 추천받기</a>
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
    ExtraHead   = '<script type="application/ld+json">' + $ldJson + '</script>'
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

      <nav class="chips" aria-label="끼니 바로가기">$jump</nav>

$($mealSections -join "`n`n")
"@

Save 'recipes\index.html' (Page @{
  Prefix      = '../'
  Title       = "냥셰프 레시피 모음 | 집밥 레시피 $($items.Count)가지"
  Description = "김치찌개부터 파스타, 샤브샤브까지. 아침·점심·저녁 집밥 레시피 $($items.Count)가지를 재료와 만드는 법, 냥셰프 팁과 함께 모았어요."
  Canonical   = "$SiteUrl/recipes/"
  Body        = $indexBody
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

$urls = @("$SiteUrl/", "$SiteUrl/recipes/", "$SiteUrl/about", "$SiteUrl/privacy") + @($items | ForEach-Object { "$SiteUrl/recipes/" + $_.id })
$sitemap = @('<?xml version="1.0" encoding="UTF-8"?>', '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">')
$sitemap += $urls | ForEach-Object { "  <url><loc>$_</loc><lastmod>$Today</lastmod></url>" }
$sitemap += '</urlset>'
Save 'sitemap.xml' (($sitemap -join "`n") + "`n")

Write-Host ("Done: {0} recipe pages, recipes/index.html, about.html, privacy.html, sitemap.xml ({1} URLs), coupang links {2}" -f $items.Count, $urls.Count, $shopLinks.Count)
