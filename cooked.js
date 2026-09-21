// 요리 자랑 페이지 (cooked.html)
// - 모두의 요리: 공개로 올린 완성 요리 (로그인 없이 볼 수 있음)
// - 내 요리 기록: 내가 남긴 완성 요리 전부 (나만 보기로 저장한 것 포함)
// - 레시피 페이지와 도마의 "완성했다냥!" 버튼은 cooked.html?menu=메뉴번호 로 와서, 그 메뉴로 쓰기 창을 엶
// db, currentUser, openAuth, onUserChange, icon, textEl, timeAgo 는 common.js, track·toast 는 site.js
// 테이블과 권한은 supabase-cooks.sql

(function () {
  const PAGE_SIZE = 12;
  const BUCKET = 'cook-photos';
  const COLUMNS = 'id, user_id, menu_id, menu_name, photo_path, comment, is_public, created_at, profiles(nickname)';

  const $ = id => document.getElementById(id);
  const bubbleEl = $('hero-bubble');
  const tabsEl = $('cook-tabs');
  const summaryEl = $('mine-summary');
  const statsEl = $('mine-stats');
  const nicknameEl = $('mine-nickname');
  const statusEl = $('feed-status');
  const loginBtn = $('feed-login');
  const listEl = $('cook-list');
  const moreBtn = $('more-btn');
  const writeDialog = $('write-dialog');
  const writeForm = $('write-form');
  const menuSelect = $('write-menu');
  const photoInput = $('write-photo');
  const photoDrop = $('photo-drop');
  const photoPreview = $('photo-preview');
  const photoTools = $('photo-tools');
  const nicknameField = $('nickname-field');
  const writeMessage = $('write-message');
  const writeSubmit = $('write-submit');
  const photoDialog = $('photo-dialog');

  const params = new URLSearchParams(location.search);
  let tab = params.get('tab') === 'mine' ? 'mine' : 'all';
  let pendingMenuId = Number(params.get('menu')) || null;   // "완성했다냥!" 버튼으로 온 메뉴
  let wantWrite = Boolean(pendingMenuId);                    // 로그인이 끝나면 쓰기 창을 열지

  const feeds = { all: newFeed(), mine: newFeed() };
  let menus = [];                  // 고를 수 있는 메뉴 [{ id, meal, name }]
  let menusReady = null;
  let recipePages = new Set();     // 레시피 페이지가 있는 메뉴 번호
  let profile;                     // 내 닉네임: undefined = 아직 모름, null = 없음
  let reported = new Set();        // 내가 신고한 글 번호
  let photo = null;                // 쓰기 창에서 고른 사진 { full, small, url }

  function newFeed() { return { rows: [], done: false, loading: false, error: '' }; }

  function photoUrl(path, small) {
    const name = small ? path.replace(/\.jpg$/, '_s.jpg') : path;
    return db.storage.from(BUCKET).getPublicUrl(name).data.publicUrl;
  }

  function nicknameOf(row) {
    return (row.profiles && row.profiles.nickname) || '집사';
  }


  // ── 목록 그리기 ────────────────────────────────────────

  function actionButton(iconName, label, onClick) {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = 'icon-action';
    b.setAttribute('aria-label', label);
    b.title = label;
    b.append(icon(iconName));
    b.addEventListener('click', onClick);
    return b;
  }

  function cookCard(row) {
    const mine = Boolean(currentUser) && row.user_id === currentUser.id;
    const li = document.createElement('li');
    li.className = row.is_public ? 'cook-card' : 'cook-card private';

    if (row.photo_path) {
      const b = document.createElement('button');
      b.type = 'button';
      b.className = 'cook-photo';
      b.setAttribute('aria-label', `${row.menu_name} 사진 크게 보기`);
      const img = new Image();
      img.src = photoUrl(row.photo_path, true);
      img.alt = `${nicknameOf(row)}님이 만든 ${row.menu_name}`;
      img.loading = 'lazy';
      img.decoding = 'async';
      b.append(img);
      b.addEventListener('click', () => openPhoto(row));
      li.append(b);
    } else {
      const empty = document.createElement('div');
      empty.className = 'cook-nophoto';
      empty.append(icon('bowl'), '사진 없이 남긴 기록');
      li.append(empty);
    }

    const body = document.createElement('div');
    body.className = 'cook-body';
    let menuEl;
    if (row.menu_id && recipePages.has(row.menu_id)) {
      menuEl = document.createElement('a');
      menuEl.href = `recipes/${row.menu_id}.html`;
      menuEl.className = 'cook-menu';
      menuEl.textContent = row.menu_name;
    } else {
      menuEl = textEl('span', 'cook-menu', row.menu_name);
    }
    const meta = document.createElement('div');
    meta.className = 'cook-meta';
    meta.append(textEl('strong', '', nicknameOf(row)), textEl('span', '', timeAgo(row.created_at)));
    if (!row.is_public) {
      const badge = document.createElement('span');
      badge.className = 'private-badge';
      badge.append(icon('lock'), '나만 보기');
      meta.append(badge);
    }
    body.append(menuEl, meta);
    if (row.comment) body.append(textEl('p', 'cook-comment', row.comment));
    li.append(body);

    const foot = document.createElement('div');
    foot.className = 'cook-foot';
    if (mine) {
      foot.append(
        row.is_public
          ? actionButton('lock', '나만 보기로 바꾸기', () => setPublic(row, false))
          : actionButton('globe', '모두의 요리에 자랑하기', () => setPublic(row, true)),
        actionButton('trash', '이 기록 지우기', () => removeCook(row)),
      );
    } else {
      const done = reported.has(row.id);
      const b = actionButton('flag', done ? '신고했어요' : '신고하기', () => reportCook(row));
      b.disabled = done;
      foot.append(b);
    }
    li.append(foot);
    return li;
  }

  function render() {
    tabsEl.querySelectorAll('button').forEach(b => b.setAttribute('aria-pressed', b.dataset.tab === tab));
    const feed = feeds[tab];
    const needLogin = tab === 'mine' && !currentUser;

    summaryEl.hidden = tab !== 'mine' || !currentUser || !feed.rows.length;
    if (!summaryEl.hidden) {
      const kinds = new Set(feed.rows.map(r => r.menu_name)).size;
      statsEl.textContent = `지금까지 ${feed.rows.length}번 요리해서, ${kinds}가지 메뉴를 만들었다냥!`;
      nicknameEl.textContent = profile ? profile.nickname : '아직 없음';
    }

    listEl.replaceChildren(...(needLogin ? [] : feed.rows.map(cookCard)));
    loginBtn.hidden = !needLogin;
    moreBtn.hidden = needLogin || feed.done || feed.loading || !feed.rows.length;

    let status = '';
    if (!db) status = connectionProblem();
    else if (needLogin) status = '로그인하면 내가 만든 요리를 모아 볼 수 있다냥.';
    else if (feed.error) status = feed.error;
    else if (feed.loading && !feed.rows.length) status = '요리를 불러오는 중이에요…';
    else if (!feed.rows.length && feed.done) {
      status = tab === 'mine'
        ? '아직 남긴 요리가 없다냥. 레시피대로 만들고 "완성했다냥!"을 눌러 줘냥!'
        : '아직 자랑한 요리가 없다냥. 첫 번째 자랑을 올려 줘냥!';
    }
    statusEl.textContent = status;
  }

  async function loadMore() {
    const which = tab;
    const feed = feeds[which];
    if (!db || feed.loading || feed.done) return;
    if (which === 'mine' && !currentUser) return render();

    feed.loading = true;
    feed.error = '';
    render();

    let query = db.from('cooks').select(COLUMNS).order('created_at', { ascending: false });
    query = which === 'all'
      ? query.eq('is_public', true).range(feed.rows.length, feed.rows.length + PAGE_SIZE - 1)
      : query.eq('user_id', currentUser.id).limit(1000);   // 내 기록은 한 번에 (통계 때문에)
    const uid = currentUser ? currentUser.id : null;
    const { data, error } = await query;

    // 불러오는 사이에 로그인 계정이 바뀌었으면 버림
    if (which === 'mine' && (currentUser ? currentUser.id : null) !== uid) return;
    feed.loading = false;
    if (error) {
      console.error(error);
      feed.error = error.code === '42P01' || error.code === 'PGRST205'
        ? '요리 자랑은 아직 준비 중이에요. 조금만 기다려 달라냥!'
        : '요리를 불러오지 못했어요. 잠시 뒤 다시 시도해 주세요.';
    } else {
      const seen = new Set(feed.rows.map(r => r.id));
      feed.rows.push(...data.filter(r => !seen.has(r.id)));
      feed.done = which === 'mine' || data.length < PAGE_SIZE;
    }
    if (tab === which) render();
  }

  function switchTab(next) {
    tab = next;
    const url = new URL(location.href);
    if (tab === 'mine') url.searchParams.set('tab', 'mine');
    else url.searchParams.delete('tab');
    history.replaceState(null, '', url);
    render();
    if (!feeds[tab].rows.length) loadMore();
  }

  tabsEl.addEventListener('click', e => {
    const b = e.target.closest('button[data-tab]');
    if (b && b.dataset.tab !== tab) switchTab(b.dataset.tab);
  });
  moreBtn.addEventListener('click', loadMore);
  loginBtn.addEventListener('click', () => openAuth('로그인하면 내가 만든 요리를 모아 볼 수 있어요냥.'));

  // "3분 전" 같은 시간 표시를 1분마다 새로 고침
  setInterval(render, 60 * 1000);


  // ── 내 글 고치기 · 지우기 · 남의 글 신고 ────────────────

  function forEachCopy(id, fn) {
    Object.values(feeds).forEach(feed => feed.rows.forEach(r => { if (r.id === id) fn(r); }));
  }

  async function setPublic(row, isPublic) {
    const { error } = await db.from('cooks').update({ is_public: isPublic }).eq('id', row.id);
    if (error) {
      console.error(error);
      return alert('바꾸지 못했어요. 잠시 뒤 다시 시도해 주세요.');
    }
    forEachCopy(row.id, r => { r.is_public = isPublic; });
    // 모두의 요리는 처음부터 다시 불러와서 순서를 맞춤
    feeds.all = newFeed();
    if (tab === 'all') loadMore(); else render();
    toast(isPublic ? '모두의 요리에 올렸어요.' : '나만 보기로 바꿨어요.');
  }

  async function removeCook(row) {
    if (!confirm(`"${row.menu_name}" 기록을 지울까요? 지우면 되돌릴 수 없어요.`)) return;
    const { error } = await db.from('cooks').delete().eq('id', row.id);
    if (error) {
      console.error(error);
      return alert('지우지 못했어요. 잠시 뒤 다시 시도해 주세요.');
    }
    if (row.photo_path) {
      const files = [row.photo_path, row.photo_path.replace(/\.jpg$/, '_s.jpg')];
      const { error: storageError } = await db.storage.from(BUCKET).remove(files);
      if (storageError) console.error(storageError);
    }
    Object.values(feeds).forEach(feed => { feed.rows = feed.rows.filter(r => r.id !== row.id); });
    render();
    toast('기록을 지웠어요.');
  }

  async function reportCook(row) {
    if (!currentUser) return openAuth('로그인하면 신고할 수 있어요냥.');
    if (!confirm('이 글을 신고할까요? 서로 다른 집사 3명이 신고하면 자동으로 가려져요.')) return;
    const { error } = await db.from('cook_reports').insert({ cook_id: row.id, user_id: currentUser.id });
    if (error && error.code !== '23505') {   // 23505 = 이미 신고함
      console.error(error);
      return alert('신고하지 못했어요. 잠시 뒤 다시 시도해 주세요.');
    }
    reported.add(row.id);
    render();
    toast('신고했어요. 알려 줘서 고마워요.');
    track('report_cook', { menu_name: row.menu_name });
  }

  $('rename-btn').addEventListener('click', async () => {
    if (!currentUser) return;
    const next = (prompt('새 닉네임 (한글·영문·숫자 2~12자, 띄어쓰기 없이)', profile ? profile.nickname : '') || '').trim();
    if (!next || (profile && next === profile.nickname)) return;
    const problem = nicknameProblem(next);
    if (problem) return alert(problem);
    const { data, error } = profile
      ? await db.from('profiles').update({ nickname: next }).eq('user_id', currentUser.id).select('nickname').single()
      : await db.from('profiles').insert({ user_id: currentUser.id, nickname: next }).select('nickname').single();
    if (error) {
      console.error(error);
      return alert(error.code === '23505' ? '이미 다른 집사가 쓰는 닉네임이에요.' : '닉네임을 바꾸지 못했어요.');
    }
    profile = data;
    forEachCopyOfUser(currentUser.id, r => { r.profiles = { nickname: data.nickname }; });
    render();
    toast('닉네임을 바꿨어요.');
  });

  function forEachCopyOfUser(userId, fn) {
    Object.values(feeds).forEach(feed => feed.rows.forEach(r => { if (r.user_id === userId) fn(r); }));
  }


  // ── 사진 크게 보기 ─────────────────────────────────────

  function openPhoto(row) {
    $('photo-full').src = photoUrl(row.photo_path, false);
    $('photo-full').alt = `${nicknameOf(row)}님이 만든 ${row.menu_name}`;
    $('photo-menu').textContent = row.menu_name;
    $('photo-meta').textContent = `${nicknameOf(row)} · ${timeAgo(row.created_at)}`;
    $('photo-comment').textContent = row.comment || '';
    photoDialog.showModal();
  }
  $('photo-close').addEventListener('click', () => photoDialog.close());
  photoDialog.addEventListener('click', e => { if (e.target === photoDialog) photoDialog.close(); });
  photoDialog.addEventListener('close', () => { $('photo-full').removeAttribute('src'); });


  // ── 쓰기 창 ───────────────────────────────────────────

  function nicknameProblem(name) {
    if (!/^[가-힣A-Za-z0-9_]{2,12}$/.test(name)) return '닉네임은 한글·영문·숫자로 2~12자, 띄어쓰기 없이 적어 주세요.';
    return '';
  }

  function loadMenus() {
    if (!menusReady) {
      menusReady = db.from('menus').select('id, meal, name').order('id')
        .then(({ data, error }) => {
          if (error) throw error;
          menus = data;
          const groups = MEAL_ORDER.map(meal => {
            const group = document.createElement('optgroup');
            group.label = meal;
            data.filter(m => m.meal === meal)
              .sort((a, b) => a.name.localeCompare(b.name, 'ko'))
              .forEach(m => group.append(new Option(m.name, m.id)));
            return group;
          }).filter(g => g.children.length);
          menuSelect.replaceChildren(new Option('메뉴를 골라 주세요', ''), ...groups);
        })
        .catch(err => {
          console.error(err);
          menusReady = null;
          menuSelect.replaceChildren(new Option('메뉴를 불러오지 못했어요', ''));
        });
    }
    return menusReady;
  }

  async function loadProfile() {
    const uid = currentUser.id;
    const { data, error } = await db.from('profiles').select('nickname').eq('user_id', uid).maybeSingle();
    if (!currentUser || currentUser.id !== uid) return;
    if (error) console.error(error);
    profile = error ? undefined : data;   // 오류면 모르는 상태로 둠
    render();
  }

  async function loadReports() {
    const { data, error } = await db.from('cook_reports').select('cook_id');
    if (error) return console.error(error);
    reported = new Set(data.map(r => r.cook_id));
    render();
  }

  function clearPhoto() {
    if (photo) URL.revokeObjectURL(photo.url);
    photo = null;
    photoInput.value = '';
    photoPreview.hidden = true;
    photoPreview.removeAttribute('src');
    photoTools.hidden = true;
    photoDrop.hidden = false;
  }

  async function openWrite(menuId) {
    if (!db) return alert(connectionProblem());
    if (!currentUser) {
      wantWrite = true;
      if (menuId) pendingMenuId = menuId;
      return openAuth('로그인하면 완성한 요리를 기록하고 자랑할 수 있어요냥.');
    }
    wantWrite = false;
    writeMessage.textContent = '';
    if (!writeDialog.open) writeDialog.showModal();
    if (profile === undefined) await loadProfile();
    showNicknameField();
    await loadMenus();
    if (menuId && menus.some(m => m.id === menuId)) menuSelect.value = String(menuId);
  }

  // 닉네임이 아직 없을 때만 쓰기 창에서 물어봄
  function showNicknameField() {
    nicknameField.hidden = profile !== null;
    writeForm.elements.nickname.required = profile === null;
  }

  function closeWrite() {
    writeDialog.close();
  }

  writeDialog.addEventListener('close', () => {
    // "완성했다냥!"으로 왔던 메뉴 번호는 한 번 쓰면 주소에서 뺌
    if (pendingMenuId) {
      pendingMenuId = null;
      const url = new URL(location.href);
      url.searchParams.delete('menu');
      history.replaceState(null, '', url);
    }
  });
  writeDialog.addEventListener('click', e => { if (e.target === writeDialog) closeWrite(); });
  $('write-close').addEventListener('click', closeWrite);
  $('write-cancel').addEventListener('click', closeWrite);
  $('write-open').addEventListener('click', () => openWrite(pendingMenuId));
  $('photo-remove').addEventListener('click', clearPhoto);

  // 사진을 브라우저에서 줄여서 JPEG로 다시 만듦 (찍은 위치 같은 사진 속 정보는 이때 빠짐)
  function toJpeg(img, maxSide, quality) {
    const scale = Math.min(1, maxSide / Math.max(img.naturalWidth, img.naturalHeight));
    const canvas = document.createElement('canvas');
    canvas.width = Math.max(1, Math.round(img.naturalWidth * scale));
    canvas.height = Math.max(1, Math.round(img.naturalHeight * scale));
    const ctx = canvas.getContext('2d');
    ctx.fillStyle = '#FFFFFF';   // 투명한 PNG도 흰 바탕으로
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
    return new Promise((resolve, reject) => {
      canvas.toBlob(blob => (blob ? resolve(blob) : reject(new Error('사진 변환 실패'))), 'image/jpeg', quality);
    });
  }

  async function preparePhoto(file) {
    const url = URL.createObjectURL(file);
    try {
      const img = new Image();
      img.src = url;
      await img.decode();
      let full = await toJpeg(img, 1280, 0.82);
      if (full.size > 900 * 1024) full = await toJpeg(img, 1024, 0.72);   // 저장소 한도(1MB) 안으로
      const small = await toJpeg(img, 480, 0.75);
      return { full, small, url };
    } catch (err) {
      URL.revokeObjectURL(url);
      throw err;
    }
  }

  photoInput.addEventListener('change', async () => {
    const file = photoInput.files && photoInput.files[0];
    if (!file) return;
    writeMessage.textContent = '사진을 준비하는 중…';
    try {
      const next = await preparePhoto(file);
      clearPhoto();
      photo = next;
      photoPreview.src = photo.url;
      photoPreview.hidden = false;
      photoTools.hidden = false;
      photoDrop.hidden = true;
      writeMessage.textContent = '';
    } catch (err) {
      console.error(err);
      photoInput.value = '';
      writeMessage.textContent = '이 사진은 읽지 못했어요. JPG나 PNG 사진으로 골라 주세요.';
    }
  });

  async function uploadPhoto() {
    const base = `${currentUser.id}/${crypto.randomUUID()}`;
    const options = { contentType: 'image/jpeg', cacheControl: '31536000', upsert: false };
    const bucket = db.storage.from(BUCKET);
    const first = await bucket.upload(`${base}.jpg`, photo.full, options);
    if (first.error) throw first.error;
    const second = await bucket.upload(`${base}_s.jpg`, photo.small, options);
    if (second.error) {
      await bucket.remove([`${base}.jpg`]);
      throw second.error;
    }
    return `${base}.jpg`;
  }

  writeForm.addEventListener('submit', async e => {
    e.preventDefault();
    if (!currentUser) return openWrite(pendingMenuId);

    const menu = menus.find(m => String(m.id) === menuSelect.value);
    if (!menu) {
      writeMessage.textContent = '만든 요리를 골라 주세요냥.';
      return;
    }
    const comment = writeForm.elements.comment.value.trim().replace(/\s+/g, ' ');
    const isPublic = writeForm.elements.public.checked;

    writeSubmit.disabled = true;
    try {
      // 1) 닉네임이 없으면 먼저 만들기
      if (profile === undefined) await loadProfile();
      if (profile === undefined) {
        writeMessage.textContent = '닉네임을 확인하지 못했어요. 잠시 뒤 다시 시도해 주세요.';
        return;
      }
      if (profile === null && nicknameField.hidden) {
        showNicknameField();
        writeMessage.textContent = '자랑 글에 보일 닉네임을 정해 주세요냥.';
        return;
      }
      if (profile === null) {
        const name = writeForm.elements.nickname.value.trim();
        const problem = nicknameProblem(name);
        if (problem) {
          writeMessage.textContent = problem;
          return;
        }
        writeMessage.textContent = '닉네임을 정하는 중…';
        const { data, error } = await db.from('profiles')
          .insert({ user_id: currentUser.id, nickname: name }).select('nickname').single();
        if (error) {
          console.error(error);
          writeMessage.textContent = error.code === '23505'
            ? '이미 다른 집사가 쓰는 닉네임이에요. 다른 이름으로 골라 주세요.'
            : '닉네임을 저장하지 못했어요. 잠시 뒤 다시 시도해 주세요.';
          return;
        }
        profile = data;
        showNicknameField();
      }

      // 2) 사진 올리기
      let photoPath = null;
      if (photo) {
        writeMessage.textContent = '사진을 올리는 중…';
        try {
          photoPath = await uploadPhoto();
        } catch (err) {
          console.error(err);
          writeMessage.textContent = '사진을 올리지 못했어요. 잠시 뒤 다시 시도하거나 사진 없이 저장해 주세요.';
          return;
        }
      }

      // 3) 기록 저장
      writeMessage.textContent = '저장하는 중…';
      const { data, error } = await db.from('cooks')
        .insert({ user_id: currentUser.id, menu_id: menu.id, menu_name: menu.name, photo_path: photoPath, comment: comment || null, is_public: isPublic })
        .select(COLUMNS)
        .single();
      if (error) {
        console.error(error);
        if (photoPath) await db.storage.from(BUCKET).remove([photoPath, photoPath.replace(/\.jpg$/, '_s.jpg')]);
        writeMessage.textContent = '저장하지 못했어요. 잠시 뒤 다시 시도해 주세요.';
        return;
      }

      // 4) 화면에 바로 보여 주기
      feeds.mine.rows.unshift(data);
      if (isPublic) feeds.all.rows.unshift({ ...data });
      writeForm.reset();
      clearPhoto();
      closeWrite();
      if (!isPublic && tab === 'all') switchTab('mine'); else render();
      window.scrollTo({ top: listEl.getBoundingClientRect().top + window.scrollY - 120, behavior: 'smooth' });
      bubbleEl.textContent = `${data.menu_name} 완성 축하한다냥!`;
      toast(isPublic ? '완성한 요리를 자랑했어요!' : '내 요리 기록에 남겼어요!');
      track('cook_done', { menu_name: data.menu_name, is_public: isPublic, has_photo: Boolean(photoPath) });
    } finally {
      writeSubmit.disabled = false;
    }
  });


  // ── 시작 ──────────────────────────────────────────────

  fetch('recipes/pages.json')
    .then(res => (res.ok ? res.json() : []))
    .then(ids => { recipePages = new Set(Array.isArray(ids) ? ids : []); render(); })
    .catch(() => {});

  onUserChange(user => {
    feeds.mine = newFeed();
    profile = undefined;
    reported = new Set();
    render();
    if (!user) {
      if (writeDialog.open) closeWrite();
      // 로그인 안 한 채로 "완성했다냥!"을 눌러 왔으면 로그인 창부터
      if (wantWrite && db) openWrite(pendingMenuId);
      return;
    }
    loadProfile().then(() => { if (wantWrite) openWrite(pendingMenuId); });
    loadReports();
    if (tab === 'mine') loadMore();
  });

  render();
  if (db) {
    loadMore();
    loadMenus();
  }
})();
