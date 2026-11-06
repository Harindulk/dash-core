"""Capture page media from a real emulated run: 4 screenshots, a GIF and a <=40 s trailer.

Usage: python tools/capture.py build/dashcore.gb build/media SEED
Gameplay is played by the same simple bot as tools/bot.py (no cheats, no memory pokes).
"""
import io
import os
import random
import subprocess
import sys
import wave

import numpy as np
from pyboy import PyBoy

ROM, OUT, SEED = sys.argv[1], sys.argv[2], int(sys.argv[3])
os.makedirs(OUT, exist_ok=True)
rng = random.Random(SEED)
RATE = 32768
SCALE = 4
pb = PyBoy(ROM, window="null", symbols=ROM[:-3] + ".sym", ram_file=io.BytesIO(bytes(8192)),
           sound_emulated=True, sound_sample_rate=RATE)
A = lambda n: pb.symbol_lookup(n)[1]
M = pb.memory
frames, audio = [], []
shots = {}


def step(n=1, rec=True):
    for _ in range(n):
        pb.tick()
        if rec:
            frames.append(pb.screen.image.convert("RGB"))
            audio.append(pb.sound.ndarray.copy())


def big(img):
    return img.resize((160 * SCALE, 144 * SCALE), 0)


def bot_input(held):
    px, py = M[A("wPX") + 1] + 8, M[A("wPY") + 1] + 8
    best = None
    for i in range(12):
        b = A("wEnemies") + i * 16
        if M[b] in (1, 2):
            sv = lambda lo, hi: (lo | hi << 8) - (65536 if hi & 0x80 else 0)
            vx, vy = sv(M[b + 6], M[b + 7]) / 256, sv(M[b + 8], M[b + 9]) / 256
            ex, ey = M[b + 3] + 4 + vx * 8, M[b + 5] + 4 + vy * 8
            d = abs(ex - px) + abs(ey - py)
            if best is None or d < best[0]:
                best = (d, int(ex - px), int(ey - py))
    want = set()
    ready = M[A("wDashCD")] == 0 and M[A("wDash")] == 0
    if best:
        d, dx, dy = best
        H = "right" if dx > 0 else "left"
        V = "down" if dy > 0 else "up"
        if ready:
            if abs(dx) <= abs(dy):
                want = {H} if abs(dx) > 4 else {V}
                if abs(dx) <= 4 and abs(dy) < 52 and rng.random() < 0.5:
                    pb.button("a")
            else:
                want = {V} if abs(dy) > 4 else {H}
                if abs(dy) <= 4 and abs(dx) < 52 and rng.random() < 0.5:
                    pb.button("a")
        elif d < 24:
            want = {"left" if dx > 0 else "right", "up" if dy > 0 else "down"}
    for k in held - want:
        pb.button_release(k)
    for k in want - held:
        pb.button_press(k)
    return want


# boot (not recorded), then title
step(110, rec=False)
step(150)
# title frame with PRESS START visible (row 9 has dark pixels)
shots["1_title"] = next(f for f in reversed(frames) if np.array(f)[72:80, 32:120].min() < 100)
pb.button("start")
step(10)

# gameplay: bot for up to ~26 s
held = set()
chain, level = [], []
for f in range(26 * 60):
    held = bot_input(held)
    step()
    if not M[A("wAlive")]:
        break
    live = sum(1 for i in range(12) if M[A("wEnemies") + i * 16] in (1, 2, 3))
    parts = sum(1 for i in range(12) if M[A("wParts") + i * 6])
    if M[A("wDash")] and parts >= 4 and live >= 3:
        chain.append(frames[-1])
    hud = np.array(frames[-1])[137:143]
    if hud[:, 0:20].min() > 200 and hud[:, 24:40].min() < 100:   # banner on screen
        level.append(frames[-1])
for k in list(held):
    pb.button_release(k)
# hands off: let the arena finish the run
while M[A("wAlive")]:
    step()
step(220)
shots["4_gameover"] = frames[-1]
pb.stop(save=False)
if chain: shots["2_chain"] = chain[len(chain) // 2]
if level: shots["3_level"] = level[len(level) // 3]

print("frames", len(frames), "shots", sorted(shots))
for name, img in shots.items():
    big(img).save(os.path.join(OUT, name + ".png"))

# GIF: gameplay only, every 2nd frame, 2x
g = [f.resize((320, 288), 0) for f in frames[150:150 + 20 * 60:2]]
g[0].save(os.path.join(OUT, "gameplay.gif"), save_all=True, append_images=g[1:], duration=33, loop=0)

# trailer: raw frames + audio -> mp4 (nearest-neighbour 4x), cut to 39 s
pcm = np.concatenate(audio).astype(np.int16)
if pcm.dtype != np.int16 or np.abs(pcm).max() < 256:
    pcm = (pcm * 200).clip(-32768, 32767).astype(np.int16)   # PyBoy gives small signed samples
wav = os.path.join(OUT, "trailer.wav")
with wave.open(wav, "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(RATE); w.writeframes(pcm.tobytes())
mp4 = os.path.join(OUT, "trailer.mp4")
cmd = ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "160x144",
       "-framerate", "59.7275", "-i", "-", "-i", wav,
       "-vf", f"scale={160*SCALE}:{144*SCALE}:flags=neighbor,pad=1280:720:(ow-iw)/2:(oh-ih)/2:color=0x1a1a1a,fade=t=out:st=37.5:d=1.5",
       "-af", "highpass=f=20,volume=8dB,afade=t=out:st=37.5:d=1.5",
       "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "16", "-c:a", "aac", "-b:a", "160k", "-t", "39", "-shortest", mp4]
p = subprocess.Popen(cmd, stdin=subprocess.PIPE)
for f in frames:
    p.stdin.write(f.tobytes())
p.stdin.close()
p.wait()
print("trailer", mp4, "exit", p.returncode)
