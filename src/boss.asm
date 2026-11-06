; ---------------------------------------------------------------
; WARDEN: the boss. A 7x3-tile machine drawn on the background at the
; top of the arena (levels 3, 6, 9). Three nodes on its underside open
; one at a time; a dash into an open node breaks it. It spits drifters
; in a line under a node and fires a beam across the player's row.
; Every BG change goes through the one-slot VBlank copy queue, so each
; routine writes at most one tile run per frame and retries if busy.
; ---------------------------------------------------------------
DEF BOSS_MAP    EQU _SCRN0 + 1 * 32 + 7
DEF BOSS_TOPY   EQU 32          ; player/enemy clamp while the boss is up
DEF NODE_OPEN_T EQU 120
DEF NODE_SHUT_T EQU 40
DEF SPIT_T      EQU 150
DEF BEAM_T      EQU 240
DEF BEAM_WARN_T EQU 45
DEF BEAM_FIRE_T EQU 14

DEF BS_NONE  EQU 0
DEF BS_ENTER EQU 1
DEF BS_LIVE  EQU 2
DEF BS_DIE   EQU 3

SECTION "BossCode", ROM0

; a = new level; the boss comes at 3, 6 and 9
BossMaybeStart:
    cp 3
    jr z, .go
    cp 6
    jr z, .go
    cp 9
    ret nz
.go
    ld a, [wBoss]
    and a
    ret nz
    ld a, BS_ENTER
    ld [wBoss], a
    xor a
    ld [wBossStep], a
    ld [wBossT], a
    ld [wBossBeam], a
    ld a, 7
    ld [wBossNodes], a
    ld a, 2
    ld [wBossNext], a
    ld a, $FF
    ld [wBossOpen], a
    ld a, 60
    ld [wBossOpenT], a
    ld a, SPIT_T
    ld [wBossAtk], a
    ld a, BEAM_T
    ld [wBossBeamT], a
    ld a, BOSS_TOPY
    ld [wTopY], a
    ld hl, TxtWarden
    call SetBanner
    ld hl, SongBoss
    jp MusicPlay

; hl = 20-char text
SetBanner:
    ld a, l
    ld [wBannerTxt], a
    ld a, h
    ld [wBannerTxt+1], a
    xor a
    ld [wBannerLvl], a
    ld a, 120
    ld [wBanner], a
    ret

UpdateBoss:
    ld a, [wBoss]
    and a
    ret z
    cp BS_ENTER
    jr z, BossEnter
    cp BS_DIE
    jp z, BossDie
    ; ---- live ----
    ld a, [wFrame]
    and 15
    jr nz, .noEye
    ld a, [wCopyLen]
    and a
    jr nz, .noEye
    ld a, [wFrame]
    and 16
    ld a, T_BOSS_EYE
    jr z, .eye
    inc a
.eye
    ld de, BOSS_MAP + 32 + 3
    call BossTile
.noEye
    call BossNodes
    call BossBeam
    call BossSpit
    jp BossHitTest

; draw one row per frame, then an alarm pause
BossEnter:
    ld a, [wBossStep]
    cp 3
    jr nc, .wait
    ld b, a
    ld a, [wCopyLen]
    and a
    ret nz
    ld a, b
    call BossRowAddr
    ld a, b
    add a
    add a
    add a
    sub b                       ; row * 7
    add LOW(BossRows)
    ld l, a
    ld a, 0
    adc HIGH(BossRows)
    ld h, a
    ld a, 7
    call QueueCopy
    ld hl, wBossStep
    inc [hl]
    ld a, [hl]
    cp 3
    ret nz
    ld a, 40
    ld [wBossT], a
    ld a, 12
    call AddShake
    ld a, 8
    ld [wFlash], a
    ld a, FLASH_CYCLE
    ld [wFlashKind], a
    ld a, 80
    call SetPan
    jp SfxAlarm
.wait
    ld hl, wBossT
    dec [hl]
    ret nz
    ld a, BS_LIVE
    ld [wBoss], a
    ret

; open/close cycle of the nodes, plus the open node's blink
BossNodes:
    ld hl, wBossOpenT
    dec [hl]
    jr nz, .blink
    ld a, [wCopyLen]
    and a
    jr z, .free
    inc [hl]                    ; queue busy: retry next frame
    ret
.free
    ld a, [wBossOpen]
    cp $FF
    jr z, .openNext
    call NodeAddr
    ld a, T_NODE_CLOSED
    call BossTile
    ld a, $FF
    ld [wBossOpen], a
    ld a, NODE_SHUT_T
    ld [wBossOpenT], a
    ret
.openNext
    ld a, [wBossNext]
    ld b, 3
.find
    inc a
    cp 3
    jr c, .in
    xor a
.in ld c, a
    call BitOf
    ld d, a
    ld a, [wBossNodes]
    and d
    ld a, c
    jr nz, .found
    dec b
    jr nz, .find
    ret
.found
    ld [wBossNext], a
    ld [wBossOpen], a
    call NodeAddr
    ld a, T_NODE_OPEN
    call BossTile
    ld a, NODE_OPEN_T
    ld [wBossOpenT], a
    ret
.blink
    ld a, [wBossOpen]
    cp $FF
    ret z
    ld a, [wFrame]
    and 7
    ret nz
    ld a, [wCopyLen]
    and a
    ret nz
    ld a, [wBossOpen]
    call NodeAddr
    ld a, [wFrame]
    and 8
    ld a, T_NODE_OPEN
    jr z, .t
    inc a
.t  jp BossTile

; beam: warn at the player's row, fire across it, clear it
BossBeam:
    ld a, [wBossBeam]           ; 0 idle, 1 warn, 2 fire
    and a
    jr nz, .active
    ld hl, wBossBeamT
    dec [hl]
    ret nz
    ld a, [wCopyLen]
    and a
    jr z, .start
    inc [hl]
    ret
.start
    ld a, [wPY + 1]
    add 8
    srl a
    srl a
    srl a                       ; row of the player's centre
    cp 5
    jr nc, .r1
    ld a, 5
.r1 cp 15
    jr c, .r2
    ld a, 14
.r2 ld [wBossBeamRow], a
    ld a, 1
    ld [wBossBeam], a
    ld a, BEAM_WARN_T
    ld [wBossBeamT], a
    ld hl, wCopyBuf
    ld a, T_BEAM_WARN
    ld [hl+], a
    ld a, T_FLOOR
    ld b, 16
.fw ld [hl+], a
    dec b
    jr nz, .fw
    ld a, T_BEAM_WARN
    ld [hl], a
    jr .queueRow
.active
    cp 2
    jr nz, .tick
    ; firing: a player in the row who is not dashing dies
    ld a, [wAlive]
    and a
    jr z, .tick
    ld a, [wDash]
    ld b, a
    ld a, [wGrace]
    or b
    jr nz, .tick
    ld a, [wBossBeamRow]
    add a
    add a
    add a
    add 4
    ld b, a
    ld a, [wPY + 1]
    add 8
    call AbsDiff
    cp 11
    call c, PlayerDie
.tick
    ld hl, wBossBeamT
    dec [hl]
    ret nz
    ld a, [wCopyLen]
    and a
    jr z, .adv
    inc [hl]
    ret
.adv
    ld a, [wBossBeam]
    cp 1
    jr z, .fire
    xor a
    ld [wBossBeam], a
    ld a, BEAM_T
    ld [wBossBeamT], a
    ld a, T_FLOOR
    jr .fillRow
.fire
    ld a, 2
    ld [wBossBeam], a
    ld a, BEAM_FIRE_T
    ld [wBossBeamT], a
    ld a, 10
    call AddShake
    ld a, 80
    call SetPan
    call SfxBeam
    ld a, T_BEAM
.fillRow
    ld hl, wCopyBuf
    ld b, 18
.fr ld [hl+], a
    dec b
    jr nz, .fr
.queueRow
    ld a, [wBossBeamRow]
    ld h, 0
    ld l, a
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    ld de, _SCRN0 + 1
    add hl, de
    ld d, h
    ld e, l
    ld hl, wCopyBuf
    ld a, 18
    jp QueueCopy

; three drifters in a line under a node, every SPIT_T frames
BossSpit:
    ld hl, wBossAtk
    dec [hl]
    ret nz
    ld [hl], SPIT_T
    ld a, [wBossOpen]
    cp $FF
    jr nz, .n
    ld a, 1
.n  call NodeX
    ld b, a
    ld c, 40
    call PlaceDrifter
    ld c, 56
    call PlaceDrifter
    ld c, 72
    ; fall through

; b = x, c = y: a drifter (after the usual warning) heading down
PlaceDrifter:
    push bc
    ld hl, wEnemies
    ld de, EN_SIZE
    ld a, MAX_EN
.f  push af
    ld a, [hl]
    and a
    jr z, .got
    add hl, de
    pop af
    dec a
    jr nz, .f
    pop bc
    ret
.got
    pop af
    pop bc
    ld a, ET_SPAWN
    ld [hl+], a
    xor a
    ld [hl+], a                 ; timer
    ld [hl+], a
    ld a, b
    ld [hl+], a                 ; x
    xor a
    ld [hl+], a
    ld a, c
    ld [hl+], a                 ; y
    ld a, [wFrame]
    and 1
    jr z, .right
    ld a, $A0
    ld [hl+], a
    ld a, $FF
    ld [hl+], a
    jr .vy
.right
    ld a, $60
    ld [hl+], a
    xor a
    ld [hl+], a
.vy
    ld a, $50
    ld [hl+], a
    xor a
    ld [hl+], a
    ld a, ET_DRIFT
    ld [hl], a
    ret

; a dash into the open node breaks it
BossHitTest:
    ld a, [wBossOpen]
    cp $FF
    ret z
    ld a, [wDash]
    and a
    ret z
    ld a, [wPY + 1]
    cp BOSS_TOPY + 2
    ret nc                      ; not touching the underside
    ld a, [wBossOpen]
    call NodeX
    add 4
    ld b, a
    ld a, [wPX + 1]
    add 8
    call AbsDiff
    cp 10
    ret nc
    ld a, [wCopyLen]
    and a
    ret nz                      ; retry next frame (the dash lasts several)
    ld a, [wBossOpen]
    call NodeAddr
    ld a, T_NODE_BROKEN
    call BossTile
    ld a, [wBossOpen]
    call BitOf
    cpl
    ld b, a
    ld a, [wBossNodes]
    and b
    ld [wBossNodes], a
    ld a, [wBossOpen]
    call NodeX
    ld b, a
    ld a, $FF
    ld [wBossOpen], a
    ld a, NODE_SHUT_T
    ld [wBossOpenT], a
    ; juice: burst, score 100 x combo, chain grows, stop, shake, wave, palette
    ld c, 28
    push bc
    ld hl, BurstKill
    call Burst
    ld a, [wCombo]
    ld hl, wScore + 1
    add [hl]
    daa
    ld [hl+], a
    ld a, [hl]
    adc 0
    daa
    ld [hl], a
    ld a, [wCombo]
    cp 9
    jr nc, .maxed
    inc a
    ld [wCombo], a
.maxed
    ld hl, wDashKills
    inc [hl]
    ld a, DASH_MAX
    ld [wDash], a
    ld a, 8
    ld [wFreeze], a
    ld a, 14
    call AddShake
    ld a, 3
    ld b, 8
    call StartWave
    ld a, 8
    ld [wFlash], a
    ld a, FLASH_CYCLE
    ld [wFlashKind], a
    pop bc
    ld a, b
    call SetPan
    call SfxBossHit
    ld a, [wBossNodes]
    and a
    ret nz
    ; all three broken: the Warden goes down
    ld a, BS_DIE
    ld [wBoss], a
    xor a
    ld [wBossStep], a
    ld a, 64
    ld [wBossT], a
    ld a, 12
    ld [wFreeze], a
    ld a, 30
    ld [wShake], a
    ld a, 3
    ld b, 12
    call StartWave
    ld a, 20
    ld [wFlash], a
    xor a
    ld [wFlashKind], a
    ; bonus: level x 1000
    ld a, [wLevel]
    swap a
    ld hl, wScore + 1
    add [hl]
    daa
    ld [hl+], a
    ld a, [hl]
    adc 0
    daa
    ld [hl], a
    ld hl, TxtWardenDown
    call SetBanner
    ld a, 80
    call SetPan
    call SfxBossDie
    ld hl, SongWin
    jp MusicPlay

; explosions over the hull, then erase it row by row
BossDie:
    ld hl, wBossT
    ld a, [hl]
    and a
    jr z, .erase
    dec [hl]
    and 7
    ret nz
    call Rand
    and 63
    add 56
    ld b, a
    call Rand
    and 15
    add 8
    ld c, a
    ld hl, BurstKill
    call Burst
    ld a, 8
    jp AddShake
.erase
    ld a, [wCopyLen]
    and a
    ret nz
    ld a, [wBossStep]
    cp 3
    jr z, .gone
    ld b, a
    call BossRowAddr
    ld hl, wCopyBuf
    ld a, T_FLOOR
    ld c, 7
.f  ld [hl+], a
    dec c
    jr nz, .f
    ld hl, wCopyBuf
    ld a, 7
    call QueueCopy
    ld hl, wBossStep
    inc [hl]
    ret
.gone
    xor a
    ld [wBoss], a
    ld a, 8
    ld [wTopY], a
    ret

; ---- helpers ----
; a = tile, de = map address: queue a one-byte write
BossTile:
    ld [wCopyBuf], a
    ld hl, wCopyBuf
    ld a, 1
    jp QueueCopy

; a = row 0..2 -> de = map address of the row's first tile
BossRowAddr:
    ld h, 0
    ld l, a
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    ld de, BOSS_MAP
    add hl, de
    ld d, h
    ld e, l
    ret

; a = node 0..2 -> de = its map address (bottom row, every third tile)
NodeAddr:
    ld e, a
    add a
    add e
    add LOW(BOSS_MAP + 64)
    ld e, a
    ld a, 0
    adc HIGH(BOSS_MAP + 64)
    ld d, a
    ret

; a = node 0..2 -> a = its left x in pixels (56, 80, 104)
NodeX:
    ld e, a
    add a
    add e                       ; x3
    add a
    add a
    add a                       ; x24
    add 56
    ret

; a = 0..7 -> a = 1 << a
BitOf:
    ld b, a
    ld a, 1
    inc b
.s  dec b
    ret z
    add a
    jr .s

BossRows:
    db T_BOSS_VENT, T_BOSS_VENT, T_BOSS_VENT, T_BOSS_VENT, T_BOSS_VENT, T_BOSS_VENT, T_BOSS_VENT
    db T_BOSS_HULL, T_BOSS_HULL, T_BOSS_HULL, T_BOSS_EYE, T_BOSS_HULL, T_BOSS_HULL, T_BOSS_HULL
    db T_NODE_CLOSED, T_BOSS_HULL, T_BOSS_HULL, T_NODE_CLOSED, T_BOSS_HULL, T_BOSS_HULL, T_NODE_CLOSED

TxtWarden:     db "   -- WARDEN --     ", STR_END
TxtWardenDown: db "    WARDEN DOWN!    ", STR_END
