# 마케팅 그림·글을 저장하는 폴더 (사이트 저장소 밖, 바탕 화면의 "뭐 먹지 프로젝트 마케팅")
# 블로그·유튜브·인스타용 결과물은 모두 여기에 모읍니다. 폴더 이름을 바꾸면 이 줄만 고치세요.
#
# 다른 스크립트에서:  . (Join-Path $PSScriptRoot 'marketing-path.ps1')  →  $MarketingDir 사용

$MarketingDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) '뭐 먹지 프로젝트 마케팅'
if (-not (Test-Path -LiteralPath $MarketingDir)) { New-Item -ItemType Directory -Force $MarketingDir | Out-Null }
