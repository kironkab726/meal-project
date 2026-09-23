# 냥빵이 요리일기 숏폼 조립 (1080x1920 세로 영상, 30~40초)
#
# 이 PC에는 ffmpeg/파이썬이 없어서 Higgsfield 샌드박스(sandbox_exec)에서 돌림.
# 샌드박스 /home/user/w 에 아래 파일을 받아 두고 python3 make-short.py 실행 → final.mp4, cover.jpg, sheet.jpg
#   c1.mp4 ~ c8.mp4  장면 영상 (Kling 3.0 std, 5초, 소리 없음, 9:16. 시작 그림은 nano_banana_2 + 냥빵이 요소)
#   studio.mp4       사이트 /studio 로 만든 룰렛 영상 (끼니와 메뉴를 골라 "영상 만들기")
#   a1.wav ~ a9.wav  대사 (선택. 장면에 "vo" 가 있을 때만). #1 은 목소리가 AI 같다고 해서 빼고 자막 + 음악만 씀
#   Jua.ttf          자막 글꼴 (github.com/google/fonts ofl/jua). 가운뎃점(·)과 말줄임표(…)가 없으니 쓰지 말 것
#   scenes.json      장면 순서, 길이, 자막 (마케팅 폴더 shorts/NN-이름/scenes.json)
#
# 소리: 오르골 배경음(C-G-Am-F, 직접 합성이라 저작권 없음) + 장면 바뀔 때 "뽁" + "sfx" 로 지정한 "띵".
# 대사가 있으면 나오는 동안 배경음을 60% 줄임. 마지막에 -16 LUFS 로 소리 크기를 맞춤.
import json, os, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

W, H, FPS, SR = 1080, 1920, 30, 44100
os.chdir('/home/user/w')
cfg = json.load(open('scenes.json'))
BROWN, CREAM, INK, MUTED, WHITE = '#B8552F', (255, 251, 243, 238), '#4A3426', '#7A6352', '#FFFFFF'
JUA = 'Jua.ttf'

def run(cmd):
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if r.returncode: print(cmd, r.stderr[-1500:]); sys.exit(1)
    return r.stdout

def font(size): return ImageFont.truetype(JUA, size)

def tw(d, text, f): b = d.textbbox((0, 0), text, font=f); return b[2] - b[0]

# ── 자막 그림 (장면마다 투명 PNG 한 장) ──
#   title/title_text : 맨 위 갈색 딱지   big : 흰 글씨 + 갈색 테두리로 크게   main/sub/step : 크림색 상자
#   note : 작은 안내 글 (끝 장면의 AI 안내)
def overlay(i, s):
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
            d.text((W // 2, y), line, font=font(104), fill=WHITE, anchor='mm', stroke_width=12, stroke_fill=INK)
            y += 128
    if s.get('main'):
        fm, fs = font(76), font(46)
        badge = s.get('step')
        mw = tw(d, s['main'], fm) + (104 if badge else 0)
        subs = s.get('sub', [])
        w = max([mw] + [tw(d, x, fs) for x in subs]) + 110
        h = 150 + 62 * len(subs)
        cy = s.get('box_y', 390)
        x0, y0 = (W - w) // 2, cy - h // 2
        d.rounded_rectangle((x0 + 6, y0 + 10, x0 + w + 6, y0 + h + 10), radius=42, fill=(74, 52, 38, 60))
        d.rounded_rectangle((x0, y0, x0 + w, y0 + h), radius=42, fill=CREAM, outline=BROWN, width=6)
        tx = W // 2 - mw // 2
        ty = y0 + 76
        if badge:
            d.ellipse((tx, ty - 42, tx + 84, ty + 42), fill=BROWN)
            d.text((tx + 42, ty), str(badge), font=font(58), fill=WHITE, anchor='mm')
            tx += 104
        d.text((tx, ty), s['main'], font=fm, fill=INK, anchor='lm')
        y = ty + 76
        for x in subs:
            d.text((W // 2, y), x, font=fs, fill=MUTED, anchor='mm'); y += 62
    if s.get('note'):
        d.text((W // 2, s.get('note_y', 1500)), s['note'], font=font(34), fill=WHITE, anchor='mm', stroke_width=6, stroke_fill=INK)
    im.save(f'ov{i}.png')

# ── 장면 영상 ──
parts, t = [], 0.0
for i, s in enumerate(cfg['scenes']):
    overlay(i, s)
    D = s['dur']
    if s['src'] == 'studio':
        v = f"-ss {s['from']} -t {D} -i studio.mp4"
        vf = 'fps=30'
    else:
        v = f"-t {D} -i {s['src']}"
        vf = 'scale=1080:-2:flags=lanczos,crop=1080:1920,fps=30'   # 클링 716x1284 → 1080x1920
    # 장면마다 딱 D초 x 30장 (마지막 장면이 길거나 짧아져서 소리와 어긋나지 않게)
    run(f"ffmpeg -v error -y {v} -i ov{i}.png -filter_complex \"[0:v]{vf},setsar=1[b];[b][1:v]overlay=0:0,format=yuv420p[o]\" -map [o] -frames:v {round(D * FPS)} -r 30 -c:v libx264 -preset medium -crf 16 -an seg{i}.mp4")
    s['start'] = t
    parts.append(f'seg{i}.mp4')
    t += D
total = t
open('list.txt', 'w').write(''.join(f"file '{p}'\n" for p in parts))
run('ffmpeg -v error -y -f concat -safe 0 -i list.txt -c copy video.mp4')

# ── 소리 ──
n = int(total * SR) + SR
mix = np.zeros(n)
def note(freq, at, length, amp, bright):
    k = np.arange(int(length * SR)) / SR
    wave = np.sin(2 * np.pi * freq * k) * np.exp(-k * 4.5) + bright * np.sin(2 * np.pi * 2 * freq * k) * np.exp(-k * 9)
    a = int(at * SR); b = min(n, a + len(wave)); mix[a:b] += amp * wave[:b - a] * np.minimum(1, k[:b - a] * 400)
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
fade = int(1.5 * SR); end = int(total * SR)
mix[end - fade:end] *= np.linspace(1, 0, fade); mix[end:] = 0

bgm = mix.copy(); voice = np.zeros(n); fx = np.zeros(n)
def add_wav(f, at, gain):
    run(f'ffmpeg -v error -y -i {f} -ac 1 -ar {SR} -f f32le tmp.raw')
    x = np.fromfile('tmp.raw', dtype=np.float32)
    a = int(at * SR); b = min(n, a + len(x)); voice[a:b] += gain * x[:b - a]

def ding(at, amp=0.2):   # 당첨·완성 때 "띵" (E6 → A6)
    for f, dt in ((1318.5, 0), (1760, 0.09)):
        k = np.arange(int(1.2 * SR)) / SR
        w = amp * np.sin(2 * np.pi * f * k) * np.exp(-k * 5)
        a = int((at + dt) * SR); b = min(n, a + len(w)); fx[a:b] += w[:b - a]

for s in cfg['scenes']:
    k = np.arange(int(0.07 * SR)) / SR
    pop = 0.18 * np.sin(2 * np.pi * (700 + 5000 * k) * k) * np.exp(-k * 40)
    a = int(s['start'] * SR); fx[a:a + len(pop)] += pop
    for at in s.get('ding', []): ding(s['start'] + at)
    if s.get('vo'): add_wav(s['vo'], s['start'] + s.get('vo_at', 0.15), 1.0)

# 대사가 나올 때는 배경음을 낮춤 (덕킹)
act = (np.abs(voice) > 0.02).astype(float)
win = int(0.35 * SR)
env = np.clip(np.convolve(act, np.ones(win) / win, 'same') * 4, 0, 1)
mix = bgm * (1 - 0.6 * env) + voice + fx
mix = mix[:end]
peak = np.max(np.abs(mix)); mix = mix / max(peak, 1e-9) * 0.89
(mix.astype(np.float32)).tofile('mix.raw')
run(f'ffmpeg -v error -y -f f32le -ar {SR} -ac 1 -i mix.raw -af loudnorm=I=-16:TP=-1.5:LRA=11,aresample=48000 -ar 48000 -ac 2 -c:a pcm_s16le audio.wav')
# 마지막에 영상과 소리를 한 번에 다시 인코딩: 정확히 초당 30장(CFR), 1초마다 키프레임, AAC 48kHz,
# 소리 길이를 영상 길이에 맞춤. 인스타가 다시 변환할 때 소리가 중간에 끊기던 문제 대비 (#1, 2026-09-23)
run('ffmpeg -v error -y -i video.mp4 -i audio.wav -map 0:v -map 1:a -c:v libx264 -preset medium -crf 18 -profile:v high -level 4.0 '
    '-pix_fmt yuv420p -r 30 -fps_mode cfr -g 30 -keyint_min 30 -sc_threshold 0 '
    '-af apad -c:a aac -ar 48000 -ac 2 -b:a 160k -shortest -movflags +faststart final.mp4')
run('ffmpeg -v error -y -ss 1.2 -i final.mp4 -frames:v 1 -q:v 2 cover.jpg')
run("ffmpeg -v error -y -i final.mp4 -vf 'fps=0.5,scale=216:-1,tile=9x2:padding=6:color=white' -frames:v 1 sheet.jpg")
print('total', round(total, 2), 'size', os.path.getsize('final.mp4'))
print(json.dumps([(round(s['start'], 2), s['dur']) for s in cfg['scenes']]))
