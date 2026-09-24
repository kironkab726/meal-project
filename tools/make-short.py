# 냥빵이 요리일기 숏폼 조립 (1080x1920 세로 영상, 20~40초)
#
# 이 PC에는 ffmpeg/파이썬이 없어서 Higgsfield 샌드박스(sandbox_exec)에서 돌림.
# 샌드박스 /home/user/w 에 아래 파일을 받아 두고 python3 make-short.py 실행 → final.mp4, cover.jpg, sheet.jpg
#   c1.mp4 ~ c9.mp4  장면 영상 (Kling 3.0 std, 3~5초, 소리 없음, 9:16. 시작 그림은 nano_banana_2 + 냥빵이 요소)
#   studio.mp4       (선택) 사이트 /studio 로 만든 룰렛 영상. 2편부터는 안 씀 (그림 톤이 달라진다는 피드백)
#   a1.wav ~ a9.wav  (선택) 대사. 장면에 "vo" 가 있을 때만. 목소리가 AI 같다고 해서 1편부터 안 씀
#   Jua.ttf          자막 글꼴 (github.com/google/fonts ofl/jua). 가운뎃점(·)과 말줄임표(…)가 없으니 쓰지 말 것
#   scenes.json      장면 순서, 길이, 자막, 효과음 (마케팅 폴더 shorts/NN-이름/scenes.json)
#
# scenes.json 맨 위
#   title     위쪽 갈색 딱지 글 ("냥빵이 요리일기 #2 - 메뉴")      bgm  false 면 배경음악 없이 효과음만 (2편부터)
#   cover_at  썸네일로 뽑을 시각(초)
# 장면마다
#   src, dur, from(영상 시작 위치), speed(빨리 감기 배율)
#   title(false 면 딱지 없음), title_text, big(큰 흰 글씨 줄들), big_y, main, sub, step(번호), box_y, note, note_y
#   pop(false 면 글자가 튀어나오는 효과 없음, 첫 장면 등)
#   효과음: ding[초...], ticks {from,to,start,end}(룰렛 딸깍, 초당 횟수가 start→end로), chops[초...](칼질), sizzle [from,to](볶는 소리)
#   장면이 바뀔 때마다 "뽁" (pop_sfx false 면 안 냄. 영상 끝과 처음이 이어지는 첫 장면에 씀)
import json, os, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

W, H, FPS, SR = 1080, 1920, 30, 44100
os.chdir('/home/user/w')
cfg = json.load(open('scenes.json'))
BROWN, CREAM, INK, MUTED, WHITE = '#B8552F', (255, 251, 243, 238), '#4A3426', '#7A6352', '#FFFFFF'
JUA = 'Jua.ttf'
SUB = 54                       # 작은 줄 글씨 크기 (1편 46은 휴대폰에서 작다는 피드백)
POP = [0.6, 0.85, 1.08, 1.12, 1.05, 1.0]   # 글자가 튀어나올 때 프레임마다 크기 배율

def run(cmd):
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if r.returncode: print(cmd, r.stderr[-1500:]); sys.exit(1)
    return r.stdout

def font(size): return ImageFont.truetype(JUA, max(8, round(size)))

def tw(d, text, f): b = d.textbbox((0, 0), text, font=f); return b[2] - b[0]

# ── 자막 그림 (k = 크기 배율. 튀어나오는 효과는 k를 바꿔 몇 장 그림) ──
#   title/title_text : 맨 위 갈색 딱지 (배율 없이 그대로)   big : 흰 글씨 + 갈색 테두리로 크게
#   main/sub/step : 크림색 상자   note : 작은 안내 글
def overlay(s, k=1.0):
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if s.get('title', True):
        f = font(44); t = s.get('title_text', cfg.get('title', '냥빵이 요리일기'))
        w = tw(d, t, f) + 64
        d.rounded_rectangle(((W - w) // 2, 150, (W + w) // 2, 226), radius=38, fill=BROWN)
        d.text((W // 2, 188), t, font=f, fill=WHITE, anchor='mm')
    if s.get('big'):
        y = s.get('big_y', 360)
        for line in s['big']:
            d.text((W // 2, y), line, font=font(104 * k), fill=WHITE, anchor='mm', stroke_width=max(1, round(12 * k)), stroke_fill=INK)
            y += 128
    if s.get('main'):
        fm, fs = font(76 * k), font(SUB * k)
        badge = s.get('step')
        bw = round(104 * k) if badge else 0
        mw = tw(d, s['main'], fm) + bw
        subs = s.get('sub', [])
        w = max([mw] + [tw(d, x, fs) for x in subs]) + round(110 * k)
        h = round(150 * k) + round(70 * k) * len(subs)
        cy = s.get('box_y', 390)
        x0, y0 = (W - w) // 2, cy - h // 2
        d.rounded_rectangle((x0 + 6, y0 + 10, x0 + w + 6, y0 + h + 10), radius=round(42 * k), fill=(74, 52, 38, 60))
        d.rounded_rectangle((x0, y0, x0 + w, y0 + h), radius=round(42 * k), fill=CREAM, outline=BROWN, width=max(2, round(6 * k)))
        tx = W // 2 - mw // 2
        ty = y0 + round(76 * k)
        if badge:
            r = round(42 * k)
            d.ellipse((tx, ty - r, tx + 2 * r, ty + r), fill=BROWN)
            d.text((tx + r, ty), str(badge), font=font(58 * k), fill=WHITE, anchor='mm')
            tx += bw
        d.text((tx, ty), s['main'], font=fm, fill=INK, anchor='lm')
        y = ty + round(82 * k)
        for x in subs:
            d.text((W // 2, y), x, font=fs, fill=MUTED, anchor='mm'); y += round(70 * k)
    if s.get('note'):
        d.text((W // 2, s.get('note_y', 1500)), s['note'], font=font(36 * k), fill=WHITE, anchor='mm', stroke_width=max(1, round(6 * k)), stroke_fill=INK)
    return im

def overlay_files(i, s):
    ks = POP if s.get('pop', True) else [1.0]
    for j, k in enumerate(ks):
        overlay(s, k).save(f'ov{i}_{j:02d}.png')
    return f'-framerate {FPS} -i ov{i}_%02d.png'   # 마지막 장은 overlay가 장면 끝까지 붙잡고 있음

# ── 장면 영상 ──
parts, t = [], 0.0
for i, s in enumerate(cfg['scenes']):
    ov_in = overlay_files(i, s)
    D = s['dur']
    sp = s.get('speed', 1.0)
    if s['src'] == 'studio':
        v = f"-ss {s['from']} -t {D} -i studio.mp4"
        vf = 'fps=30'
    else:
        v = f"-ss {s.get('from', 0)} -t {D * sp + 0.3:.2f} -i {s['src']}"
        vf = (f'setpts=PTS/{sp},' if sp != 1 else '') + 'scale=1080:-2:flags=lanczos,crop=1080:1920,fps=30'   # 클링 716x1284 → 1080x1920
    # 장면마다 딱 D초 x 30장 (마지막 장면이 길거나 짧아져서 소리와 어긋나지 않게)
    run(f"ffmpeg -v error -y {v} {ov_in} -filter_complex \"[0:v]{vf},setsar=1[b];[b][1:v]overlay=0:0,format=yuv420p[o]\" -map [o] -frames:v {round(D * FPS)} -r 30 -c:v libx264 -preset medium -crf 16 -an seg{i}.mp4")
    s['start'] = t
    parts.append(f'seg{i}.mp4')
    t += D
total = t
open('list.txt', 'w').write(''.join(f"file '{p}'\n" for p in parts))
run('ffmpeg -v error -y -f concat -safe 0 -i list.txt -c copy video.mp4')

# ── 소리 ──
n = int(total * SR) + SR
end = int(total * SR)
rng = np.random.default_rng(7)
bgm = np.zeros(n); voice = np.zeros(n); fx = np.zeros(n)

def place(buf, at, wave):
    a = int(at * SR); b = min(n, a + len(wave))
    if 0 <= a < n: buf[a:b] += wave[:b - a]

# 배경음악 (1편: 오르골 C-G-Am-F, 직접 합성). 2편부터는 "bgm": false → 올릴 때 앱에서 유행 음악을 고름
if cfg.get('bgm', True):
    def note(freq, at, length, amp, bright):
        k = np.arange(int(length * SR)) / SR
        wave = np.sin(2 * np.pi * freq * k) * np.exp(-k * 4.5) + bright * np.sin(2 * np.pi * 2 * freq * k) * np.exp(-k * 9)
        place(bgm, at, amp * wave * np.minimum(1, k * 400))
    midi = lambda m: 440 * 2 ** ((m - 69) / 12)
    chords = [[60, 64, 67, 72], [55, 59, 62, 67], [57, 60, 64, 69], [53, 57, 60, 65]]   # C G Am F
    pattern = [0, 2, 1, 3, 2, 1, 3, 2]
    beat = 60 / 100
    bar = 0
    while bar * 4 * beat < total:
        ch = chords[bar % 4]
        for j, p in enumerate(pattern):
            note(midi(ch[p] + 12), bar * 4 * beat + j * beat / 2, 1.2, 0.055, 0.35)
        for j in (0, 2):
            note(midi(ch[0] - 12), bar * 4 * beat + j * beat, 1.6, 0.07, 0.1)
        bar += 1
    fade = int(1.5 * SR)
    bgm[end - fade:end] *= np.linspace(1, 0, fade); bgm[end:] = 0

def add_wav(f, at, gain):
    run(f'ffmpeg -v error -y -i {f} -ac 1 -ar {SR} -f f32le tmp.raw')
    place(voice, at, gain * np.fromfile('tmp.raw', dtype=np.float32))

def ding(at, amp=0.2):   # 당첨·완성 때 "띵" (E6 → A6)
    for f, dt in ((1318.5, 0), (1760, 0.09)):
        k = np.arange(int(1.2 * SR)) / SR
        place(fx, at + dt, amp * np.sin(2 * np.pi * f * k) * np.exp(-k * 5))

def pop(at):             # 장면 바뀔 때 "뽁"
    k = np.arange(int(0.07 * SR)) / SR
    place(fx, at, 0.18 * np.sin(2 * np.pi * (700 + 5000 * k) * k) * np.exp(-k * 40))

def tick(at, amp=0.13):  # 룰렛 딸깍
    k = np.arange(int(0.025 * SR)) / SR
    click = np.sin(2 * np.pi * 2400 * k) * np.exp(-k * 260) + 0.5 * rng.standard_normal(len(k)) * np.exp(-k * 500)
    place(fx, at, amp * click)

def chop(at, amp=0.32):  # 도마에 칼 "탁"
    k = np.arange(int(0.12 * SR)) / SR
    thud = np.sin(2 * np.pi * 150 * k) * np.exp(-k * 35) + 0.7 * rng.standard_normal(len(k)) * np.exp(-k * 90)
    place(fx, at, amp * thud)

def sizzle(a, b, amp=0.05):  # 팬에서 "치이익" (잘게 튀는 잡음)
    m = int((b - a) * SR)
    noise = rng.standard_normal(m)
    hiss = np.diff(noise, prepend=0)                          # 높은 소리만 남김
    crackle = (rng.random(m) < 0.004) * rng.standard_normal(m) * 6
    env = np.minimum(1, np.minimum(np.arange(m), m - np.arange(m)) / (0.15 * SR))
    place(fx, a, amp * (hiss + crackle) * env)

for s in cfg['scenes']:
    st = s['start']
    if s.get('pop_sfx', True): pop(st)
    for at in s.get('ding', []): ding(st + at)
    for at in s.get('chops', []): chop(st + at)
    if s.get('sizzle'): sizzle(st + s['sizzle'][0], st + s['sizzle'][1])
    if s.get('ticks'):
        tk = s['ticks']; at = st + tk['from']; stop = st + tk['to']
        while at < stop:
            rate = tk['start'] + (tk['end'] - tk['start']) * (at - st - tk['from']) / max(0.01, tk['to'] - tk['from'])
            tick(at); at += 1 / rate
    if s.get('vo'): add_wav(s['vo'], st + s.get('vo_at', 0.15), 1.0)

# 대사가 나올 때는 배경음을 낮춤 (덕킹)
act = (np.abs(voice) > 0.02).astype(float)
win = int(0.35 * SR)
env = np.clip(np.convolve(act, np.ones(win) / win, 'same') * 4, 0, 1)
mix = (bgm * (1 - 0.6 * env) + voice + fx)[:end]
peak = np.max(np.abs(mix))
if cfg.get('bgm', True):
    mix = mix / max(peak, 1e-9) * 0.89
    (mix.astype(np.float32)).tofile('mix.raw')
    run(f'ffmpeg -v error -y -f f32le -ar {SR} -ac 1 -i mix.raw -af loudnorm=I=-16:TP=-1.5:LRA=11,aresample=48000 -ar 48000 -ac 2 -c:a pcm_s16le audio.wav')
else:
    # 효과음만: 크기 맞추기(loudnorm)를 하면 조용한 부분까지 커져서, 가장 큰 소리만 맞춤. 앱에서 음악을 얹을 자리를 남겨 둠
    mix = mix / max(peak, 1e-9) * 0.7
    (mix.astype(np.float32)).tofile('mix.raw')
    run(f'ffmpeg -v error -y -f f32le -ar {SR} -ac 1 -i mix.raw -af aresample=48000 -ar 48000 -ac 2 -c:a pcm_s16le audio.wav')
# 마지막에 영상과 소리를 한 번에 다시 인코딩: 정확히 초당 30장(CFR), 1초마다 키프레임, AAC 48kHz,
# 소리 길이를 영상 길이에 맞춤. 인스타가 다시 변환할 때 소리가 중간에 끊기던 문제 대비 (#1, 2026-09-23)
run('ffmpeg -v error -y -i video.mp4 -i audio.wav -map 0:v -map 1:a -c:v libx264 -preset medium -crf 18 -profile:v high -level 4.0 '
    '-pix_fmt yuv420p -r 30 -fps_mode cfr -g 30 -keyint_min 30 -sc_threshold 0 '
    '-af apad -c:a aac -ar 48000 -ac 2 -b:a 160k -shortest -movflags +faststart final.mp4')
run(f"ffmpeg -v error -y -ss {cfg.get('cover_at', 1.2)} -i final.mp4 -frames:v 1 -q:v 2 cover.jpg")
run("ffmpeg -v error -y -i final.mp4 -vf 'fps=1,scale=216:-1,tile=10x3:padding=6:color=white' -frames:v 1 sheet.jpg")
print('total', round(total, 2), 'size', os.path.getsize('final.mp4'))
print(json.dumps([(round(s['start'], 2), s['dur']) for s in cfg['scenes']]))
