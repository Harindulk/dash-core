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
start_game(pb)
check(rd(pb, "wAlive") == 1, "game starts, player alive")
check(rd(pb, "wPX", 1) == 72, "player spawned at centre")

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
