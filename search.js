// 레시피 검색: 페이지에 미리 들어 있는 레시피 목록을 검색어·끼니·조리 시간·난이도로 거르고 순서를 바꿈
// 찾는 곳: 메뉴 이름 > 초성(ㄱㅊㅉㄱ) > 종류·끼니(한식, 점심) > 재료
// 검색어를 띄어 쓰면 모든 낱말이 맞는 레시피만 보여 줌 (예: "김치 돼지고기")
(function () {
  const form = document.getElementById('search-form');
  const input = document.getElementById('search-q');
  const list = document.getElementById('search-results');
  const statusEl = document.getElementById('search-status');
  const emptyEl = document.getElementById('search-empty');
  const chips = Array.from(document.querySelectorAll('.filter-chip'));
  const suggestEl = document.querySelector('.search-suggest');

  // 같은 재료를 다르게 부르는 말
  const SYNONYMS = {
    계란: ['달걀'], 달걀: ['계란'], 쇠고기: ['소고기'], 소고기: ['쇠고기'], 돈까스: ['돈카츠'], 돈가스: ['돈카츠'],
    스파게티: ['파스타'], 파스타: ['스파게티'], 스팸: ['햄'], 닭: ['닭고기'], 돼지: ['돼지고기'], 국수: ['면'],
  };
  const CHOSUNG = 'ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ';

  const norm = text => (text || '').toLowerCase().replace(/\s+/g, '');
  const initials = text => Array.from(text).map(ch => {
    const code = ch.charCodeAt(0) - 0xAC00;
    return code >= 0 && code <= 11171 ? CHOSUNG[Math.floor(code / 588)] : ch;
  }).join('');

  const items = Array.from(list.children).map((li, index) => {
    const ingredients = (li.dataset.ingredients || '').split('|').filter(Boolean);
    const name = li.dataset.name || '';
    return {
      li, index, name, ingredients,
      meal: li.dataset.meal || '',
      difficulty: li.dataset.difficulty || '',
      minutes: Number(li.dataset.minutes) || 0,
      nName: norm(name),
      iName: norm(initials(name)),
      nCategory: norm(li.dataset.category),
      nMeal: norm(li.dataset.meal),
      nIngredients: ingredients.map(norm),
      snippet: li.querySelector('.snippet'),
    };
  });

  const filters = { meal: '', time: '', difficulty: '' };

  // 낱말 하나가 레시피의 어디에 맞는지 점수로 (안 맞으면 null)
  function matchTerm(item, term) {
    let best = null;
    for (const word of [term].concat(SYNONYMS[term] || [])) {
      let found = null;
      if (item.nName === word) found = { score: 100 };
      else if (item.nName.startsWith(word)) found = { score: 80 };
      else if (item.nName.includes(word)) found = { score: 60 };
      else if (/^[ㄱ-ㅎ]+$/.test(word) && item.iName.includes(word)) found = { score: 55 };
      else if (item.nCategory === word || item.nMeal === word) found = { score: 40 };
      else {
        const i = item.nIngredients.findIndex(line => line.includes(word));
        if (i >= 0) found = { score: 30, snippet: item.ingredients[i] };
      }
      if (found && (!best || found.score > best.score)) best = found;
    }
    return best;
  }

  function passesFilters(item) {
    if (filters.meal && item.meal !== filters.meal) return false;
    if (filters.time && !(item.minutes && item.minutes <= Number(filters.time))) return false;
    if (filters.difficulty && item.difficulty !== filters.difficulty) return false;
    return true;
  }

  function render() {
    const query = input.value.trim();
    const terms = query.split(/\s+/).map(norm).filter(Boolean);
    const results = [];

    for (const item of items) {
      if (!passesFilters(item)) continue;
      let score = 0;
      let snippet = '';
      let ok = true;
      for (const term of terms) {
        const hit = matchTerm(item, term);
        if (!hit) { ok = false; break; }
        score += hit.score;
        if (hit.snippet && !snippet) snippet = hit.snippet;
      }
      if (ok) results.push({ item, score, snippet });
    }

    results.sort((a, b) => b.score - a.score || a.item.index - b.item.index);
    items.forEach(item => { item.li.hidden = true; });
    results.forEach(({ item, snippet }) => {
      item.snippet.textContent = snippet ? `재료: ${snippet}` : '';
      item.snippet.hidden = !snippet;
      item.li.hidden = false;
      list.append(item.li);   // 점수 순서대로 다시 줄 세움
    });

    const filtered = Boolean(filters.meal || filters.time || filters.difficulty);
    statusEl.textContent = query
      ? `'${query}' 검색 결과 ${results.length}개${filtered ? ' (고른 조건 안에서)' : ''}`
      : `${filtered ? '고른 조건에 맞는 ' : ''}레시피 ${results.length}개`;
    emptyEl.hidden = results.length > 0;
    resetBtn.hidden = !filtered;
    suggestEl.hidden = Boolean(query);   // 검색어를 넣으면 추천 검색어는 숨김
  }

  // 조건 때문에 결과가 없을 때 조건을 한 번에 풀기
  const resetBtn = document.getElementById('search-reset');
  function resetFilters() {
    Object.keys(filters).forEach(key => { filters[key] = ''; });
    chips.forEach(c => c.setAttribute('aria-pressed', !c.dataset.value));
    render();
  }
  resetBtn.addEventListener('click', resetFilters);

  // 주소에 검색어를 남겨서 새로고침하거나 공유해도 그대로 보이게
  function syncUrl() {
    const query = input.value.trim();
    history.replaceState(null, '', query ? `?q=${encodeURIComponent(query)}` : location.pathname);
  }

  // 통계: 입력을 멈춘 뒤 한 번만 남김
  let trackTimer = null;
  let lastTracked = '';
  function trackSearch(now) {
    clearTimeout(trackTimer);
    const query = input.value.trim();
    const send = () => {
      if (!query || query === lastTracked) return;
      lastTracked = query;
      if (window.track) window.track('search', { search_term: query });
    };
    if (now) send();
    else trackTimer = setTimeout(send, 1500);
  }

  input.addEventListener('input', () => {
    render();
    syncUrl();
    trackSearch(false);
  });

  form.addEventListener('submit', e => {
    e.preventDefault();
    render();
    syncUrl();
    trackSearch(true);
    input.blur();   // 휴대폰 키보드 내리기
  });

  chips.forEach(chip => chip.addEventListener('click', () => {
    const group = chip.dataset.filter;
    filters[group] = chip.dataset.value || '';
    chips.filter(c => c.dataset.filter === group).forEach(c => c.setAttribute('aria-pressed', c === chip));
    render();
    if (window.track) window.track('search_filter', { filter: group, value: chip.dataset.value || 'all' });
  }));

  document.querySelectorAll('.suggest-chip').forEach(btn => btn.addEventListener('click', () => {
    input.value = btn.dataset.q || '';
    render();
    syncUrl();
    trackSearch(true);
  }));

  list.addEventListener('click', e => {
    const link = e.target.closest('a');
    if (!link || !window.track) return;
    const li = link.closest('li');
    window.track('search_result_click', { menu_name: li ? li.dataset.name : '', search_term: input.value.trim() });
  });

  input.value = new URLSearchParams(location.search).get('q') || '';
  render();
  if (input.value) trackSearch(true);
})();
