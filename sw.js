// 냥빵이 앱(PWA)용 서비스 워커: 한 번 본 페이지는 인터넷이 끊겨도 열리게 하고, 다시 열 때 빨리 뜨게 함
// - 페이지(HTML): 인터넷에서 먼저 받고(늘 최신), 안 되면 저장해 둔 것, 그것도 없으면 "인터넷이 끊겼다냥" 화면
// - 같은 사이트의 css·js·그림·json: 저장해 둔 걸 바로 보여 주고, 뒤에서 새로 받아 다음번에 씀
// - 다른 사이트(Supabase 로그인·기록, 구글 글꼴, 위키미디어 사진, 통계, 유튜브)는 건드리지 않음
// 저장 방식을 바꾸면 CACHE 이름의 숫자를 올리세요 (예전 저장분은 자동으로 지워짐)

const CACHE = 'nyangbbang-v1';
const CORE = ['/', '/style.css?v=11', '/pages.css?v=7', '/theme.js?v=1', '/site.js?v=3', '/common.js?v=7', '/config.js', '/favicon.svg', '/favicon-192.png'];

const OFFLINE_HTML = `<!doctype html>
<html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>인터넷이 끊겼다냥</title>
<style>
  body { margin: 0; min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 24px; box-sizing: border-box; background: #FBF3E4; color: #4A3426; font-family: sans-serif; text-align: center; }
  h1 { margin: 12px 0 8px; font-size: 24px; }
  p { margin: 0 0 20px; line-height: 1.6; color: #7A6352; word-break: keep-all; }
  button { height: 48px; padding: 0 24px; border: 0; border-radius: 14px; background: #B8552F; color: #FFFFFF; font-size: 17px; }
</style></head>
<body><div>
  <img src="/favicon-192.png" width="96" height="96" alt="">
  <h1>인터넷이 끊겼다냥</h1>
  <p>연결되면 다시 메뉴를 골라 줄게냥.<br>전에 열어 본 레시피는 그대로 볼 수 있어요.</p>
  <button type="button" onclick="location.reload()">다시 시도</button>
</div></body></html>`;

self.addEventListener('install', event => {
  // 하나가 실패해도 나머지는 저장 (개발용 주소 등에서 없는 파일이 있어도 설치는 됨)
  event.waitUntil(
    caches.open(CACHE)
      .then(cache => Promise.allSettled(CORE.map(url => cache.add(url))))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(key => key !== CACHE).map(key => caches.delete(key))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', event => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;
  if (url.pathname === '/sw.js') return;

  if (request.mode === 'navigate') event.respondWith(networkFirst(request));
  else event.respondWith(staleWhileRevalidate(request, event));
});

async function networkFirst(request) {
  const cache = await caches.open(CACHE);
  try {
    const response = await fetch(request);
    if (response.ok) cache.put(request, response.clone());
    return response;
  } catch (err) {
    const saved = await cache.match(request, { ignoreSearch: true });
    return saved || new Response(OFFLINE_HTML, { headers: { 'Content-Type': 'text/html; charset=utf-8' } });
  }
}

async function staleWhileRevalidate(request, event) {
  const cache = await caches.open(CACHE);
  const saved = await cache.match(request);
  const fresh = fetch(request)
    .then(response => {
      if (response.ok) cache.put(request, response.clone());
      return response;
    })
    .catch(() => null);
  if (saved) {
    event.waitUntil(fresh);
    return saved;
  }
  return (await fresh) || Response.error();
}
