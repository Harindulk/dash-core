"""Headless self-check for DASH CORE (runs the real ROM in PyBoy).

Usage: python tools/test_rom.py build/dashcore.gb [--shots]
"""
import io
import os
import random
import shutil
import sys
import tempfile

from pyboy import PyBoy

ROM = sys.argv[1]
SHOTS = "--shots" in sys.argv
SYM = os.path.splitext(ROM)[0] + ".sym"
SHOT_DIR = os.path.join(os.path.dirname(ROM), "shots")
fails = []


def check(cond, msg):
    print(("PASS " if cond else "FAIL ") + msg)
    if not cond:
        fails.append(msg)


# ---- header ----
data = open(ROM, "rb").read()
check(len(data) == 32768, "ROM is 32 KiB")
check(data[0x147] == 0x03, "cart type 3 (MBC1+RAM+BATTERY)")
check(data[0x148] == 0x00, "ROM size code 0 (32 KiB)")
check(data[0x149] == 0x02, "RAM size code 2 (8 KiB)")
check(data[0x143] == 0x00, "DMG-only (no CGB flag)")
hc = 0
for b in data[0x134:0x14D]:
    hc = (hc - b - 1) & 0xFF
check(hc == data[0x14D], "header checksum")


def boot(ram=None):
    pb = PyBoy(ROM, window="null", symbols=SYM, sound_emulated=False,
               ram_file=io.BytesIO(ram) if ram is not None else io.BytesIO(bytes(8192)))
    return pb


def addr(pb, name):
    return pb.symbol_lookup(name)[1]


def rd(pb, name, off=0):
    return pb.memory[addr(pb, name) + off]


def wr(pb, name, val, off=0):
    pb.memory[addr(pb, name) + off] = val


def bcd(pb, name):
    a = addr(pb, name)
    return int(f"{pb.memory[a+2]:02X}{pb.memory[a+1]:02X}{pb.memory[a]:02X}")


def shot(pb, name):
    if SHOTS:
        os.makedirs(SHOT_DIR, exist_ok=True)
        pb.screen.image.convert("RGB").resize((480, 432), 0).save(os.path.join(SHOT_DIR, name))


def clear_enemies(pb):
    base = addr(pb, "wEnemies")
    for i in range(12 * 16):
        pb.memory[base + i] = 0


def settle(pb, fn):
    # A tick boundary can land mid-UpdateEnemies (slot copied out to wCur, not yet back),
    # so park the game loop in its pause branch before poking enemy memory.
    wr(pb, "wPaused", 1); pb.tick(2); fn(); wr(pb, "wPaused", 0)


def put_enemy(pb, slot, x, y, typ=1, vx=0, vy=0):
    base = addr(pb, "wEnemies") + slot * 16
    vals = [typ, 0, 0, x, 0, y, vx & 0xFF, (vx >> 8) & 0xFF, vy & 0xFF, (vy >> 8) & 0xFF, typ]
    for i, v in enumerate(vals):
        pb.memory[base + i] = v


def start_game(pb):
    pb.tick(90)
    shot(pb, "1_title.png")
    pb.button("start")
    pb.tick(30)


# ---- 1: boot, title, start ----
pb = boot()
pb.tick(120)                 # past the opening banner, on the title
check(pb.memory[0xFFFF] & 2, "title: STAT (HBlank ripple) interrupt stays enabled")
start_game(pb)
check(rd(pb, "wAlive") == 1, "game starts, player alive")
check(pb.memory[0xFFFF] & 2 == 0, "game: STAT interrupt off while no wave runs")
check(rd(pb, "wPX", 1) == 72, "player spawned at centre")

# ---- 1b: SELECT on the title switches the language ----
pb2 = boot()
pb2.tick(90)
pb2.button("select"); pb2.tick(40)
row12 = [pb2.memory[0x9800 + 12 * 32 + 1 + i] for i in range(4)]
check(rd(pb2, "wLang") == 1 and row12 == [13, 28, 31, 36], f"SELECT switches the title to Spanish (CRUZ, got {row12})")
pb2.button("select"); pb2.tick(40)
check(rd(pb2, "wLang") == 0 and pb2.memory[0x9800 + 12 * 32 + 1] == 14, "SELECT again: back to English (DPAD)")
pb2.stop(save=False)

# ---- 2: dash kill + chain ----
wr(pb, "wSpawnT", 255)
settle(pb, lambda: clear_enemies(pb))
wr(pb, "wFaceX", 1); wr(pb, "wFaceY", 0)
wr(pb, "wDashCD", 0)
put_enemy(pb, 0, 100, 64)
put_enemy(pb, 1, 125, 64)
pb.button("a")
pb.tick(40)
check(rd(pb, "wEnemies", 0) == 0, "dash kills first enemy")
check(rd(pb, "wEnemies", 16) == 0, "extended dash chains into second enemy")
check(bcd(pb, "wScore") == 30, f"score 10 + 20 for a x2 chain (got {bcd(pb, 'wScore')})")
check(rd(pb, "wCombo") == 3, "combo now x3")

# ---- 2b: a splitter breaks into two blinking children that hatch into drifters ----
pbs = boot()
start_game(pbs)
wr(pbs, "wSpawnT", 255)
settle(pbs, lambda: clear_enemies(pbs))
wr(pbs, "wFaceX", 1); wr(pbs, "wFaceY", 0); wr(pbs, "wDashCD", 0)
put_enemy(pbs, 0, 100, 64, typ=4)
wr(pbs, "wSpawnT", 255)
pbs.button("a")
types = []
for _ in range(20):
    pbs.tick(1)
    types = [pbs.memory[addr(pbs, "wEnemies") + i * 16] for i in range(12)]
    if types.count(3) == 2:
        break
check(types.count(3) == 2 and types.count(4) == 0, f"dashing a splitter leaves two blinking children (types {types})")
wr(pbs, "wSpawnT", 255)
pbs.tick(30)
types = [pbs.memory[addr(pbs, "wEnemies") + i * 16] for i in range(12)]
check(types.count(1) == 2, f"children hatch into two drifters (types {types})")
pbs.stop(save=False)

# ---- 3: whiffed dash resets combo ----
wr(pb, "wDashCD", 0)
wr(pb, "wFaceX", 0xFF)
pb.button("a")
pb.tick(150)
check(rd(pb, "wCombo") == 1, "dash that hits nothing resets combo")

# ---- 4: walls hold the player ----
pb.button_press("left")
pb.tick(120)
pb.button_release("left")
check(rd(pb, "wPX", 1) == 8, "left wall clamps player at x=8")

# ---- 5: spawner works on its own ----
wr(pb, "wSpawnT", 1)
pb.tick(80)
live = sum(1 for i in range(12) if rd(pb, "wEnemies", i * 16) != 0)
check(live >= 1, f"spawner spawned enemies ({live})")
shot(pb, "2_play.png")

# ---- 6: touching an enemy kills you, best is saved ----
wr(pb, "wSpawnT", 255)
settle(pb, lambda: clear_enemies(pb))
wr(pb, "wDashCD", 20)
px, py = rd(pb, "wPX", 1), rd(pb, "wPY", 1)
settle(pb, lambda: put_enemy(pb, 0, px + 4, py + 4))
pb.tick(3)
check(rd(pb, "wAlive") == 0, "contact without dash kills the player")
pb.tick(10)
shot(pb, "3_death.png")
pb.tick(140)
check(rd(pb, "wOver") == 1, "game over state reached")
check(bcd(pb, "wBest") == 30, "best updated to 30")
check(rd(pb, "wWY") == 56, "game over panel slid in")
shot(pb, "4_over.png")
ram_out = io.BytesIO()
pb.stop(save=True, ram_file=ram_out) if "ram_file" in pb.stop.__doc__ else pb.stop()
saved = ram_out.getvalue()
check(saved[:4] == b"DSHC" and saved[4:7] == bytes([0x30, 0, 0]), "SRAM holds magic + best")

# ---- 7: best survives a power cycle; garbage SRAM is rejected ----
pb = boot(saved)
pb.tick(150)
check(bcd(pb, "wBest") == 30, "best loads from SRAM after reboot")
pb.stop(save=False)
junk = bytearray(saved); junk[5] = 0x77
pb = boot(bytes(junk))
pb.tick(150)
check(bcd(pb, "wBest") == 0, "corrupt SRAM checksum -> best reset to 0")
pb.stop(save=False)
pb = boot(bytes([0xFF]) * 8192)
pb.tick(150)
check(bcd(pb, "wBest") == 0, "blank (FF) SRAM -> best 0")
pb.stop(save=False)

# ---- 7a: impact effects: fade-in, HBlank wave on hit-stop, stereo pan ----
pb = PyBoy(ROM, window="null", symbols=SYM, sound_emulated=True, ram_file=io.BytesIO(bytes(8192)))
pb.tick(90); pb.button_press("start"); pb.tick(2); pb.button_release("start"); pb.tick(3)
check(pb.memory[0xFF47] == 0 and rd(pb, "wFlashKind") == 2, "game starts with a palette fade-in from white")
pb.tick(30)
wr(pb, "wSpawnT", 255)
settle(pb, lambda: clear_enemies(pb))
put_enemy(pb, 0, 40, 64)
wr(pb, "wFaceX", 0xFF); wr(pb, "wFaceY", 0); wr(pb, "wDashCD", 0)
pb.button("a")
seen = None
for i in range(40):
    pb.tick()
    if rd(pb, "wWave") and seen is None:
        seen = (rd(pb, "wWaveAmp"), pb.memory[0xFFFF], pb.memory[0xFF25], rd(pb, "wFreeze"))
check(seen is not None and seen[0] == 1 and seen[1] & 2 and seen[3] > 0,
      f"kill at x1: 2 px wave during hit-stop, HBlank IRQ enabled (got {seen})")
check(seen is not None and seen[2] == 0xF6, f"kill on the left pans SFX left (NR51 {seen[2]:02X} if seen else None)")
check(rd(pb, "wWave") == 0 and pb.memory[0xFFFF] == 1 and pb.memory[0xFF43] == 0, "wave ends: IRQ off, SCX back to 0")
px, py = rd(pb, "wPX", 1), rd(pb, "wPY", 1)
settle(pb, lambda: put_enemy(pb, 1, px + 4, py + 4))
for i in range(30):
    pb.tick()
    if rd(pb, "wAlive") == 0:
        break
check(rd(pb, "wAlive") == 0 and rd(pb, "wWaveAmp") == 3 and rd(pb, "wWave") >= 20 and rd(pb, "wFlashKind") == 0,
      "death: 8 px wave for 24 frames with the invert flash")
pb.stop(save=False)

# ---- 7c: the Warden (boss at level 3) ----
def to_level3(pb):
    wr(pb, "wSpawnT", 255)
    settle(pb, lambda: clear_enemies(pb))
    wr(pb, "wLevel", 2); wr(pb, "wKillsLvl", 5)
    wr(pb, "wFaceX", 1); wr(pb, "wFaceY", 0); wr(pb, "wDashCD", 0)
    put_enemy(pb, 0, 100, 64)
    pb.button("a"); pb.tick(20)

def hold_attacks(pb):
    wr(pb, "wBossAtk", 250); wr(pb, "wBossBeamT", 250); wr(pb, "wSpawnT", 255)

pb = boot(); start_game(pb)
to_level3(pb)
check(rd(pb, "wLevel") == 3 and rd(pb, "wBoss") == 1, "18th kill reaches level 3 and the Warden starts entering")
pb.tick(80)
check(rd(pb, "wBoss") == 2 and pb.memory[0x9800 + 32 + 7] == 78 and pb.memory[0x9800 + 96 + 7] == 82,
      "Warden drawn on the BG (vent row, closed node) and live")
check(rd(pb, "wTopY") == 32, "arena top clamped under the boss")
broken = 0; score0 = bcd(pb, "wScore"); idx = 0xFF
for n in range(3):
    settle(pb, lambda: (clear_enemies(pb), wr(pb, "wPX", 72, 1), wr(pb, "wPY", 100, 1)))
    for i in range(400):
        if i % 100 == 0: hold_attacks(pb)
        pb.tick()
        if rd(pb, "wBossOpen") != 0xFF: break
    idx = rd(pb, "wBossOpen")
    if idx == 0xFF: break
    settle(pb, lambda: (clear_enemies(pb), wr(pb, "wPX", 52 + idx * 24, 1), wr(pb, "wPY", 44, 1)))
    wr(pb, "wFaceX", 0); wr(pb, "wFaceY", 0xFF); wr(pb, "wDashCD", 0); wr(pb, "wDash", 0)
    pb.button("a")
    for i in range(30):
        pb.tick()
        if not (rd(pb, "wBossNodes") & (1 << idx)):
            broken += 1; break
check(broken == 3, f"dashing into each open node breaks it ({broken}/3)")
check(bcd(pb, "wScore") >= score0 + 300, f"node breaks score 100 x combo (score {bcd(pb, 'wScore')})")
check(rd(pb, "wBoss") == 3, "third node: Warden dying")
pb.tick(130)
check(rd(pb, "wBoss") == 0 and rd(pb, "wTopY") == 8 and pb.memory[0x9800 + 32 + 7] == 48,
      "Warden gone, arena restored, top clamp back to 8")
check(bcd(pb, "wScore") >= score0 + 3300, f"boss bonus 3000 at level 3 (score {bcd(pb, 'wScore')})")
check(rd(pb, "wAlive") == 1 and rd(pb, "wMusOn") == 1, "player alive, music playing after the fight")
pb.stop(save=False)

# ---- 7c: the level-10 Warden ends a loop: CORE SECURED, back to level 1, faster ----
pb = boot(); start_game(pb)
wr(pb, "wSpawnT", 255)
settle(pb, lambda: clear_enemies(pb))
wr(pb, "wLevel", 8); wr(pb, "wKillsLvl", 5)
wr(pb, "wFaceX", 1); wr(pb, "wFaceY", 0); wr(pb, "wDashCD", 0)
put_enemy(pb, 0, 100, 64)
pb.button("a"); pb.tick(100)
check(rd(pb, "wLevel") == 9 and rd(pb, "wBoss") == 2, "level 10 brings the last Warden")
for n in range(3):
    settle(pb, lambda: (clear_enemies(pb), wr(pb, "wPX", 72, 1), wr(pb, "wPY", 100, 1)))
    for i in range(400):
        if i % 100 == 0: hold_attacks(pb)
        pb.tick()
        if rd(pb, "wBossOpen") != 0xFF: break
    idx = rd(pb, "wBossOpen")
    if idx == 0xFF: break
    settle(pb, lambda: (clear_enemies(pb), wr(pb, "wPX", 52 + idx * 24, 1), wr(pb, "wPY", 44, 1)))
    wr(pb, "wFaceX", 0); wr(pb, "wFaceY", 0xFF); wr(pb, "wDashCD", 0); wr(pb, "wDash", 0)
    pb.button("a")
    for i in range(30):
        pb.tick()
        if not (rd(pb, "wBossNodes") & (1 << idx)): break
banner = rd(pb, "wBannerTxt") | rd(pb, "wBannerTxt", 1) << 8
check(rd(pb, "wLoop") == 1 and rd(pb, "wLevel") == 0 and banner == addr(pb, "TxtSecure"),
      f"last Warden down: loop 1, level 1, CORE SECURED banner (loop {rd(pb, 'wLoop')}, level {rd(pb, 'wLevel')})")
pb.tick(200)
check(rd(pb, "wAlive") == 1 and rd(pb, "wBoss") == 0, "play continues into loop 2")
pb.stop(save=False)

# ---- 7d: the beam kills a standing player in its row ----
pb = boot(); start_game(pb)
to_level3(pb); pb.tick(80)
settle(pb, lambda: (clear_enemies(pb), wr(pb, "wPX", 72, 1), wr(pb, "wPY", 80, 1)))
wr(pb, "wBossAtk", 250); wr(pb, "wBossBeamT", 2); wr(pb, "wSpawnT", 255)
died = None
for i in range(90):
    pb.tick()
    if rd(pb, "wAlive") == 0:
        died = i; break
check(rd(pb, "wBossBeamRow") == 11, f"beam targets the player's row (row {rd(pb, 'wBossBeamRow')})")
check(died is not None and 40 < died < 70, f"beam warns, then kills a player standing in the row (frame {died})")
pb.stop(save=False)

# ---- 7b: worst-case load still runs at full frame rate ----
pb = boot()
start_game(pb)
wr(pb, "wSpawnT", 255)
def load_up():
    for i in range(12):
        put_enemy(pb, i, 20 + i * 10, 20 + (i % 5) * 18, typ=2, vx=0x40, vy=-0x40)
    pa = addr(pb, "wParts")
    for i in range(12):
        for j, v in enumerate([200, 30 + i * 8, 100, 0, 0, 72]):
            pb.memory[pa + i * 6 + j] = v
    wr(pb, "wPX", 8, 1); wr(pb, "wPY", 112, 1)
settle(pb, load_up)
f0 = rd(pb, "wFrame"); pb.tick(60); f1 = rd(pb, "wFrame")
check((f1 - f0) & 0xFF == 60, f"12 chasers + 12 particles: 60 game frames in 60 LCD frames (got {(f1 - f0) & 0xFF})")
wr(pb, "wLevel", 2); wr(pb, "wKillsLvl", 5)
settle(pb, lambda: (clear_enemies(pb), wr(pb, "wFaceX", 1), wr(pb, "wFaceY", 0), wr(pb, "wDashCD", 0), wr(pb, "wPX", 72, 1), wr(pb, "wPY", 60, 1)))
put_enemy(pb, 0, 100, 64); pb.button("a"); pb.tick(100)
wr(pb, "wSpawnT", 255)
settle(pb, load_up)
f0 = rd(pb, "wFrame"); pb.tick(60); f1 = rd(pb, "wFrame")
check(rd(pb, "wBoss") == 2 and (f1 - f0) & 0xFF == 60, f"same load with the Warden live: 60/60 (got {(f1 - f0) & 0xFF}, boss {rd(pb, 'wBoss')})")
pb.stop(save=False)

# ---- 8: soak with random input: no crash, no stack creep ----
rng = random.Random(7)
pb = boot()
start_game(pb)
buttons = ["a", "left", "right", "up", "down", "start"]
frames_ok = True
for i in range(12000):
    if i % 6 == 0:
        b = rng.choice(buttons[:5] if rng.random() < 0.97 else buttons)
        pb.button(b, 3)
    before = rd(pb, "wFrame")
    pb.tick()
    if i % 600 == 599:
        pc = pb.register_file.PC
        sp = pb.register_file.SP
        if not (pc < 0x8000 or 0xFF80 <= pc) or not (0xDF00 <= sp <= 0xE000):
            frames_ok = False
            print("bad state", hex(pc), hex(sp))
            break
f1 = rd(pb, "wFrame"); pb.tick(5); f2 = rd(pb, "wFrame")
check(frames_ok and f1 != f2, "12000 frames of random input: PC/SP sane, main loop alive")
pb.stop(save=False)

print("\n%d failure(s)" % len(fails))
sys.exit(1 if fails else 0)
