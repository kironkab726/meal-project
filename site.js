// 모든 페이지가 함께 쓰는 작은 도구
//   track(이름, 정보)   구글 애널리틱스·클라리티에 "무슨 버튼을 눌렀는지" 남김 (개인정보는 넣지 않음)
//   shareLink({...})    휴대폰은 공유 창(카카오톡 등), 컴퓨터는 링크 복사
//   toast(글)           화면 아래에 잠깐 뜨는 알림
// 버튼에 data-share="recipe" 를 달면 그 페이지 주소를 공유하고,
// 링크에 data-track="이벤트이름" 을 달면 누를 때 통계에 남김
(function () {
  const SITE_URL = 'https://meal-project.pages.dev';

  function track(name, params) {
    try {
      if (typeof window.gtag === 'function') window.gtag('event', name, params || {});
      if (typeof window.clarity === 'function') window.clarity('event', name);
    } catch (e) {}
  }

  // 알림 칸은 처음부터 만들어 둬야 화면 읽기 프로그램이 새 글을 읽어 줌
  const toastEl = document.createElement('div');
  toastEl.className = 'toast';
  toastEl.setAttribute('role', 'status');
  document.body.append(toastEl);
  let toastTimer = null;

  function toast(message) {
    toastEl.textContent = message;
    toastEl.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toastEl.classList.remove('show'), 2800);
  }

  // 운영자 기기 빼기 (?nb_me=1 켜기 / ?nb_me=0 끄기). 실제 스위치는 각 페이지 <head> 맨 위 코드가 켬
  // 여기서는 잘 됐다고 알려 주고, 주소에서 표시를 지움 (공유할 때 딸려 가지 않게)
  const meParam = new URLSearchParams(location.search).get('nb_me');
  if (meParam === '1' || meParam === '0') {
    const url = new URL(location.href);
    url.searchParams.delete('nb_me');
    history.replaceState(null, '', url);
    setTimeout(() => toast(meParam === '1'
      ? '이 기기는 이제 방문 통계에서 빠져요.'
      : '이 기기도 다시 방문 통계에 들어가요.'), 500);
  }

  async function copyText(text) {
    try {
      await navigator.clipboard.writeText(text);
      return true;
    } catch (e) {}
    // 예전 브라우저용
    const area = document.createElement('textarea');
    area.value = text;
    area.setAttribute('readonly', '');
    area.className = 'copy-helper';
    document.body.append(area);
    area.select();
    let ok = false;
    try { ok = document.execCommand('copy'); } catch (e) {}
    area.remove();
    return ok;
  }

  // 공유로 들어온 방문자를 통계에서 따로 볼 수 있게 표시를 붙임
  function withShareTag(url) {
    const u = new URL(url, SITE_URL);
    u.searchParams.set('utm_source', 'share');
    u.searchParams.set('utm_medium', 'social');
    return u.toString();
  }

  async function shareLink({ title, text, url, contentType, itemId }) {
    const link = withShareTag(url);
    const info = { content_type: contentType || 'page', item_id: itemId || '' };
    const touch = window.matchMedia('(pointer: coarse)').matches;

    if (navigator.share && touch) {
      try {
        await navigator.share({ title, text, url: link });
        track('share', Object.assign({ method: 'share_sheet' }, info));
        return;
      } catch (e) {
        if (e && e.name === 'AbortError') return;   // 공유 창을 닫음
      }
    }

    if (await copyText(`${text}\n${link}`)) {
      toast('링크를 복사했어요. 카톡에 붙여 넣어 보내 보세요!');
      track('share', Object.assign({ method: 'copy_link' }, info));
    } else {
      window.prompt('아래 주소를 복사해 주세요.', link);
    }
  }

  // 요리 영상: 처음엔 미리보기 그림만 보여 주고, 누르면 그때 유튜브 플레이어를 붙임
  // (페이지가 빨리 뜨고, 누르기 전까지는 유튜브 쿠키가 생기지 않음)
  function playVideo(btn) {
    const id = btn.dataset.video || '';
    if (!/^[\w-]{11}$/.test(id)) return;
    const frame = document.createElement('iframe');
    frame.src = `https://www.youtube-nocookie.com/embed/${id}?autoplay=1&rel=0&playsinline=1`;
    frame.title = btn.dataset.title || '요리 영상';
    frame.allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share';
    frame.allowFullscreen = true;
    frame.referrerPolicy = 'strict-origin-when-cross-origin';
    btn.replaceWith(frame);
    track('play_video', { video_id: id, label: btn.dataset.title || '' });
  }

  document.addEventListener('click', e => {
    const playBtn = e.target.closest('.video-play');
    if (playBtn) {
      playVideo(playBtn);
      return;
    }
    const shareBtn = e.target.closest('[data-share]');
    if (shareBtn) {
      const canonical = document.querySelector('link[rel="canonical"]');
      shareLink({
        title: document.title,
        text: shareBtn.dataset.shareText || document.title,
        url: canonical ? canonical.href : location.href,
        contentType: shareBtn.dataset.share,
        itemId: shareBtn.dataset.shareItem,
      });
      return;
    }
    const tracked = e.target.closest('[data-track]');
    if (tracked) track(tracked.dataset.track, { label: tracked.dataset.trackLabel || '' });
  });

  // ── 앱으로 설치 (PWA) ──────────────────────────────────
  // 서비스 워커(sw.js): 한 번 본 페이지는 인터넷이 끊겨도 열리고, 다시 열 때 빨리 뜸
  if ('serviceWorker' in navigator && (location.hostname === 'meal-project.pages.dev' || location.hostname === 'localhost')) {
    window.addEventListener('load', () => navigator.serviceWorker.register('/sw.js').catch(() => {}));
  }

  // data-install 이 달린 버튼(아래쪽 링크, 메뉴판)은 설치할 수 있을 때만 보임
  //   안드로이드·컴퓨터 크롬: 브라우저가 "설치할 수 있음"을 알려 주면 버튼을 보여 주고, 누르면 설치 창
  //   아이폰: 설치 창이 없어서, 누르면 "공유 → 홈 화면에 추가" 방법을 알려 줌
  let installPrompt = null;
  const installed = () => window.matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;
  const isIOS = /iphone|ipad|ipod/i.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  const showInstall = show => document.querySelectorAll('[data-install]').forEach(el => { el.hidden = !show; });

  window.addEventListener('beforeinstallprompt', e => {
    e.preventDefault();
    installPrompt = e;
    showInstall(true);
  });
  window.addEventListener('appinstalled', () => {
    installPrompt = null;
    showInstall(false);
    toast('냥빵이 앱을 설치했어요! 홈 화면에서 열어 보세요.');
    track('app_installed');
  });
  if (isIOS && !installed()) showInstall(true);

  let iosHelp = null;
  function showIOSHelp() {
    if (!iosHelp) {
      iosHelp = document.createElement('dialog');
      iosHelp.className = 'install-help';
      const title = document.createElement('h2');
      title.textContent = '아이폰에 냥빵이 앱 설치하기';
      const steps = document.createElement('ol');
      ['화면 아래(또는 위)의 공유 버튼(네모에 위쪽 화살표)을 눌러요.', '목록에서 "홈 화면에 추가"를 눌러요.', '오른쪽 위 "추가"를 누르면 끝! 홈 화면에 냥빵이가 생겨요.']
        .forEach(text => { const li = document.createElement('li'); li.textContent = text; steps.append(li); });
      const close = document.createElement('button');
      close.type = 'button';
      close.className = 'pill-btn';
      close.textContent = '알겠어요';
      close.addEventListener('click', () => iosHelp.close());
      iosHelp.append(title, steps, close);
      iosHelp.addEventListener('click', e => { if (e.target === iosHelp) iosHelp.close(); });
      document.body.append(iosHelp);
    }
    iosHelp.showModal();
  }

  document.addEventListener('click', async e => {
    if (!e.target.closest('[data-install]')) return;
    e.preventDefault();   // 메뉴판의 설치 링크가 페이지를 옮기지 않게
    track('app_install_click', { label: installPrompt ? 'prompt' : (isIOS ? 'ios_help' : 'none') });
    if (installPrompt) {
      installPrompt.prompt();
      const choice = await installPrompt.userChoice;
      installPrompt = null;
      if (choice.outcome === 'accepted') showInstall(false);
    } else if (isIOS) {
      showIOSHelp();
    }
  });

  window.SITE_URL = SITE_URL;
  window.track = track;
  window.toast = toast;
  window.shareLink = shareLink;
})();
