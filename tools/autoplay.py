"""Deterministic autoplayer for DASH CORE footage: chains enemies, breaks the Warden's
nodes, dodges the beam, restarts after game over. decide() returns the d-pad set to hold."""

SV = lambda lo, hi: (lo | hi << 8) - (65536 if hi & 0x80 else 0)


def decide(pb, A, M):
    if not M[A("wAlive")]:
        if M[A("wOver")] and M[A("wWY")] == 56:
            pb.button("start")
        return set()
    px, py = M[A("wPX") + 1] + 8, M[A("wPY") + 1] + 8
    dash, cd = M[A("wDash")], M[A("wDashCD")]
    ready = dash == 0 and cd == 0
    if dash:                    # the d-pad steers a dash every frame: hold still so it flies straight
        return set()
    boss, node, beam, brow = M[A("wBoss")], M[A("wBossOpen")], M[A("wBossBeam")], M[A("wBossBeamRow")]
    # enemies: active ones, and markers about to hatch
    foes, marks = [], []
    for i in range(12):
        b = A("wEnemies") + i * 16
        t = M[b]
        if t in (1, 2):
            vx, vy = SV(M[b + 6], M[b + 7]) / 256, SV(M[b + 8], M[b + 9]) / 256
            ex, ey = M[b + 3] + 4 + vx * 6, M[b + 5] + 4 + vy * 6
            foes.append((abs(ex - px) + abs(ey - py), ex - px, ey - py, t))
        elif t == 3 and M[b + 1] >= 14:          # about to hatch: a hazard, not a target
            ex, ey = M[b + 3] + 4, M[b + 5] + 4
            marks.append((abs(ex - px) + abs(ey - py), ex - px, ey - py, t))
    foes.sort(); marks.sort()
    near = foes[0] if foes and foes[0][0] < 30 else None
    if marks and marks[0][0] < 24 and (near is None or marks[0][0] < near[0]):
        near = marks[0]
    # 1. beam: leave the row (a dash is also safe)
    if beam and abs((py >> 3) - brow) <= 1:
        if beam == 2 and ready:
            pb.button("a")
            return {"left" if px > 80 else "right"}
        return {"down"} if brow < 11 else {"up"}
    # 2. an open node: line up under it and dash up (unless something is on top of us)
    if boss == 2 and node != 0xFF and near is None:
        nx = 60 + node * 24
        dx = nx - px
        want = set()
        if abs(dx) > 2:
            want.add("right" if dx > 0 else "left")
            if py < 56: want.add("down")
            if py > 76: want.add("up")
        else:
            want.add("up")
            if ready and py < 90:
                pb.button("a")
        return want
    if near and (near[3] == 3 or not ready):
        d, dx, dy, t = near          # hazard close and no dash: step away
        return {"left" if dx > 0 else "right", "up" if dy > 0 else "down"}
    if not foes:
        # drift back to the middle
        want = set()
        if px < 70: want.add("right")
        if px > 90: want.add("left")
        if py < 60: want.add("down")
        if py > 80: want.add("up")
        return want
    d, dx, dy, t = foes[0]
    H = "right" if dx > 0 else "left"
    V = "down" if dy > 0 else "up"
    if ready:
        if abs(dx) <= 3 and abs(dy) < 70:
            pb.button("a"); return {V}
        if abs(dy) <= 3 and abs(dx) < 70:
            pb.button("a"); return {H}
        if abs(abs(dx) - abs(dy)) <= 4 and abs(dx) < 50:
            pb.button("a"); return {H, V}
        if abs(dx) < abs(dy):
            want = {H}
            if abs(dy) > 72: want.add(V)
        else:
            want = {V}
            if abs(dx) > 72: want.add(H)
        return want
    return set()


def apply(pb, held, want):
    for k in held - want:
        pb.button_release(k)
    for k in want - held:
        pb.button_press(k)
    return want
