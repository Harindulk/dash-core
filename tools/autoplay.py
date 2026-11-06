"""Deterministic autoplayer for DASH CORE footage: chains enemies, breaks the Warden's
nodes, dodges the beam, restarts after game over. decide() returns the d-pad set to hold."""

SV = lambda lo, hi: (lo | hi << 8) - (65536 if hi & 0x80 else 0)


def flee(t):
    d, dx, dy, k = t
    return {"left" if dx > 0 else "right", "up" if dy > 0 else "down"}


def aim(pb, t):
    """press A and return the d-pad that points the dash at t"""
    d, dx, dy, k = t
    pb.button("a")
    if abs(dx) <= 4:
        return {"down" if dy > 0 else "up"}
    if abs(dy) <= 4:
        return {"right" if dx > 0 else "left"}
    return {"right" if dx > 0 else "left", "down" if dy > 0 else "up"}


def decide(pb, A, M, over_frames=999):
    if not M[A("wAlive")]:
        if M[A("wOver")] and M[A("wWY")] == 56 and over_frames >= 150:
            pb.button("start")
        return set()
    px, py = M[A("wPX") + 1] + 8, M[A("wPY") + 1] + 8
    dash, cd = M[A("wDash")], M[A("wDashCD")]
    ready = dash == 0 and cd == 0
    if dash:                    # the d-pad steers a dash every frame: hold still so it flies straight
        return set()
    boss, node, beam, brow = M[A("wBoss")], M[A("wBossOpen")], M[A("wBossBeam")], M[A("wBossBeamRow")]
    foes, marks = [], []
    for i in range(12):
        b = A("wEnemies") + i * 16
        t = M[b]
        if t in (1, 2, 4):
            vx, vy = SV(M[b + 6], M[b + 7]) / 256, SV(M[b + 8], M[b + 9]) / 256
            ex, ey = M[b + 3] + 4 + vx * 6, M[b + 5] + 4 + vy * 6
            foes.append((abs(ex - px) + abs(ey - py), ex - px, ey - py, t))
        elif t == 3 and M[b + 1] >= 14:          # about to hatch: a hazard, not a target
            ex, ey = M[b + 3] + 4, M[b + 5] + 4
            marks.append((abs(ex - px) + abs(ey - py), ex - px, ey - py, t))
    foes.sort(); marks.sort()

    def threat(rf, rm):
        c = [t for t in foes[:1] if t[0] < rf] + [t for t in marks[:1] if t[0] < rm]
        return min(c) if c else None

    # 1. beam: the game kills within 11 px of the row centre; get 15 px clear (a dash is safe too)
    if beam and boss == 2:
        dyb = py - (brow * 8 + 4)
        if abs(dyb) < 15:
            if beam == 2 and ready:
                pb.button("a")
                return {"left" if px > 80 else "right"}
            return {"up" if dyb < 0 else "down"}
    # 2. an open node: it is the priority; only an imminent threat interrupts
    if boss == 2 and node != 0xFF:
        nx = 60 + node * 24
        dx = nx - px
        t = threat(18, 14)
        if t:
            if ready and t[3] != 3:
                return aim(pb, t)
            return flee(t)
        if abs(dx) > 2:
            want = {"right" if dx > 0 else "left"}
            if py < 60: want.add("down")
            if py > 76: want.add("up")
            return want
        if ready and py < 92:
            pb.button("a")
        return {"up"}
    # 3. open play
    t = threat(30, 24)
    if t and (t[3] == 3 or not ready):
        return flee(t)
    if boss == 2 and py < 44:    # keep clear of the hull while the nodes are shut
        return {"down"}
    if not foes:
        want = set()
        if px < 70: want.add("right")
        if px > 90: want.add("left")
        if py < 60: want.add("down")
        if py > 80: want.add("up")
        return want
    d, dx, dy, k = foes[0]
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
