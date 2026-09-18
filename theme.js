// 다크/라이트 모드 전환 버튼 (모든 페이지 공통)
// 고른 모드는 브라우저에 저장해서 새로고침해도 유지. 처음 적용은 각 페이지 <head>의 작은 스크립트가 맡음

(function () {
  const themeBtn = document.getElementById('theme-toggle');
  if (!themeBtn) return;

  function applyTheme(theme) {
    document.documentElement.dataset.theme = theme;
    const label = theme === 'dark' ? '라이트 모드로 전환' : '다크 모드로 전환';
    themeBtn.setAttribute('aria-label', label);
    themeBtn.title = label;
  }

  themeBtn.addEventListener('click', () => {
    const theme = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark';
    applyTheme(theme);
    try { localStorage.setItem('menu-picker-theme', theme); } catch (e) {}
  });

  applyTheme(document.documentElement.dataset.theme);
})();
