; ---------------------------------------------------------------
; Sound: tiny pattern tracker (CH2 melody, CH3 wave bass)
; SFX use CH1 (square+sweep) and CH4 (noise) so they never fight the music.
; Song format: db speed, duty, envelope
;              then entries: dw melodyPattern, bassPattern  (16 steps each)
;              dw 0 = loop to first entry, dw 1 = stop
; Step bytes: HOLD (0) keep, OFF (1) note off, else note code
; ---------------------------------------------------------------
SECTION "SoundCode", ROM0

SoundInit:
    ld a, $80
    ldh [rNR52], a
    ld a, $77
    ldh [rNR50], a
    ld a, $FF
    ldh [rNR51], a
    xor a
    ldh [rNR30], a              ; DAC off before writing wave RAM
    ld hl, WaveData
    ld de, _WAVE
    ld c, 16
.w  ld a, [hl+]
    ld [de], a
    inc de
    dec c
    jr nz, .w
    ret

; hl = song
MusicPlay:
    xor a
    ld [wMusOn], a              ; tick ignores us while we set up
    ld a, [hl+]
    ld [wMusSpeed], a
    ld a, [hl+]
    ld [wMelDuty], a
    ld a, [hl+]
    ld [wMelEnv], a
    ld a, l
    ld [wMusStart], a
    ld [wMusOrd], a
    ld a, h
    ld [wMusStart+1], a
    ld [wMusOrd+1], a
    xor a
    ld [wMusRow], a
    inc a
    ld [wMusTick], a
    call MusLoadEntry
    ret z
    ld a, 1
    ld [wMusOn], a
    ret

MusicStop:
    xor a
    ld [wMusOn], a
MusSilence:
    xor a
    ldh [rNR22], a
    ldh [rNR30], a
    ret

; returns nz = playing, z = song ended
MusLoadEntry:
    ld a, [wMusOrd]
    ld l, a
    ld a, [wMusOrd+1]
    ld h, a
    ld a, [hl+]
    ld e, a
    ld a, [hl+]
    ld d, a
    or e
    jr nz, .notLoop
    ld a, [wMusStart]
    ld [wMusOrd], a
    ld l, a
    ld a, [wMusStart+1]
    ld [wMusOrd+1], a
    ld h, a
    ld a, [hl+]
    ld e, a
    ld a, [hl+]
    ld d, a
.notLoop
    ld a, d
    and a
    jr nz, .ok
    ld a, e
    cp 1
    jr nz, .ok
    call MusicStop
    xor a                       ; z
    ret
.ok
    ld a, e
    ld [wMusMel], a
    ld a, d
    ld [wMusMel+1], a
    ld a, [hl+]
    ld [wMusBass], a
    ld a, [hl]
    ld [wMusBass+1], a
    or 1                        ; nz
    ret

; called from the VBlank handler
MusicTick:
    ld a, [wMusOn]
    and a
    ret z
    ld hl, wMusTick
    dec [hl]
    ret nz
    ld a, [wMusSpeed]
    ld [hl], a
    ld a, [wMusRow]
    ld c, a
    ld a, [wMusMel]
    add c
    ld l, a
    ld a, [wMusMel+1]
    adc 0
    ld h, a
    ld a, [hl]
    call PlayMel
    ld a, [wMusRow]
    ld c, a
    ld a, [wMusBass]
    add c
    ld l, a
    ld a, [wMusBass+1]
    adc 0
    ld h, a
    ld a, [hl]
    call PlayBass
    ld a, [wMusRow]
    inc a
    and 15
    ld [wMusRow], a
    ret nz
    ld hl, wMusOrd
    ld a, [hl]
    add 4
    ld [hl+], a
    ld a, [hl]
    adc 0
    ld [hl], a
    jp MusLoadEntry

PlayMel:
    and a
    ret z
    cp OFF
    jr nz, .note
    xor a
    ldh [rNR22], a
    ret
.note
    call NoteFreq
    ld a, [wMelDuty]
    ldh [rNR21], a
    ld a, [wMelEnv]
    ldh [rNR22], a
    ld a, e
    ldh [rNR23], a
    ld a, d
    or $80
    ldh [rNR24], a
    ret

PlayBass:
    and a
    ret z
    cp OFF
    jr nz, .note
    xor a
    ldh [rNR30], a
    ret
.note
    call NoteFreq
    xor a                       ; DAC off first: avoids DMG wave RAM corruption on retrigger
    ldh [rNR30], a
    ld a, $80
    ldh [rNR30], a
    ld a, $20                   ; full volume
    ldh [rNR32], a
    ld a, e
    ldh [rNR33], a
    ld a, d
    or $80
    ldh [rNR34], a
    ret

; a = note code (>= 2) -> de = frequency register value
NoteFreq:
    sub 2
    add a
    add LOW(NoteTable)
    ld l, a
    ld a, 0
    adc HIGH(NoteTable)
    ld h, a
    ld a, [hl+]
    ld e, a
    ld d, [hl]
    ret

; ---------------- sound effects ----------------
; a = x position (0..160) -> NR51: SFX channels (1, 4) pan with the event; music (2, 3) stays centred
SetPan:
    cp 56
    jr c, .left
    cp 104
    jr nc, .right
    ld a, $FF
    jr .set
.left
    ld a, %11110110
    jr .set
.right
    ld a, %01101111
.set
    ldh [rNR51], a
    ret

; CH1 one-shot: a = NR10, then NR11/NR12 from b/c, de = freq
Ch1Shot:
    ldh [rNR10], a
    ld a, b
    ldh [rNR11], a
    ld a, c
    ldh [rNR12], a
    ld a, e
    ldh [rNR13], a
    ld a, d
    or $80
    ldh [rNR14], a
    ret

; a = NR42 envelope, b = NR43 noise
NoiseShot:
    ldh [rNR42], a
    ld a, b
    ldh [rNR43], a
    ld a, $80
    ldh [rNR44], a
    ret

SfxDash:
    ld b, $80
    ld c, $F1
    ld de, $0400
    ld a, $14                   ; fast upward sweep: a "zip"
    call Ch1Shot
    ld a, $61
    ld b, $11                   ; short airy hiss
    jp NoiseShot

; a = combo (1..9): pitch climbs with the chain
SfxKill:
    dec a
    add a
    add E5
    call NoteFreq
    ld b, $80
    ld c, $C2
    xor a
    call Ch1Shot
    ld a, $C2
    ld b, $51                   ; crunch
    jp NoiseShot

SfxReady:
    ld a, A6
    call NoteFreq
    ld b, $40
    ld c, $51
    xor a
    jp Ch1Shot

SfxDeath:
    ld b, $80
    ld c, $F4
    ld de, $0700
    ld a, $2D                   ; slow downward sweep
    call Ch1Shot
    ld a, $F5
    ld b, $72                   ; low rumble
    jp NoiseShot

SfxStart:
    ld b, $80
    ld c, $F3
    ld de, $0600
    ld a, $25
    jp Ch1Shot

SfxLevel:
    ld a, E6
    call NoteFreq
    ld b, $80
    ld c, $A3
    ld a, $16
    jp Ch1Shot

; ---------------- data ----------------
SECTION "SoundData", ROM0
WaveData:                       ; triangle
    db $01,$23,$45,$67,$89,$AB,$CD,$EF,$FE,$DC,$BA,$98,$76,$54,$32,$10

SongGame:
    db 7, $80, $A3
    dw M1, BAm, M2, BF, M3, BG, M4, BE
    dw M5, BAm, M6, BF, M7, BG, M8, BE
    dw 0, 0

SongTitle:
    db 9, $40, $73
    dw TA1, TBA, TA2, TBF, TA3, TBG, TA4, TBE
    dw 0, 0

SongOver:
    db 8, $80, $C5
    dw JG, JB
    dw 1, 1

M1: db A4,HOLD,OFF,A4, C5,HOLD,OFF,E5, HOLD,OFF,D5,HOLD, C5,HOLD,A4,OFF
M2: db F4,HOLD,A4,HOLD, C5,HOLD,OFF,C5, D5,HOLD,C5,HOLD, A4,HOLD,HOLD,OFF
M3: db G4,HOLD,OFF,G4, B4,HOLD,OFF,D5, HOLD,OFF,E5,HOLD, D5,HOLD,B4,OFF
M4: db E5,HOLD,HOLD,HOLD, D5,HOLD,C5,HOLD, B4,HOLD,HOLD,HOLD, Gs4,HOLD,OFF,OFF
M5: db A5,HOLD,OFF,E5, HOLD,OFF,C5,HOLD, OFF,E5,OFF,A5, HOLD,G5,HOLD,OFF
M6: db F5,HOLD,OFF,C5, HOLD,OFF,A4,HOLD, OFF,C5,OFF,F5, HOLD,E5,HOLD,OFF
M7: db G5,HOLD,OFF,D5, HOLD,OFF,B4,HOLD, OFF,D5,OFF,G5, HOLD,F5,HOLD,OFF
M8: db E5,HOLD,HOLD,HOLD, B4,HOLD,HOLD,HOLD, Gs4,HOLD,B4,HOLD, E5,HOLD,OFF,OFF

BAm: db A3,OFF,A3,OFF, A4,OFF,A3,OFF, A3,OFF,A3,OFF, A4,OFF,G3,OFF
BF:  db F3,OFF,F3,OFF, F4,OFF,F3,OFF, F3,OFF,F3,OFF, F4,OFF,E3,OFF
BG:  db G3,OFF,G3,OFF, G4,OFF,G3,OFF, G3,OFF,G3,OFF, G4,OFF,D4,OFF
BE:  db E3,OFF,E3,OFF, E4,OFF,E3,OFF, Gs3,OFF,Gs3,OFF, B3,OFF,Gs3,OFF

TA1: db A4,C5,E5,A5, E5,C5,A4,C5, E5,A5,C6,A5, E5,C5,E5,C5
TA2: db F4,A4,C5,F5, C5,A4,F4,A4, C5,F5,A5,F5, C5,A4,C5,A4
TA3: db G4,B4,D5,G5, D5,B4,G4,B4, D5,G5,B5,G5, D5,B4,D5,B4
TA4: db E4,Gs4,B4,E5, B4,Gs4,E4,Gs4, B4,E5,Gs5,E5, B4,Gs4,B4,Gs4
TBA: db A3,HOLD,HOLD,HOLD,HOLD,HOLD,HOLD,OFF, A3,HOLD,HOLD,HOLD,HOLD,HOLD,HOLD,OFF
TBF: db F3,HOLD,HOLD,HOLD,HOLD,HOLD,HOLD,OFF, F3,HOLD,HOLD,HOLD,HOLD,HOLD,HOLD,OFF
TBG: db G3,HOLD,HOLD,HOLD,HOLD,HOLD,HOLD,OFF, G3,HOLD,HOLD,HOLD,HOLD,HOLD,HOLD,OFF
TBE: db E3,HOLD,HOLD,HOLD,HOLD,HOLD,HOLD,OFF, E3,HOLD,HOLD,HOLD,HOLD,HOLD,HOLD,OFF

JG: db E5,HOLD,D5,HOLD, C5,HOLD,B4,HOLD, A4,HOLD,HOLD,HOLD, HOLD,HOLD,OFF,OFF
JB: db A3,HOLD,HOLD,OFF, G3,HOLD,HOLD,OFF, A3,HOLD,HOLD,HOLD, HOLD,HOLD,OFF,OFF
