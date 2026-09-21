// 두 페이지(index.html, board.html)가 함께 쓰는 코드
// Supabase 연결 · 로그인 · 다크/라이트 모드 · 작은 도우미 함수
// 불러오는 순서: supabase-js → config.js → theme.js → common.js → 각 페이지 스크립트


// ── Supabase 연결 ── 주소와 키는 config.js에 있음. 데이터 보호는 Supabase의 RLS 정책이 맡음

const config = window.APP_CONFIG || {};

// secret/service_role 키는 모든 권한을 우회하므로, 실수로 넣었더라도 쓰지 않음
function isSecretKey(key) {
  if (key.startsWith('sb_secret_')) return true;
  try {
    const payload = JSON.parse(atob(key.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')));
    return payload.role === 'service_role';
  } catch (e) {
    return false;
  }
}

const secretKeyUsed = isSecretKey(config.supabaseKey || '');
const db = window.supabase && config.supabaseUrl && config.supabaseKey && !secretKeyUsed
  ? window.supabase.createClient(config.supabaseUrl, config.supabaseKey)
  : null;

// 연결하지 못했을 때 화면에 보여줄 안내 (연결됐으면 null)
function connectionProblem() {
  if (db) return null;
  if (secretKeyUsed) return 'config.js에 secret 키가 들어 있어요. 공개(publishable) 키로 바꿔 주세요.';
  if (!config.supabaseKey) return 'config.js를 찾지 못했어요. index.html과 같은 폴더에 있는지 확인해 주세요.';
  return 'Supabase에 연결하지 못했어요. 인터넷 연결을 확인해 주세요.';
}


// ── 작은 도우미 ───────────────────────────────────────

const MEAL_ORDER = ['아침', '점심', '저녁'];
const MEAL_ICON = { 아침: 'sun', 점심: 'bowl', 저녁: 'moon' };

// 페이지의 <template id="icons">에서 아이콘을 복사해 옴
function icon(name) {
  const tpl = document.getElementById('icons');
  const svg = tpl && Array.from(tpl.content.children).find(el => el.dataset.icon === name);
  return svg ? svg.cloneNode(true) : document.createTextNode('');
}

function textEl(tag, className, text) {
  const el = document.createElement(tag);
  el.className = className;
  el.textContent = text;
  return el;
}

const relativeTime = new Intl.RelativeTimeFormat('ko', { numeric: 'auto' });

function timeAgo(iso) {
  const seconds = (new Date(iso) - Date.now()) / 1000;
  const abs = Math.abs(seconds);
  if (abs < 60) return '방금 전';
  if (abs < 3600) return relativeTime.format(Math.round(seconds / 60), 'minute');
  if (abs < 86400) return relativeTime.format(Math.round(seconds / 3600), 'hour');
  if (abs < 86400 * 7) return relativeTime.format(Math.round(seconds / 86400), 'day');
  return new Date(iso).toLocaleDateString('ko', { month: 'long', day: 'numeric' });
}


// 다크/라이트 모드 버튼은 theme.js에 있음


// ── 로그인 ────────────────────────────────────────────

let currentUser = null;   // 로그인한 사람 (없으면 null)
let authReady = false;
let notifyPending = false;
const userListeners = [];

// 로그인 상태가 처음 정해질 때, 그리고 바뀔 때마다 listener(currentUser)를 부름
function onUserChange(listener) {
  userListeners.push(listener);
  // 페이지 스크립트보다 로그인 확인이 먼저 끝났으면, 늦게 등록한 listener에게도 한 번 알려 줌
  if (authReady && !notifyPending) setTimeout(() => listener(currentUser), 0);
}

const accountEl = document.getElementById('account');
const authDialog = document.getElementById('auth-dialog');
const authForm = document.getElementById('auth-form');
const authNoteEl = document.getElementById('auth-note');
const authMessageEl = document.getElementById('auth-message');

const AUTH_ERRORS = {
  invalid_credentials: '이메일 또는 비밀번호가 맞지 않아요.',
  email_not_confirmed: '메일 인증을 먼저 끝내 주세요. 받은 메일의 링크를 누르면 돼요.',
  user_already_exists: '이미 가입된 이메일이에요. 로그인해 주세요.',
  weak_password: '비밀번호가 너무 쉬워요. 더 길게 정해 주세요.',
  over_email_send_rate_limit: '메일을 너무 자주 보냈어요. 잠시 뒤 다시 시도해 주세요.',
};

function openAuth(note) {
  authNoteEl.textContent = note || '로그인하면 추천 기록, 좋아요, 메뉴 건의함을 쓸 수 있어요냥.';
  authMessageEl.textContent = '';
  authDialog.showModal();
}

function renderAccount() {
  if (!db) return accountEl.replaceChildren();

  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'pill-btn';

  if (currentUser) {
    button.textContent = '로그아웃';
    button.addEventListener('click', () => db.auth.signOut());
    accountEl.replaceChildren(textEl('span', 'email', currentUser.email), button);
  } else {
    button.append(icon('user'), '로그인');
    button.addEventListener('click', () => openAuth());
    accountEl.replaceChildren(button);
  }
}

document.getElementById('auth-close').addEventListener('click', () => authDialog.close());

authForm.addEventListener('submit', async e => {
  e.preventDefault();
  if (!db) return;
  const mode = e.submitter && e.submitter.value === 'signup' ? 'signup' : 'login';
  const email = authForm.elements.email.value.trim();
  const password = authForm.elements.password.value;
  const buttons = authForm.querySelectorAll('.auth-actions button');

  // 만 14세 미만은 법정대리인 동의 없이 가입할 수 없어서, 가입할 때 나이를 확인받음
  if (mode === 'signup' && authForm.elements.age14 && !authForm.elements.age14.checked) {
    authMessageEl.textContent = '만 14세 이상만 가입할 수 있어요. 맞다면 "만 14세 이상이에요"에 체크해 주세요.';
    return;
  }

  buttons.forEach(b => { b.disabled = true; });
  authMessageEl.textContent = mode === 'signup' ? '가입하는 중…' : '로그인하는 중…';

  const { data, error } = mode === 'signup'
    ? await db.auth.signUp({ email, password })
    : await db.auth.signInWithPassword({ email, password });

  buttons.forEach(b => { b.disabled = false; });

  if (error) {
    authMessageEl.textContent = AUTH_ERRORS[error.code] || `오류: ${error.message}`;
    return;
  }
  // 가입·로그인 횟수만 통계에 남김 (이메일은 보내지 않음). track은 site.js에 있음
  if (window.track) window.track(mode === 'signup' ? 'sign_up' : 'login', { method: 'email' });
  if (mode === 'signup' && !data.session) {
    authMessageEl.textContent = '확인 메일을 보냈어요. 메일 속 링크를 누른 뒤, 여기서 로그인하세요.';
    return;
  }
  authForm.reset();
  authDialog.close();
});

renderAccount();

if (db) {
  db.auth.onAuthStateChange((event, session) => {
    const nextUser = session ? session.user : null;
    const changed = !authReady || (nextUser ? nextUser.id : null) !== (currentUser ? currentUser.id : null);
    currentUser = nextUser;
    authReady = true;
    if (!changed) return;
    renderAccount();
    // 이 콜백 안에서 바로 Supabase를 부르면 멈출 수 있어서 한 박자 뒤에 알림
    notifyPending = true;
    setTimeout(() => {
      notifyPending = false;
      userListeners.forEach(listener => listener(currentUser));
    }, 0);
  });
}
