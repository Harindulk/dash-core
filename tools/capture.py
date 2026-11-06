"""Capture page media from a real autoplayed run: 4 screenshots, a GIF and a <=39 s trailer
that opens on the Warden. Usage: python tools/capture.py build/dashcore.gb dist [max_seconds]"""
import os
import subprocess
import sys
import wave

import numpy as np
from pyboy import PyBoy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from autoplay import decide, apply

ROM, OUT = sys.argv[1], sys.argv[2]
MAX_S = int(sys.argv[3]) if len(sys.argv) > 3 else 150
os.makedirs(OUT, exist_ok=True)
RATE, SCALE, FPS = 32768, 4, 59.7275
pb = PyBoy(ROM, window="null", symbols=ROM[:-3] + ".sym", ram_file=__import__("io").BytesIO(bytes(8192)),
           sound_emulated=True, sound_sample_rate=RATE)
A = lambda n: pb.symbol_lookup(n)[1]
M = pb.memory
frames, audio = [], []
ev = {}                                   # event name -> frame index (first occurrence)
score_at = []                             # score per recorded frame


def score():
    return int(f"{M[A('wScore')+2]:02X}{M[A('wScore')+1]:02X}{M[A('wScore')]:02X}")


def step(rec=True):
    pb.tick()
    if rec:
        frames.append(pb.screen.image.convert("RGB"))
        audio.append(pb.sound.ndarray.copy())
        score_at.append(score())


def mark(name):
    ev.setdefault(name, len(frames) - 1)


for _ in range(110):
    step(rec=False)
for _ in range(150):
    step()
title_end = len(frames)
pb.button("start")
step()
held = set()
prev = dict(boss=0, nodes=7, alive=1, over=0, combo=1)
over_since = None
for f in range(MAX_S * 60):
    over_since = (over_since + 1 if over_since is not None else 0) if M[A("wOver")] else None
    held = apply(pb, held, decide(pb, A, M, over_since if over_since is not None else 999))
    step()
    boss, nodes, alive, over = M[A("wBoss")], M[A("wBossNodes")], M[A("wAlive")], M[A("wOver")]
    if boss == 1 and prev["boss"] == 0: mark("boss_enter")
    if boss == 2 and nodes < prev["nodes"] and "boss_enter" in ev:
        mark("break1"); ev["break_last"] = len(frames) - 1
    if boss == 3 and prev["boss"] == 2: mark("boss_down")
    if not alive and prev["alive"]: mark("death")
    if over and not prev["over"]: mark("gameover")
    if M[A("wDash")] and M[A("wCombo")] >= 5 and "boss_enter" not in ev: mark("chain")
    prev = dict(boss=boss, nodes=nodes, alive=alive, over=over)
    if "boss_down" in ev and len(frames) - ev["boss_down"] > 60 * 9 and ("gameover" in ev or f > 100 * 60):
        break
for k in list(held):
    pb.button_release(k)
for _ in range(170):                      # let the game-over panel land and sit
    step()
    if M[A("wOver")]: mark("gameover")
pb.stop(save=False)
n = len(frames)
print("recorded", n, "frames; events", {k: v for k, v in sorted(ev.items(), key=lambda kv: kv[1])})


def seg(a, b):
    return max(title_end, a), min(n, b)


def best_window(a, b, w):
    """start of the w-frame window in [a, b) with the largest score gain"""
    best, bs = a, -1
    for s in range(a, max(a + 1, b - w), 30):
        g = score_at[min(s + w, n - 1)] - score_at[s]
        if g > bs:
            best, bs = s, g
    return best


parts = []
if "break1" in ev:
    parts.append(seg(ev["break1"] - 100, ev["break1"] + 50))        # cold open: a node shatters
parts.append((0, 90))                                                # title
play0 = title_end + 30
play_end = ev.get("boss_enter", n)
w = best_window(play0, play_end, 600)
parts.append(seg(w, w + 600))                                        # best 10 s of chaining
if "boss_enter" in ev:
    parts.append(seg(ev["boss_enter"] - 30, ev["boss_enter"] + 270))  # WARDEN arrives
if "boss_down" in ev:
    parts.append(seg(ev["boss_down"] - 270, ev["boss_down"] + 150))   # last nodes and the kill
    w2 = best_window(ev["boss_down"] + 150, n, 300)
    parts.append(seg(w2, w2 + 300))                                   # carnage after
if "gameover" in ev:
    parts.append(seg(ev["gameover"] + 60, ev["gameover"] + 150))
total = sum(b - a for a, b in parts)
limit = int(38.5 * 60)
if total > limit:                                                    # trim the chaining window first
    parts[2] = (parts[2][0], parts[2][1] - (total - limit))
print("trailer parts", parts, "frames", sum(b - a for a, b in parts))

shots = {}
shots["1_title"] = next(f for f in reversed(frames[:title_end]) if np.array(f)[64:72, 32:120].min() < 100)
if "chain" in ev: shots["2_chain"] = frames[ev["chain"] + 2]
if "break1" in ev: shots["3_warden"] = frames[ev["break1"] + 3]
elif "boss_enter" in ev: shots["3_warden"] = frames[ev["boss_enter"] + 120]
if "gameover" in ev: shots["4_gameover"] = frames[min(n - 1, ev["gameover"] + 120)]
elif "boss_down" in ev: shots["4_wardendown"] = frames[ev["boss_down"] + 40]
for name, img in shots.items():
    img.resize((160 * SCALE, 144 * SCALE), 0).save(os.path.join(OUT, name + ".png"))
print("shots", sorted(shots))

g0 = ev.get("boss_enter", title_end + 60) - 60
g = [f.resize((320, 288), 0) for f in frames[g0:g0 + 12 * 60:2]]
g[0].save(os.path.join(OUT, "gameplay.gif"), save_all=True, append_images=g[1:], duration=33, loop=0)

sel = [i for a, b in parts for i in range(a, b)]
pcm = np.concatenate([audio[i] for i in sel]).astype(np.int16)
if np.abs(pcm).max() < 256:
    pcm = (pcm * 200).clip(-32768, 32767).astype(np.int16)
wav = os.path.join(OUT, "trailer.wav")
with wave.open(wav, "wb") as wf:
    wf.setnchannels(2); wf.setsampwidth(2); wf.setframerate(RATE); wf.writeframes(pcm.tobytes())
secs = len(sel) / FPS
mp4 = os.path.join(OUT, "trailer.mp4")
cmd = ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "160x144",
       "-framerate", str(FPS), "-i", "-", "-i", wav,
       "-vf", f"scale={160*SCALE}:{144*SCALE}:flags=neighbor,pad=1280:720:(ow-iw)/2:(oh-ih)/2:color=0x1a1a1a,fade=t=out:st={secs-1.2:.2f}:d=1.2",
       "-af", f"highpass=f=20,volume=8dB,afade=t=out:st={secs-1.2:.2f}:d=1.2",
       "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "16", "-c:a", "aac", "-b:a", "160k", "-shortest", mp4]
p = subprocess.Popen(cmd, stdin=subprocess.PIPE)
for i in sel:
    p.stdin.write(frames[i].tobytes())
p.stdin.close(); p.wait()
os.remove(wav)
print("trailer", mp4, f"{secs:.1f}s", "exit", p.returncode)
