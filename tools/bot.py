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
deaths, maxs, maxlvl, bossdown = 0, 0, 0, 0
import os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from autoplay import decide, apply
for f in range(FRAMES):
    was_over = M[A("wOver")]
    held = apply(pb, held, decide(pb, A, M))
    step()
    if was_over and not M[A("wOver")]:
        deaths += 1
    if M[A("wBoss")] == 3: bossdown = 1
    maxlvl = max(maxlvl, M[A("wLevel")])
    maxs = max(maxs, int(f"{M[A('wScore')+2]:02X}{M[A('wScore')+1]:02X}{M[A('wScore')]:02X}"))

scores = M[A("wScore")+2], M[A("wScore")+1], M[A("wScore")]
print("deaths", deaths, "maxscore", maxs, "maxlevel", maxlvl, "bossdown", bossdown)
frames[0].save(OUT + ".gif", save_all=True, append_images=frames[1::2], duration=33, loop=0)
pcm = np.concatenate(audio)
print("audio samples", pcm.shape, "peak", int(np.abs(pcm).max()), "rms", float(np.sqrt((pcm.astype(float) ** 2).mean())))
with wave.open(OUT + ".wav", "wb") as w:
    w.setnchannels(2); w.setsampwidth(1 if pcm.dtype == np.int8 or pcm.dtype == np.uint8 else 2); w.setframerate(32768)
    data = pcm.astype(np.int16) if pcm.dtype != np.int8 else (pcm.astype(np.int16) + 128).astype(np.uint8)
    w.writeframes(data.tobytes())
pb.stop(save=False)
