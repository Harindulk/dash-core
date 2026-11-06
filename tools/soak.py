"""50-round soak test: plays the real ROM headless and checks invariants every frame.
Rounds 0-29 autoplayer, 30-39 autoplayer with 25% random input, 40-49 random mashing.
Usage: python tools/soak.py build/dashcore.gb [rounds]"""
import io
import os
import random
import sys
from multiprocessing import Pool

from pyboy import PyBoy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from autoplay import decide, apply

ROM = sys.argv[1]
ROUNDS = int(sys.argv[2]) if len(sys.argv) > 2 else 50
MAX_PLAY = 120 * 60                       # 2 minutes of play per round
BTN = ["up", "down", "left", "right", "a", "b", "start", "select"]


def bcd(M, a):
    v = (M[a + 2], M[a + 1], M[a])
    ok = all((b >> 4) < 10 and (b & 15) < 10 for b in v)
    return int("".join(f"{b:02X}" for b in v)) if ok else -1


def run(r):
    rng = random.Random(r)
    mode = "auto" if r < 30 else "noisy" if r < 40 else "random"
    ramf = io.BytesIO(bytes(8192))
    pb = PyBoy(ROM, window="null", symbols=ROM[:-3] + ".sym", sound_emulated=False, ram_file=ramf)
    pb.set_emulation_speed(0)
    A = lambda n: pb.symbol_lookup(n)[1]
    M = pb.memory
    bugs, held = [], set()
    pb.tick(120 + rng.randrange(400), False)      # vary the DIV seed
    pb.button("start"); pb.tick(30, False)
    parked = dict(n_en=0, f=0)

    def check(_):
        # runs when the game loop parks in WaitVBlank: all logic for the frame is done
        f = parked["f"]
        if parked.get("done") == f:            # halt wakes on every HBlank interrupt; check once per frame
            return
        parked["done"] = f
        pc, sp = pb.register_file.PC, pb.register_file.SP
        if not (0xC000 <= sp <= 0xE000): bug(f"SP out of WRAM: {sp:04X}")
        alive, boss = M[A("wAlive")], M[A("wBoss")]
        px, py, top = M[A("wPX") + 1], M[A("wPY") + 1], M[A("wTopY")]
        moving = alive and not M[A("wFreeze")] and not M[A("wPaused")]   # hit-stop/pause hold the player still
        if moving and not (8 <= px <= 136 and top <= py <= 112): bug(f"player out of arena {px},{py} (top {top})")
        lvl, combo = M[A("wLevel")], M[A("wCombo")]
        if not 0 <= lvl <= 9: bug(f"level {lvl}")
        if not 1 <= combo <= 9: bug(f"combo {combo}")
        if boss > 3: bug(f"boss state {boss}")
        if M[A("wBossNodes")] > 7: bug(f"boss nodes {M[A('wBossNodes')]:02X}")
        if bcd(M, A("wScore")) < 0: bug("score not valid BCD")
        n = 0
        for i in range(12):
            b = A("wEnemies") + i * 16
            t = M[b]
            if t > 3: bug(f"enemy {i} type {t}")
            if t:
                n += 1
                ex, ey = M[b + 3], M[b + 5]
                if not (0 <= ex <= 160 and 0 <= ey <= 136): bug(f"enemy {i} at {ex},{ey}")
        parked["n_en"] = n

    # the instruction right after WaitVBlank's halt loop (halt, nop, ld a,[nn], and a, jr z = 8 bytes):
    # runs once per frame, after the frame's logic and before the next frame's
    pb.hook_register(0, pb.symbol_lookup("WaitVBlank")[1] + 8, check, None)
    stats = dict(mode=mode, frames=0, level=0, boss_kills=0, deaths=0, lag=0, score=0, best=0)
    last_boss, empty_t, dash_t, over_t, restarts = 0, 0, 0, 0, 0
    def bug(msg):
        if len(bugs) < 8: bugs.append(f"f{stats['frames']}: {msg}")
    for f in range(MAX_PLAY):
        stats["frames"] = f
        alive, over = M[A("wAlive")], M[A("wOver")]
        if mode == "random" or (mode == "noisy" and rng.random() < 0.25):
            want = {b for b in BTN[:6] if rng.random() < 0.3}
            if rng.random() < 0.004: want.add("start")
            held = apply(pb, held, want)
        else:
            held = apply(pb, held, decide(pb, A, M, over_t))
        if M[A("wPaused")] and rng.random() < 0.05:
            held = apply(pb, held, set()); pb.button("start")
        parked["f"] = f
        fr0 = M[A("wFrame")]
        pb.tick(1, False)
        pc = pb.register_file.PC
        if not (pc < 0x8000 or pc >= 0xFF80): bug(f"PC out of ROM/HRAM: {pc:04X}")
        alive, over, boss = M[A("wAlive")], M[A("wOver")], M[A("wBoss")]
        lvl, sc = M[A("wLevel")], bcd(M, A("wScore"))
        if M[A("wFrame")] == fr0 and not M[A("wPaused")]:
            stats["lag"] += 1
        n_en = parked["n_en"]
        empty_t = empty_t + 1 if (alive and n_en == 0 and boss == 0) else 0
        if empty_t == 900: bug("15 s alive with no enemies and no boss (spawner stuck?)")
        dash_t = dash_t + 1 if M[A("wDash")] else 0
        if dash_t == 180: bug("dash lasted 3 s (stuck dash?)")
        if boss == 3 and last_boss != 3: stats["boss_kills"] += 1
        last_boss = boss
        stats["level"] = max(stats["level"], lvl)
        if sc > stats["score"]: stats["score"] = sc
        # ---- game over and restart ----
        over_t = over_t + 1 if over else 0
        if over_t == 1:
            stats["deaths"] += 1
            best = bcd(M, A("wBest"))
            stats["best"] = best
            if best < sc: bug(f"best {best} < score {sc} at game over")
        if over_t == 400 and mode != "auto":             # restart by hand for non-auto rounds
            held = apply(pb, held, set()); pb.button("start")
        if over_t > 900: bug("game over panel never accepted START"); break
    # ---- SRAM survives a power cycle ----
    held = apply(pb, held, set())
    best_mem = bcd(M, A("wBest"))
    out = io.BytesIO()
    pb.stop(save=True, ram_file=out)              # PyBoy writes SRAM only to the file given to stop()
    pb2 = PyBoy(ROM, window="null", symbols=ROM[:-3] + ".sym", sound_emulated=False,
                ram_file=io.BytesIO(out.getvalue()))
    pb2.tick(200, False)
    best2 = bcd(pb2.memory, pb2.symbol_lookup("wBest")[1])
    pb2.stop(save=False)
    saved = out.getvalue()
    if best2 != best_mem: bug(f"best {best_mem} became {best2} after a power cycle (sram {len(saved)} bytes, head {saved[:8].hex()})")
    return r, stats, bugs, best_mem


if __name__ == "__main__":
    with Pool(min(8, os.cpu_count() or 4)) as p:
        res = sorted(p.map(run, range(int(sys.argv[3]) if len(sys.argv) > 3 else 0, ROUNDS)))
    allbugs = 0
    for r, s, bugs, best in res:
        flag = "BUG" if bugs else "ok "
        print(f"{flag} round {r:2d} {s['mode']:6s} lvl {s['level']+1} boss_kills {s['boss_kills']} deaths {s['deaths']} "
              f"best {s['best']:6d} lag {s['lag']:3d}")
        for b in bugs:
            print("      ", b)
        allbugs += len(bugs)
    lv = [s["level"] + 1 for _, s, _, _ in res]
    print(f"\n{ROUNDS} rounds, {allbugs} invariant failures; levels reached: max {max(lv)}, "
          f"rounds reaching the Warden (level 4+): {sum(l >= 4 for l in lv)}, boss kills total {sum(s['boss_kills'] for _, s, _, _ in res)}")
