// 냥빵이 숏폼 만들기 (studio.html)
// 캔버스에 11초짜리 세로 영상(1080x1920)을 그리고, 브라우저의 동영상 인코더(WebCodecs)로 MP4를 만듦
//   0.0~1.8초  냥빵이 등장 + "오늘 점심 뭐 먹지?"
//   1.8~5.8초  메뉴 룰렛 (점점 느려지다 멈춤)
//   5.8~9.6초  고른 메뉴 공개: 음식 사진 + 이름 + 웃는 냥빵이
//   9.6~11.2초 마무리: "레시피는 프로필 링크에서!"
// 냥빵이 그림은 index.html 의 .chef-cat 과 같은 좌표(400 칸)를 Path2D 로 그림

(function () {
  'use strict';

  const W = 1080, H = 1920, FPS = 30, DURATION = 11.2;
  const S2 = 1.8, S3 = 5.8, S4 = 9.6;   // 장면이 바뀌는 시각(초)
  const MEALS = ['아침', '점심', '저녁'];
  const COLOR = {
    bg: '#FBF3E4', paper: '#FFFBF3', ink: '#4A3426', muted: '#7A6352', accent: '#B8552F',
    plate: '#F6E6CB', ring: '#E6D0AC', chip: '#F3E6CF', doodle: '#E4CFAD', star: '#F2C46D',
    crust: '#C8733A', crumb: '#FFE9C2', blush: '#F4A28C', nose: '#E7837A',
  };
  const JUA = 'Jua, sans-serif', GAEGU = 'Gaegu, cursive', BODY = '"Gowun Dodum", sans-serif';

  const $ = id => document.getElementById(id);
  const canvas = $('canvas');
  const ctx = canvas.getContext('2d');
  const mealTabs = $('meal-tabs');
  const menuSelect = $('menu-select');
  const previewBtn = $('preview-btn');
  const makeBtn = $('make-btn');
  const statusEl = $('status');
  const progressBar = $('progress-bar');
  const resultEl = $('result');
  const resultVideo = $('result-video');
  const downloadLink = $('download-link');
  const shareBtn = $('share-btn');

  let menus = [];
  let credits = {};
  let meal = defaultMeal();
  let plan = null;          // 지금 그리는 영상의 내용 { menu, photo, credit, times, names }
  let raf = 0;
  let resultFile = null;
  const photoCache = new Map();

  function defaultMeal() {
    const h = new Date().getHours();
    return h < 10 ? '아침' : h < 15 ? '점심' : '저녁';
  }


  // ── 작은 도우미 ────────────────────────────────────────

  const clamp = (v, lo = 0, hi = 1) => Math.min(hi, Math.max(lo, v));
  const prog = (t, start, dur) => clamp((t - start) / dur);
  const lerp = (a, b, p) => a + (b - a) * p;
  const easeOut = x => 1 - Math.pow(1 - x, 3);
  const easeInOut = x => (x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2);
  const easeBack = x => { const c1 = 1.70158, c3 = c1 + 1; return 1 + c3 * Math.pow(x - 1, 3) + c1 * Math.pow(x - 1, 2); };

  function hasBatchim(word) {
    const code = word.charCodeAt(word.length - 1) - 0xAC00;
    return code >= 0 && code <= 11171 && code % 28 !== 0;
  }

  function roundRect(x, y, w, h, r) {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }

  // 글자가 maxW 보다 넓으면 글자 크기를 줄여서 맞춤
  function fitFont(text, maxW, size, family, weight) {
    let s = size;
    for (;;) {
      ctx.font = `${weight || ''} ${s}px ${family}`;
      if (ctx.measureText(text).width <= maxW || s <= 20) return s;
      s -= 4;
    }
  }

  function centerText(text, y, size, family, color, opts) {
    const o = opts || {};
    fitFont(text, o.maxW || W - 120, size, family, o.weight);
    ctx.fillStyle = color;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'alphabetic';
    ctx.fillText(text, o.x || W / 2, y);
  }

  // 가운데(cx, cy)를 기준으로 s 배 키워서 draw() 를 그림 (톡 튀어나오는 효과)
  function popAt(cx, cy, s, alpha, draw) {
    if (alpha <= 0) return;
    ctx.save();
    ctx.globalAlpha *= clamp(alpha);
    ctx.translate(cx, cy);
    ctx.scale(s, s);
    ctx.translate(-cx, -cy);
    draw();
    ctx.restore();
  }


  // ── 배경 · 소품 ───────────────────────────────────────

  function gingham(x, y, w, h, cell) {
    ctx.save();
    ctx.beginPath();
    ctx.rect(x, y, w, h);
    ctx.clip();
    ctx.fillStyle = COLOR.bg;
    ctx.fillRect(x, y, w, h);
    ctx.fillStyle = 'rgba(184, 85, 47, 0.28)';
    for (let cx = x; cx < x + w; cx += cell) ctx.fillRect(cx, y, cell / 2, h);
    for (let cy = y; cy < y + h; cy += cell) ctx.fillRect(x, cy, w, cell / 2);
    ctx.restore();
  }

  function paw(cx, cy, size, deg) {
    ctx.save();
    ctx.translate(cx, cy);
    ctx.rotate(deg * Math.PI / 180);
    ctx.scale(size / 48, size / 48);
    ctx.translate(-24, -24);
    ctx.fillStyle = COLOR.doodle;
    ctx.beginPath();
    ctx.ellipse(24, 32, 10, 8, 0, 0, Math.PI * 2);
    ctx.fill();
    for (const [x, y] of [[11, 19], [19, 11], [29, 11], [37, 19]]) {
      ctx.beginPath();
      ctx.arc(x, y, 4, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }

  function plate(cx, cy, r, alpha) {
    if (alpha <= 0) return;
    ctx.save();
    ctx.globalAlpha = alpha;
    ctx.fillStyle = COLOR.plate;
    ctx.beginPath();
    ctx.arc(cx, cy, r, 0, Math.PI * 2);
    ctx.fill();
    ctx.setLineDash([r * 0.09, r * 0.06]);
    ctx.lineWidth = Math.max(3, r / 40);
    ctx.strokeStyle = COLOR.ring;
    ctx.beginPath();
    ctx.arc(cx, cy, r * 0.87, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
  }

  function tape(x, y, w, h, deg) {
    ctx.save();
    ctx.translate(x + w / 2, y + h / 2);
    ctx.rotate(deg * Math.PI / 180);
    ctx.fillStyle = 'rgba(242, 196, 109, 0.85)';
    ctx.fillRect(-w / 2, -h / 2, w, h);
    ctx.restore();
  }

  function star(cx, cy, r, color) {
    ctx.save();
    ctx.translate(cx, cy);
    ctx.fillStyle = color || COLOR.star;
    ctx.beginPath();
    ctx.moveTo(0, -r);
    ctx.quadraticCurveTo(0, 0, r, 0);
    ctx.quadraticCurveTo(0, 0, 0, r);
    ctx.quadraticCurveTo(0, 0, -r, 0);
    ctx.quadraticCurveTo(0, 0, 0, -r);
    ctx.fill();
    ctx.restore();
  }

  // 말풍선: (cx, cy)가 가운데, 꼬리 끝은 (tailX, tailY). p = 나타난 정도(0~1)
  function bubble(text, cx, cy, tailX, tailY, p) {
    if (p <= 0) return;
    const size = fitFont(text, 760, 60, GAEGU, '700');
    const w = ctx.measureText(text).width + 84;
    const h = size + 52;
    const x = cx - w / 2, y = cy - h / 2;
    popAt(cx, cy, lerp(0.6, 1, easeBack(p)), p * 2, () => {
      ctx.lineWidth = 7;
      ctx.strokeStyle = COLOR.ink;
      ctx.fillStyle = COLOR.paper;
      roundRect(x, y, w, h, h / 2);
      ctx.fill();
      ctx.stroke();
      // 꼬리: 상자 아래쪽에서 tailX 쪽으로
      const bx = clamp(tailX, x + h / 2 + 10, x + w - h / 2 - 10);
      const bottom = y + h;
      ctx.beginPath();
      ctx.moveTo(bx - 22, bottom - 9);
      ctx.lineTo(tailX, tailY);
      ctx.lineTo(bx + 22, bottom - 9);
      ctx.closePath();
      ctx.fill();
      ctx.beginPath();
      ctx.moveTo(bx - 22, bottom - 1);
      ctx.lineTo(tailX, tailY);
      ctx.lineTo(bx + 22, bottom - 1);
      ctx.stroke();
      ctx.fillStyle = COLOR.ink;
      ctx.font = `700 ${size}px ${GAEGU}`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(text, cx, cy + 2);
    });
  }


  // ── 냥빵이 (index.html 의 .chef-cat 과 같은 모양) ────────

  const P = Object.fromEntries(Object.entries({
    tail: 'M282 386 C340 394 372 362 362 322 C356 300 340 294 332 306',
    earL: 'M104 128 L112 44 L178 92 Z',
    earInL: 'M120 114 L124 66 L160 94 Z',
    earR: 'M296 128 L288 44 L222 92 Z',
    earInR: 'M280 114 L276 66 L240 94 Z',
    crust: 'M90 392 L90 214 C52 206 44 130 100 112 C140 70 260 70 300 112 C356 130 348 206 310 214 L310 392 Q310 404 298 404 L102 404 Q90 404 90 392 Z',
    stripes: 'M68 156 L86 162 M68 178 L88 180 M332 156 L314 162 M332 178 L312 180',
    crumb: 'M108 384 L108 204 C74 196 66 142 114 128 C150 94 250 94 286 128 C334 142 326 196 292 204 L292 384 Q292 390 286 390 L114 390 Q108 390 108 384 Z',
    toes: 'M152 384 L152 395 M168 384 L168 395 M232 384 L232 395 M248 384 L248 395',
    pleats: 'M186 64 L186 82 M200 62 L200 82 M214 64 L214 82',
    nose: 'M191 250 Q200 246 209 250 L200 259 Z',
    mouth: 'M200 259 Q196 270 186 268 M200 259 Q204 270 214 268',
    whiskers: 'M122 248 L82 242 M122 260 L84 264 M278 248 L318 242 M278 260 L316 264',
    blink: 'M143 232 L161 232 M239 232 L257 232',
    likeEyes: 'M138 236 Q152 220 166 236 M234 236 Q248 220 262 236',
    likeMouth: 'M186 262 Q200 286 214 262 Z',
    whiskersUp: 'M122 246 L84 236 M122 258 L84 258 M278 246 L316 236 M278 258 L316 258',
  }).map(([k, d]) => [k, new Path2D(d)]));

  function fillP(p, color) { ctx.fillStyle = color; ctx.fill(p); }
  function strokeP(p, color, width) { ctx.strokeStyle = color; ctx.lineWidth = width; ctx.stroke(p); }
  function dot(x, y, rx, ry, color) { ctx.fillStyle = color; ctx.beginPath(); ctx.ellipse(x, y, rx, ry, 0, 0, Math.PI * 2); ctx.fill(); }

  // 그림의 (10, 10)을 (x, y)에 두고 s 배로. mood: 'default' | 'like'
  function drawCat(x, y, s, mood, t) {
    const bob = Math.sin(t * 2.4) * 5;   // 숨 쉬듯 살짝 오르내림
    ctx.save();
    ctx.translate(x, y);
    ctx.scale(s, s);
    ctx.translate(-10, -10 + bob);
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';

    ctx.save();   // 꼬리 살랑살랑
    ctx.translate(296, 386);
    ctx.rotate(Math.sin(t * 3.1) * 0.07);
    ctx.translate(-296, -386);
    strokeP(P.tail, COLOR.crust, 24);
    ctx.restore();

    for (const [ear, inner] of [[P.earL, P.earInL], [P.earR, P.earInR]]) {
      fillP(ear, COLOR.crust);
      strokeP(ear, COLOR.crust, 10);
      fillP(inner, COLOR.blush);
    }
    fillP(P.crust, COLOR.crust);
    strokeP(P.stripes, '#A85A28', 7);
    fillP(P.crumb, COLOR.crumb);
    dot(160, 392, 30, 17, '#E49A5A');
    dot(240, 392, 30, 17, '#E49A5A');
    strokeP(P.toes, '#B8672F', 4);

    ctx.save();   // 셰프 모자 (-8도)
    ctx.translate(200, 84);
    ctx.rotate(-8 * Math.PI / 180);
    ctx.translate(-200, -84);
    dot(176, 52, 20, 20, '#FFFFFF');
    dot(224, 52, 20, 20, '#FFFFFF');
    dot(200, 40, 24, 24, '#FFFFFF');
    roundRect(170, 54, 60, 36, 8);
    ctx.fillStyle = '#FFFFFF';
    ctx.fill();
    strokeP(P.pleats, '#E6DCCD', 4);
    ctx.restore();

    ctx.globalAlpha = 0.9;
    dot(136, 262, mood === 'like' ? 20 : 17, mood === 'like' ? 11 : 10, COLOR.blush);
    dot(264, 262, mood === 'like' ? 20 : 17, mood === 'like' ? 11 : 10, COLOR.blush);
    ctx.globalAlpha = 1;
    fillP(P.nose, COLOR.nose);

    if (mood === 'like') {
      strokeP(P.likeEyes, COLOR.ink, 5);
      fillP(P.likeMouth, '#9C4A3A');
      strokeP(P.likeMouth, COLOR.ink, 5);
      dot(200, 270, 7, 3.5, COLOR.blush);
      strokeP(P.whiskersUp, COLOR.ink, 3.5);
      const twinkle = 0.75 + 0.25 * Math.sin(t * 7);
      star(62, 84, 15 * twinkle);
      star(340, 80, 13 * (1.5 - twinkle));
    } else {
      if (t % 3.2 < 0.13) {   // 가끔 눈 깜빡
        strokeP(P.blink, COLOR.ink, 5);
      } else {
        dot(152, 232, 9, 11, COLOR.ink);
        dot(248, 232, 9, 11, COLOR.ink);
        dot(155, 228, 3, 3, '#FFFFFF');
        dot(251, 228, 3, 3, '#FFFFFF');
      }
      strokeP(P.mouth, COLOR.ink, 5);
      strokeP(P.whiskers, COLOR.ink, 3.5);
    }
    ctx.restore();
  }


  // ── 장면 그리기 ───────────────────────────────────────

  // 냥빵이 자리: 장면마다 [x, y, 배율], 접시 [가운데 x, y, 반지름]
  const CAT_AT = [
    { x: 264, y: 770, s: 1.45, plate: [540, 1090, 340] },
    { x: 340, y: 1010, s: 1.05, plate: [540, 1240, 250] },
    { x: 36, y: 1400, s: 0.78, plate: [184, 1560, 170] },
  ];

  function catLayout(t) {
    const a = t < S3 ? CAT_AT[0] : CAT_AT[1];
    const b = t < S3 ? CAT_AT[1] : CAT_AT[2];
    const p = easeInOut(prog(t, t < S3 ? S2 : S3, 0.45));
    const mix = (u, v) => lerp(u, v, p);
    return {
      x: mix(a.x, b.x), y: mix(a.y, b.y), s: mix(a.s, b.s),
      plate: [mix(a.plate[0], b.plate[0]), mix(a.plate[1], b.plate[1]), mix(a.plate[2], b.plate[2])],
    };
  }

  function drawBackground() {
    ctx.fillStyle = COLOR.bg;
    ctx.fillRect(0, 0, W, H);
    gingham(0, 0, W, 44, 44);
    paw(110, 470, 70, -18);
    paw(985, 580, 60, 16);
    paw(930, 230, 50, 20);
    paw(120, 1250, 56, 10);
    paw(985, 1560, 64, -12);
    centerText('냥빵이의 오늘은 뭐 먹지', 132, 50, JUA, COLOR.ink);
  }

  function nameAt(t) {
    let i = -1;
    while (i + 1 < plan.times.length && plan.times[i + 1] <= t) i++;
    return { i, name: i >= 0 ? plan.names[i] : '?', since: i >= 0 ? t - plan.times[i] : t - S2 };
  }

  function drawRoulette(t) {
    const p = prog(t, S2, 0.35);
    const x = 90, y = 470, w = 900, h = 380;
    // 공개 장면으로 넘어가면 위로 빠지며 사라짐
    const leave = easeInOut(prog(t, S3, 0.35));
    if (leave >= 1) return;
    ctx.save();
    ctx.globalAlpha = 1 - leave;
    ctx.translate(0, -leave * 120);
    popAt(W / 2, y + h / 2, lerp(0.7, 1, easeBack(p)), p * 2, () => {
      const cur = nameAt(t);
      const landed = cur.i === plan.times.length - 1;
      ctx.fillStyle = COLOR.paper;
      roundRect(x, y, w, h, 40);
      ctx.fill();
      ctx.lineWidth = 8;
      ctx.strokeStyle = landed ? COLOR.accent : COLOR.ink;
      ctx.stroke();
      tape(x + 80, y - 22, 150, 44, -7);
      tape(x + w - 230, y - 22, 150, 44, 6);
      centerText('냥빵이의 메뉴 룰렛', y + 84, 42, JUA, COLOR.muted);
      // 이름 칸: 새 이름이 아래에서 스르륵 올라옴
      ctx.save();
      ctx.beginPath();
      ctx.rect(x + 30, y + 110, w - 60, h - 130);
      ctx.clip();
      const slide = (1 - easeOut(clamp(cur.since / 0.09))) * 150;
      centerText(cur.name, y + 290 + slide, 130, JUA, landed ? COLOR.accent : COLOR.ink, { maxW: w - 100 });
      ctx.restore();
      if (landed) {
        const glow = easeOut(clamp(cur.since / 0.3));
        star(x + 40, y + 40, 34 * glow);
        star(x + w - 36, y + h - 44, 28 * glow);
      }
    });
    ctx.restore();
  }

  function drawPhotoCard(t) {
    const p = prog(t, S3, 0.5);
    if (p <= 0) return;
    const x = 90, y = 400, w = 900, h = 580;
    popAt(W / 2, y + h / 2, lerp(0.8, 1, easeBack(p)), p * 2.5, () => {
      ctx.save();
      roundRect(x, y, w, h, 32);
      ctx.clip();
      if (plan.photo) {
        const img = plan.photo;
        const scale = Math.max(w / img.width, h / img.height);
        const dw = img.width * scale, dh = img.height * scale;
        ctx.drawImage(img, x + (w - dw) / 2, y + (h - dh) / 2, dw, dh);
      } else {
        ctx.fillStyle = '#F7E7C6';
        ctx.fillRect(x, y, w, h);
        centerText(plan.menu.name, y + h / 2 + 30, 90, JUA, COLOR.muted, { maxW: w - 80 });
      }
      ctx.restore();
      ctx.lineWidth = 8;
      ctx.strokeStyle = COLOR.ink;
      roundRect(x, y, w, h, 32);
      ctx.stroke();
      tape(x + 80, y - 22, 150, 44, -7);
      tape(x + w - 230, y - 22, 150, 44, 6);
      const twinkle = 0.8 + 0.2 * Math.sin(t * 6);
      star(x - 10, y + 60, 34 * twinkle);
      star(x + w + 8, y + h - 70, 30 * (1.6 - twinkle));
    });
    // 사진 출처 (위키미디어 라이선스: 작가와 라이선스를 꼭 보여 줘야 함)
    if (plan.credit) {
      ctx.save();
      ctx.globalAlpha = clamp(p * 2);
      centerText(plan.credit, y + h + 44, 28, BODY, COLOR.muted, { maxW: w });
      ctx.restore();
    }
  }

  function drawReveal(t) {
    const p = prog(t, S3 + 0.25, 0.4);
    if (p <= 0) return;
    const m = plan.menu;
    // 끼니 · 종류 칩
    const chip = `${m.meal} · ${m.category}`;
    ctx.font = `40px ${JUA}`;
    const cw = ctx.measureText(chip).width + 64;
    popAt(W / 2, 1082, lerp(0.7, 1, easeBack(p)), p * 2, () => {
      ctx.fillStyle = COLOR.chip;
      roundRect(W / 2 - cw / 2, 1052, cw, 64, 32);
      ctx.fill();
      centerText(chip, 1098, 40, JUA, COLOR.muted);
    });
    const p2 = prog(t, S3 + 0.4, 0.45);
    popAt(W / 2, 1200, lerp(0.5, 1, easeBack(p2)), p2 * 2, () => {
      centerText(m.name, 1250, 150, JUA, COLOR.ink, { maxW: 940 });
    });
  }

  function drawHeadline(t) {
    // 1~2장면: "오늘 점심 뭐 먹지?" → 3장면: "오늘 점심은 이거다냥!"
    const pIn = prog(t, 0.05, 0.35);
    const swap = prog(t, S3, 0.3);
    if (swap < 1) {
      popAt(W / 2, 300, lerp(0.6, 1, easeBack(pIn)), pIn * 2 * (1 - swap), () => {
        centerText(`오늘 ${meal} 뭐 먹지?`, 340, 116, JUA, COLOR.ink);
      });
    }
    if (swap > 0) {
      popAt(W / 2, 290, lerp(0.7, 1, easeBack(swap)), swap * 2, () => {
        centerText(`오늘 ${meal}은 이거다냥!`, 320, 96, JUA, COLOR.accent);
      });
    }
  }

  function drawMain(t) {
    const lay = catLayout(t);
    plate(lay.plate[0], lay.plate[1], lay.plate[2], 1);
    // 1장면: 냥빵이가 아래에서 톡 올라옴
    const enter = easeBack(prog(t, 0.1, 0.6));
    drawCat(lay.x, lay.y + (1 - enter) * 700, lay.s, t >= S3 + 0.2 ? 'like' : 'default', t);

    drawHeadline(t);
    if (t >= S2) drawRoulette(t);
    if (t >= S3) {
      drawPhotoCard(t);
      drawReveal(t);
    }

    // 말풍선
    if (t < S2) bubble('골라 줄게냥!', 790, 640, 640, 770, prog(t, 0.7, 0.3) * (1 - prog(t, S2 - 0.15, 0.15)));
    else if (t < S3) bubble('두구두구…', 800, 930, 690, 1040, prog(t, S2 + 0.45, 0.3) * (1 - prog(t, S3 - 0.15, 0.15)));
    else {
      const name = plan.menu.name;
      bubble(`오늘은 ${name}${hasBatchim(name) ? '이다냥' : '다냥'}!`, 660, 1395, 360, 1478, prog(t, S3 + 0.8, 0.3));
    }
  }

  function drawEnd(t) {
    const p = easeOut(prog(t, S4, 0.4));
    if (p <= 0) return;
    const top = H * (1 - p);
    ctx.save();
    ctx.translate(0, top);
    ctx.fillStyle = COLOR.bg;
    ctx.fillRect(0, 0, W, H);
    gingham(0, 0, W, 44, 44);
    paw(140, 1320, 60, -14);
    paw(950, 380, 56, 18);
    plate(540, 640, 320, 1);
    drawCat(312, 330, 1.2, 'like', t);
    centerText('레시피는 프로필 링크에서!', 1110, 88, JUA, COLOR.ink);
    centerText('냥빵이의 오늘은 뭐 먹지', 1215, 60, JUA, COLOR.accent);
    const url = 'meal-project.pages.dev';
    ctx.font = `46px ${JUA}`;
    const uw = ctx.measureText(url).width + 90;
    ctx.fillStyle = COLOR.accent;
    roundRect(W / 2 - uw / 2, 1265, uw, 92, 46);
    ctx.fill();
    centerText(url, 1328, 46, JUA, '#FFFFFF');
    ctx.restore();
  }

  function render(t) {
    ctx.save();
    drawBackground();
    if (plan) {
      if (t < S4 + 0.4) drawMain(t);
      drawEnd(t);
    }
    ctx.restore();
  }


  // ── 영상 내용 정하기 ───────────────────────────────────

  async function loadPhoto(file) {
    if (!file) return null;
    if (!photoCache.has(file)) {
      photoCache.set(file, (async () => {
        // 위키미디어 원본 대신 1080px 썸네일 주소를 받아서, 캔버스에 그려도 되는(CORS) 방식으로 불러옴
        const api = 'https://commons.wikimedia.org/w/api.php?action=query&format=json&origin=*&prop=imageinfo&iiprop=url&iiurlwidth=1080&titles=File:' + encodeURIComponent(file);
        const data = await (await fetch(api)).json();
        const info = Object.values(data.query.pages)[0].imageinfo[0];
        const blob = await (await fetch(info.thumburl || info.url)).blob();
        return createImageBitmap(blob);
      })().catch(err => {
        console.error(err);
        photoCache.delete(file);
        return null;
      }));
    }
    return photoCache.get(file);
  }

  function shuffle(list) {
    const a = list.slice();
    for (let i = a.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [a[i], a[j]] = [a[j], a[i]];
    }
    return a;
  }

  async function makePlan() {
    const list = menus.filter(m => m.meal === meal);
    const chosen = menuSelect.value
      ? list.find(m => String(m.id) === menuSelect.value)
      : list[Math.floor(Math.random() * list.length)];
    // 룰렛: 점점 느려지는 시각들, 마지막 이름이 고른 메뉴
    const times = [];
    let at = S2 + 0.35;
    let gap = 0.07;
    while (at < S3 - 0.55) {
      times.push(at);
      at += gap;
      gap *= 1.12;
    }
    const pool = shuffle(list.map(m => m.name).filter(n => n !== chosen.name));
    const names = times.map((_, i) => pool[i % pool.length]);
    names[names.length - 1] = chosen.name;

    statusEl.textContent = '음식 사진을 불러오는 중…';
    const photo = await loadPhoto(chosen.photo);
    const c = credits[chosen.photo] || {};
    const credit = chosen.photo ? ['사진: ' + (c.a || '위키미디어 공용 작가'), c.l, '위키미디어'].filter(Boolean).join(' · ') : '';
    return { menu: chosen, photo, credit, times, names };
  }


  // ── 미리보기 · 영상 만들기 ─────────────────────────────

  function stopPreview() {
    cancelAnimationFrame(raf);
    raf = 0;
  }

  function play(onDone) {
    stopPreview();
    const start = performance.now();
    const loop = now => {
      const t = (now - start) / 1000;
      render(Math.min(t, DURATION));
      if (t < DURATION) raf = requestAnimationFrame(loop);
      else { raf = 0; if (onDone) onDone(); }
    };
    raf = requestAnimationFrame(loop);
  }

  function setBusy(busy) {
    previewBtn.disabled = busy;
    makeBtn.disabled = busy;
    mealTabs.querySelectorAll('button').forEach(b => { b.disabled = busy; });
    menuSelect.disabled = busy;
  }

  const sleep = ms => new Promise(r => setTimeout(r, ms));

  async function pickCodec() {
    for (const codec of ['avc1.640028', 'avc1.4d0028', 'avc1.42003e']) {
      try {
        const { supported } = await VideoEncoder.isConfigSupported({ codec, width: W, height: H, bitrate: 6e6, framerate: FPS });
        if (supported) return codec;
      } catch (e) { /* 다음 후보 */ }
    }
    return null;
  }

  // 프레임을 하나씩 그려서 인코더에 넣음 (화면 속도와 상관없이 정확한 11초 영상)
  async function encodeFrames(codec) {
    const muxer = new Mp4Muxer.Muxer({
      target: new Mp4Muxer.ArrayBufferTarget(),
      video: { codec: 'avc', width: W, height: H, frameRate: FPS },
      fastStart: 'in-memory',   // 영상 정보를 파일 앞에 둬서 앱이 바로 읽게
    });
    let failure = null;
    const encoder = new VideoEncoder({
      output: (chunk, meta) => muxer.addVideoChunk(chunk, meta),
      error: e => { failure = e; },
    });
    encoder.configure({ codec, width: W, height: H, bitrate: 6e6, framerate: FPS });
    const total = Math.round(DURATION * FPS);
    for (let i = 0; i < total; i++) {
      if (failure) throw failure;
      render(i / FPS);
      const frame = new VideoFrame(canvas, { timestamp: Math.round(i * 1e6 / FPS), duration: Math.round(1e6 / FPS) });
      encoder.encode(frame, { keyFrame: i % (FPS * 2) === 0 });
      frame.close();
      while (encoder.encodeQueueSize > 6) await sleep(4);
      if (i % 6 === 0) {
        progressBar.style.width = `${Math.round((i / total) * 100)}%`;
        statusEl.textContent = `영상을 만드는 중… ${Math.round((i / total) * 100)}%`;
        await sleep(0);
      }
    }
    await encoder.flush();
    encoder.close();
    if (failure) throw failure;
    muxer.finalize();
    return new Blob([muxer.target.buffer], { type: 'video/mp4' });
  }

  // 인코더를 못 쓰는 브라우저: 화면에 재생하면서 그대로 녹화 (11초 걸림)
  async function recordRealtime() {
    const type = ['video/mp4;codecs=avc1', 'video/mp4', 'video/webm'].find(t => window.MediaRecorder && MediaRecorder.isTypeSupported(t));
    if (!type) throw new Error('이 브라우저는 영상 저장을 지원하지 않아요');
    const recorder = new MediaRecorder(canvas.captureStream(FPS), { mimeType: type, videoBitsPerSecond: 6e6 });
    const chunks = [];
    recorder.ondataavailable = e => { if (e.data.size) chunks.push(e.data); };
    const stopped = new Promise(r => { recorder.onstop = r; });
    recorder.start();
    statusEl.textContent = '녹화하는 중… (11초)';
    await new Promise(r => play(r));
    recorder.stop();
    await stopped;
    return new Blob(chunks, { type: type.split(';')[0] });
  }

  async function makeVideo() {
    stopPreview();
    setBusy(true);
    resultEl.hidden = true;
    progressBar.style.width = '0%';
    try {
      plan = await makePlan();
      const codec = window.VideoEncoder && window.Mp4Muxer ? await pickCodec() : null;
      const blob = codec ? await encodeFrames(codec) : await recordRealtime();
      const ext = blob.type.includes('webm') ? 'webm' : 'mp4';
      const name = `냥빵이-${meal}-${plan.menu.name}.${ext}`.replace(/\s+/g, '');
      resultFile = new File([blob], name, { type: blob.type });
      const url = URL.createObjectURL(blob);
      resultVideo.src = url;
      downloadLink.href = url;
      downloadLink.download = name;
      shareBtn.hidden = !(navigator.canShare && navigator.canShare({ files: [resultFile] }));
      resultEl.hidden = false;
      progressBar.style.width = '100%';
      statusEl.textContent = `다 만들었어요! "${plan.menu.name}" 영상 (${(blob.size / 1024 / 1024).toFixed(1)}MB)`;
      render(S3 + 1.5);
      window.studioLastVideo = blob;   // 확인용
    } catch (err) {
      console.error(err);
      statusEl.textContent = '영상을 만들지 못했어요: ' + (err && err.message ? err.message : err);
    } finally {
      setBusy(false);
    }
  }

  previewBtn.addEventListener('click', async () => {
    setBusy(true);
    try {
      plan = await makePlan();
      statusEl.textContent = `미리보기: ${plan.menu.name}`;
    } finally {
      setBusy(false);
    }
    play();
  });
  makeBtn.addEventListener('click', makeVideo);
  shareBtn.addEventListener('click', () => {
    if (resultFile) navigator.share({ files: [resultFile], title: '냥빵이 숏폼' }).catch(() => {});
  });


  // ── 시작 ──────────────────────────────────────────────

  function renderMealTabs() {
    mealTabs.replaceChildren(...MEALS.map(name => {
      const b = document.createElement('button');
      b.type = 'button';
      b.textContent = name;
      b.setAttribute('aria-pressed', name === meal);
      b.addEventListener('click', () => {
        meal = name;
        renderMealTabs();
        fillMenus();
      });
      return b;
    }));
  }

  function fillMenus() {
    const list = menus.filter(m => m.meal === meal).sort((a, b) => a.name.localeCompare(b.name, 'ko'));
    menuSelect.replaceChildren(new Option('무작위로 뽑기', ''), ...list.map(m => new Option(m.name, m.id)));
  }

  window.studioRender = t => render(t);   // 확인용: 특정 시각의 장면 그리기
  window.studioPlan = async id => { menuSelect.value = String(id || ''); plan = await makePlan(); return plan.menu.name; };

  async function init() {
    renderMealTabs();
    render(0);
    const cfg = window.APP_CONFIG || {};
    try {
      const db = window.supabase.createClient(cfg.supabaseUrl, cfg.supabaseKey);
      const [menuRes, creditJson] = await Promise.all([
        db.from('menus').select('id, meal, category, name, photo').order('id'),
        fetch('recipes/photo-credits.json').then(r => (r.ok ? r.json() : {})).catch(() => ({})),
        document.fonts.load(`116px ${JUA}`),
        document.fonts.load(`700 60px ${GAEGU}`),
        document.fonts.load(`28px ${BODY}`),
      ]);
      if (menuRes.error) throw menuRes.error;
      menus = menuRes.data;
      credits = creditJson;
      fillMenus();
      plan = await makePlan();
      render(S3 + 1.5);   // 첫 화면: 공개 장면 한 컷
      statusEl.textContent = '';
      previewBtn.disabled = false;
      makeBtn.disabled = false;
    } catch (err) {
      console.error(err);
      statusEl.textContent = '메뉴를 불러오지 못했어요. 새로고침해 주세요.';
    }
  }

  init();
})();
