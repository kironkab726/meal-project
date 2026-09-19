// 냉장고 털기: 고른 재료로 만들 수 있는 냥셰프 레시피를 찾아 줌
// 레시피별 "꼭 필요한 재료 / 있으면 좋은 재료" 데이터는 build-pages.ps1 이 tools/fridge.csv 를 읽어 페이지에 넣어 줌
//   need, nice           : 고를 수 있는 재료 (버튼이 있는 것)
//   needExtra, niceExtra : 버튼이 없는 재료 (춘장, 중화면처럼 따로 사야 하는 것)
(function () {
  const STORE_KEY = 'nyang-fridge';
  const data = JSON.parse(document.getElementById('fridge-data').textContent);
  const chips = Array.from(document.querySelectorAll('.fridge-chip'));
  const resultsEl = document.getElementById('fridge-results');
  const statusEl = document.getElementById('fridge-status');
  const resetBtn = document.getElementById('fridge-reset');
  const known = new Set(chips.map(c => c.dataset.key));

  // 고른 재료는 이 브라우저에만 기억해 둠 (다음에 와도 그대로)
  function load() {
    try {
      const saved = JSON.parse(localStorage.getItem(STORE_KEY) || '[]');
      return Array.isArray(saved) ? saved.filter(k => known.has(k)) : [];
    } catch (e) {
      return [];
    }
  }

  function save() {
    try { localStorage.setItem(STORE_KEY, JSON.stringify(Array.from(selected))); } catch (e) {}
  }

  const selected = new Set(load());

  function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text != null) node.textContent = text;
    return node;
  }

  // 고른 재료가 하나라도 들어가는 레시피만, 빠진 "꼭 필요한 재료"를 셈
  function evaluate(r) {
    const matched = r.need.concat(r.nice).filter(k => selected.has(k));
    if (!matched.length) return null;
    const missing = r.need.filter(k => !selected.has(k)).concat(r.needExtra);
    const main = r.need.filter(k => selected.has(k)).length;   // 고른 재료 중 주재료인 것
    return { r, matched, missing, main };
  }

  // 빠진 재료가 적은 것 → 고른 재료를 주재료로 쓰는 것 → 고른 재료를 많이 쓰는 것 → 빨리 되는 것 순서
  function byBest(a, b) {
    return a.missing.length - b.missing.length
      || b.main - a.main
      || b.matched.length - a.matched.length
      || (a.r.minutes || 999) - (b.r.minutes || 999);
  }

  const FIRST_SHOWN = 12;   // 목록이 길면 앞의 몇 개만 보여 주고 나머지는 접어 둠

  function labelled(className, label, list) {
    const line = el('span', className);
    line.append(el('strong', '', label), list.join(', '));
    return line;
  }

  function card(x, status) {
    const li = document.createElement('li');
    const a = el('a');
    a.href = `recipes/${x.r.id}.html`;
    a.addEventListener('click', () => {
      if (window.track) window.track('fridge_result_click', { menu_name: x.r.name, status });
    });
    const meta = [x.r.meal, x.r.category, x.r.minutes ? `${x.r.minutes}분` : '', x.r.difficulty].filter(Boolean).join(' · ');
    a.append(el('span', 'name', x.r.name), el('span', 'meta', meta), labelled('have', '있는 재료 ', x.matched));
    if (x.missing.length) a.append(labelled('need', '더 필요 ', x.missing));
    li.append(a);
    return li;
  }

  function list(items, status) {
    const ul = el('ul', 'fridge-list');
    ul.append(...items.map(x => card(x, status)));
    return ul;
  }

  function section(title, items, status) {
    const box = el('section', 'fridge-section');
    box.append(el('h2', '', title), list(items.slice(0, FIRST_SHOWN), status));
    if (items.length > FIRST_SHOWN) {
      const rest = el('details', 'fridge-more');
      rest.append(el('summary', '', `${items.length - FIRST_SHOWN}개 더 보기`), list(items.slice(FIRST_SHOWN), status));
      box.append(rest);
    }
    return box;
  }

  function render() {
    chips.forEach(c => c.setAttribute('aria-pressed', selected.has(c.dataset.key)));
    resetBtn.hidden = !selected.size;

    if (!selected.size) {
      resultsEl.replaceChildren(el('p', 'fridge-empty', '재료를 하나 이상 고르면 여기에 만들 수 있는 메뉴가 나와요.'));
      statusEl.textContent = '';
      return;
    }

    const all = data.recipes.map(evaluate).filter(Boolean).sort(byBest);
    const ready = all.filter(x => x.missing.length === 0);
    const almost = all.filter(x => x.missing.length >= 1 && x.missing.length <= 2);
    const more = all.filter(x => x.missing.length > 2);

    const parts = [];
    if (ready.length) parts.push(section(`지금 바로 만들 수 있어요 (${ready.length})`, ready, 'ready'));
    if (almost.length) parts.push(section(`한두 가지만 더 있으면 돼요 (${almost.length})`, almost, 'almost'));
    if (more.length) {
      const details = el('details', 'fridge-more');
      details.append(el('summary', '', `장을 조금 더 보면 만들 수 있어요 (${more.length})`), list(more, 'more'));
      parts.push(details);
    }
    if (!parts.length) parts.push(el('p', 'fridge-empty', '이 재료가 들어가는 냥셰프 레시피가 아직 없어요. 다른 재료도 골라 보세요.'));

    resultsEl.replaceChildren(...parts);
    statusEl.textContent = `고른 재료 ${selected.size}개 · 바로 만들 수 있는 메뉴 ${ready.length}개 · 한두 가지만 더 있으면 되는 메뉴 ${almost.length}개`;
  }

  chips.forEach(chip => chip.addEventListener('click', () => {
    const key = chip.dataset.key;
    const on = !selected.has(key);
    if (on) selected.add(key);
    else selected.delete(key);
    save();
    render();
    if (window.track) window.track('fridge_select', { ingredient: key, selected: on });
  }));

  resetBtn.addEventListener('click', () => {
    selected.clear();
    save();
    render();
    if (chips.length) chips[0].focus();
  });

  render();
})();
