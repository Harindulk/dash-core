"""Simple autoplay bot: records a GIF + WAV and reports survival time/score.

Usage: python tools/bot.py build/dashcore.gb out_prefix [frames] [seed]
"""
import io
import random
import sys
import wave

import numpy as np
from pyboy import PyBoy

ROM, OUT = sys.argv[1], sys.argv[2]
FRAMES = int(sys.argv[3]) if len(sys.argv) > 3 else 1800
SEED = int(sys.argv[4]) if len(sys.argv) > 4 else 1
rng = random.Random(SEED)

pb = PyBoy(ROM, window="null", symbols=ROM[:-3] + ".sym", ram_file=io.BytesIO(bytes(8192)),
           sound_emulated=True, sound_sample_rate=32768)
A = lambda n: pb.symbol_lookup(n)[1]
M = pb.memory
frames, audio = [], []


def step(n=1):
    for _ in range(n):
        pb.tick()
        frames.append(pb.screen.image.convert("P"))
        audio.append(pb.sound.ndarray.copy())


step(100)
pb.button("start")
step(40)
held = set()
deaths, best_t, t_alive = 0, 0, 0
maxs = 0
for f in range(FRAMES):
    if M[A("wOver")]:
        if M[A("wWY")] == 56 and rng.random() < 0.05:
            pb.button("start")
            deaths += 1
        step()
        continue
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
            if abs(dx) <= abs(dy):          # line up horizontally, then dash vertically
                want = {H} if abs(dx) > 4 else {V}
                if abs(dx) <= 4 and abs(dy) < 52 and rng.random() < 0.5: pb.button("a")
            else:
                want = {V} if abs(dy) > 4 else {H}
                if abs(dy) <= 4 and abs(dx) < 52 and rng.random() < 0.5: pb.button("a")
        elif d < 24:                        # cooling down: back off
            want = {"left" if dx > 0 else "right", "up" if dy > 0 else "down"}
    for k in held - want: pb.button_release(k)
    for k in want - held: pb.button_press(k)
    held = want
    step()
    maxs = max(maxs, int(f"{M[A('wScore')+2]:02X}{M[A('wScore')+1]:02X}{M[A('wScore')]:02X}"))

scores = M[A("wScore")+2], M[A("wScore")+1], M[A("wScore")]
print("deaths", deaths, "maxscore", maxs, "score", "".join(f"{x:02X}" for x in scores), "level", M[A("wLevel")])
frames[0].save(OUT + ".gif", save_all=True, append_images=frames[1::2], duration=33, loop=0)
pcm = np.concatenate(audio)
print("audio samples", pcm.shape, "peak", int(np.abs(pcm).max()), "rms", float(np.sqrt((pcm.astype(float) ** 2).mean())))
with wave.open(OUT + ".wav", "wb") as w:
    w.setnchannels(2); w.setsampwidth(1 if pcm.dtype == np.int8 or pcm.dtype == np.uint8 else 2); w.setframerate(32768)
    data = pcm.astype(np.int16) if pcm.dtype != np.int8 else (pcm.astype(np.int16) + 128).astype(np.uint8)
    w.writeframes(data.tobytes())
pb.stop(save=False)
