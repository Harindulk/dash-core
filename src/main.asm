; ===============================================================
;  DASH CORE  -  a one-screen dash-and-chain arcade game
;  Game Boy (DMG), MBC1+RAM+BATTERY, 32 KiB ROM, 8 KiB SRAM
;  Assembler: RGBDS
; ===============================================================
INCLUDE "hw.inc"
INCLUDE "notes.inc"

; ---------------- character map (font tile order) ----------------
CHARMAP " ", 0
CHARMAP "0", 1
CHARMAP "1", 2
CHARMAP "2", 3
CHARMAP "3", 4
CHARMAP "4", 5
CHARMAP "5", 6
CHARMAP "6", 7
CHARMAP "7", 8
CHARMAP "8", 9
CHARMAP "9", 10
CHARMAP "A", 11
CHARMAP "B", 12
CHARMAP "C", 13
CHARMAP "D", 14
CHARMAP "E", 15
CHARMAP "F", 16
CHARMAP "G", 17
CHARMAP "H", 18
CHARMAP "I", 19
CHARMAP "J", 20
CHARMAP "K", 21
CHARMAP "L", 22
CHARMAP "M", 23
CHARMAP "N", 24
CHARMAP "O", 25
CHARMAP "P", 26
CHARMAP "Q", 27
CHARMAP "R", 28
CHARMAP "S", 29
CHARMAP "T", 30
CHARMAP "U", 31
CHARMAP "V", 32
CHARMAP "W", 33
CHARMAP "X", 34
CHARMAP "Y", 35
CHARMAP "Z", 36
CHARMAP "!", 37
CHARMAP "-", 38
CHARMAP ":", 39
CHARMAP ".", 40
CHARMAP "x", 41
CHARMAP "?", 42
DEF STR_END EQU $FF

; ---------------- tiles ----------------
DEF T_FLOOR  EQU 48
DEF T_OUT    EQU 49
DEF T_EDGE_T EQU 50
DEF T_EDGE_B EQU 51
DEF T_EDGE_L EQU 52
DEF T_EDGE_R EQU 53
DEF T_C_TL   EQU 54
DEF T_C_TR   EQU 55
DEF T_C_BL   EQU 56
DEF T_C_BR   EQU 57
DEF S_P_TL   EQU 58
DEF S_P_TR   EQU 59
DEF S_P_BL   EQU 60
DEF S_P_BR   EQU 61
DEF S_GHOST  EQU 62
DEF S_AR_H   EQU 63
DEF S_AR_V   EQU 64
DEF S_AR_D   EQU 65
DEF S_DRIFT  EQU 66
DEF S_CHASE  EQU 68
DEF S_MARK   EQU 70
DEF S_SPARK  EQU 72
DEF S_DOT    EQU 73
DEF T_METER  EQU 74
DEF T_BOSS_VENT   EQU 78
DEF T_BOSS_HULL   EQU 79
DEF T_BOSS_EYE    EQU 80
DEF T_NODE_CLOSED EQU 82
DEF T_NODE_OPEN   EQU 83
DEF T_NODE_BROKEN EQU 85
DEF T_BEAM        EQU 86
DEF T_BEAM_WARN   EQU 87
DEF T_LOGO   EQU 128

; ---------------- game constants ----------------
DEF MAX_EN      EQU 12
DEF EN_SIZE     EQU 16
DEF MAX_PART    EQU 12
DEF PART_SIZE   EQU 6
DEF PART_LIFE   EQU 16

DEF E_TYPE  EQU 0
DEF E_TIMER EQU 1
DEF E_XL    EQU 2
DEF E_XH    EQU 3
DEF E_YL    EQU 4
DEF E_YH    EQU 5
DEF E_VXL   EQU 6
DEF E_VXH   EQU 7
DEF E_VYL   EQU 8
DEF E_VYH   EQU 9
DEF E_NEXT  EQU 10

DEF ET_NONE  EQU 0
DEF ET_DRIFT EQU 1
DEF ET_CHASE EQU 2
DEF ET_SPAWN EQU 3

DEF P_MINX  EQU 8
DEF P_MAXX  EQU 136
DEF P_MINY  EQU 8
DEF P_MAXY  EQU 112
DEF E_MAXX  EQU 144
DEF E_MAXY  EQU 120

DEF WALK_SPEED  EQU $0150
DEF DASH_SPEED  EQU $0380
DEF DASH_FRAMES EQU 12
DEF DASH_MAX    EQU 16
DEF DASH_CD     EQU 30
DEF GRACE       EQU 6
DEF CHASE_ACC   EQU $0007
DEF SPAWN_TIME  EQU 40
DEF HURT_R      EQU 8
DEF KILL_R      EQU 16
DEF PANEL_WY    EQU 56

DEF PAD_A     EQU 0
DEF PAD_B     EQU 1
DEF PAD_SEL   EQU 2
DEF PAD_START EQU 3
DEF PAD_RIGHT EQU 4
DEF PAD_LEFT  EQU 5
DEF PAD_UP    EQU 6
DEF PAD_DOWN  EQU 7

DEF PAL_NORMAL EQU %11100100
DEF PAL_INVERT EQU %00011011
DEF PAL_LIGHT  EQU %10010000

DEF FLASH_INVERT EQU 0
DEF FLASH_CYCLE  EQU 1
DEF FLASH_FADEIN EQU 2

DEF LCDC_ON EQU %11110011       ; LCD, win map 9C00, win on, tiles 8000, BG 9800, OBJ on, BG on

MACRO PUTS                     ; PRINT dest, string_label
    ld hl, \1
    ld de, \2
    call PrintStr
ENDM
MACRO PUTL                     ; PRINT dest, string id (current language)
    ld a, \2
    call StrLang
    ld hl, \1
    call PrintStr
ENDM

; string ids (index into StrEN / StrES)
DEF STR_PRESS   EQU 0
DEF STR_BEST    EQU 1
DEF STR_HELP1   EQU 2
DEF STR_HELP2   EQU 3
DEF STR_SCORE   EQU 4
DEF STR_OVER    EQU 5
DEF STR_NEWBEST EQU 6
DEF STR_LEVEL   EQU 7
DEF STR_INTRO   EQU 8
DEF STR_WARDEN  EQU 9
DEF STR_WDOWN   EQU 10
DEF STR_LANG    EQU 11

; ===============================================================
SECTION "VBlankVec", ROM0[$40]
    jp VBlankHandler
SECTION "StatVec", ROM0[$48]
    jp StatHandler

SECTION "Header", ROM0[$100]
    nop
    jp Start
    ds $150 - @, 0

; ===============================================================
SECTION "Main", ROM0

Start:
    di
    ld sp, $E000
    ; LCD off (only legal in VBlank on DMG). LcdOff checks LCDC.7 first:
    ; LY reads 0 while the LCD is off, so a flash-cart menu that hands
    ; over with the screen off would hang a plain LY wait forever.
    call LcdOff
    ; clear WRAM inline (the stack lives there)
    ld hl, $C000
    ld bc, $2000
.cw xor a
    ld [hl+], a
    dec bc
    ld a, b
    or c
    jr nz, .cw
    ld hl, $FF80
    ld c, $7F
.ch xor a
    ld [hl+], a
    dec c
    jr nz, .ch
    ld hl, DMARoutine
    ld de, hOAMDMA
    ld bc, DMARoutineEnd - DMARoutine
    call Memcpy
    ld hl, _VRAM
    ld bc, $2000
    xor a
    call Memset
    ld hl, _OAM
    ld bc, 160
    xor a
    call Memset
    call SoundInit
    call LoadGraphics
    call LoadBest
    ld a, PAL_NORMAL
    ldh [rBGP], a
    ldh [rOBP0], a
    ld [wBGP], a
    ld a, PAL_LIGHT
    ldh [rOBP1], a
    ld a, 7
    ldh [rWX], a
    ld a, 1
    ld [wRng], a
    jp TitleScreen

; ---------------------------------------------------------------
DMARoutine:
    ldh [rDMA], a
    ld a, 40
.w  dec a
    jr nz, .w
    ret
DMARoutineEnd:

; ===============================================================
;  Interrupts
; ===============================================================
VBlankHandler:
    push af
    push bc
    push de
    push hl
    ld a, HIGH(wShadowOAM)
    call hOAMDMA
    ld a, [wSCX]
    ldh [rSCX], a
    ld a, [wSCY]
    ldh [rSCY], a
    ld a, [wBGP]
    ldh [rBGP], a
    ld a, [wWY]
    ldh [rWY], a
    ld a, [wHudDirty]
    and a
    jr z, .noHud
    xor a
    ld [wHudDirty], a
    ld hl, wHud
    ld de, _SCRN1
    ld c, 20
.hud
    ld a, [hl+]
    ld [de], a
    inc e
    dec c
    jr nz, .hud
.noHud
    ld a, [wCopyLen]
    and a
    jr z, .noCopy
    ld c, a
    ld a, [wCopySrc]
    ld l, a
    ld a, [wCopySrc+1]
    ld h, a
    ld a, [wCopyDst]
    ld e, a
    ld a, [wCopyDst+1]
    ld d, a
.cp
    ld a, [hl+]
    ld [de], a
    inc de
    dec c
    jr nz, .cp
    xor a
    ld [wCopyLen], a
.noCopy
    call MusicTick
    ldh a, [hStatMode]          ; title: the logo ripple is always on
    and a
    ld a, %00000011
    jr z, .ie
    ld a, [wWave]               ; game: HBlank wave only while a wave runs
    and a
    ld a, %00000001
    jr z, .ie
    ld a, %00000011
.ie
    ld b, a
    ldh a, [rIF]                ; drop the STAT flag the last HBlank left
    and %11111101               ; pending, or the handler fires once in VBlank
    ldh [rIF], a
    ld a, b
    ldh [rIE], a
    ld a, 1
    ld [wVBlankDone], a
    pop hl
    pop de
    pop bc
    pop af
    reti

; HBlank interrupt. Title: ripple the logo lines. Game: full-screen SCX wave,
; enabled through IE only while wWave > 0 (it rides on hit-stop frames, so it
; never competes with the game logic for frame time).
StatHandler:
    push af
    push hl
    ldh a, [hStatMode]
    and a
    jr nz, .game
    ldh a, [rLY]
    cp 15
    jr c, .top                  ; tread band above the logo drifts left
    cp 56
    jr nc, .low
    ld l, a
    ldh a, [hWavePhase]
    add l
    and 63
    ld l, a
    ld h, HIGH(SineTable)
    ld a, [hl]
    ldh [rSCX], a
    pop hl
    pop af
    reti
.top
    ldh a, [hParaA]
    ldh [rSCX], a
    pop hl
    pop af
    reti
.low
    cp 63
    jr nc, .zero
    ldh a, [hParaB]             ; band below the logo drifts right
    ldh [rSCX], a
    pop hl
    pop af
    reti
.zero
    xor a
    ldh [rSCX], a
    pop hl
    pop af
    reti
.game
    ldh a, [hWavePhase]
    ld l, a
    ldh a, [rLY]
    add l
    and 63
    ld l, a
    ldh a, [hWaveHi]
    ld h, a
    ld a, [wSCX]
    add [hl]
    ldh [rSCX], a
    pop hl
    pop af
    reti

; ===============================================================
;  Helpers
; ===============================================================
; hl = src, de = dst, bc = len
Memcpy:
    ld a, [hl+]
    ld [de], a
    inc de
    dec bc
    ld a, b
    or c
    jr nz, Memcpy
    ret

; hl = dst, bc = len, a = value
Memset:
    ld d, a
.l  ld a, d
    ld [hl+], a
    dec bc
    ld a, b
    or c
    jr nz, .l
    ret

; hl = src, de = dst, c = len (1..255)
Copy8:
    ld a, [hl+]
    ld [de], a
    inc de
    dec c
    jr nz, Copy8
    ret

; de = string (STR_END terminated), hl = dst
PrintStr:
    ld a, [de]
    cp STR_END
    ret z
    ld [hl+], a
    inc de
    jr PrintStr

; de = 3-byte little-endian BCD, hl = dst; writes 6 digit tiles
PrintBCD6:
    inc de
    inc de
    ld b, 3
.l  ld a, [de]
    swap a
    and $0F
    inc a
    ld [hl+], a
    ld a, [de]
    and $0F
    inc a
    ld [hl+], a
    dec de
    dec b
    jr nz, .l
    ret

; hl = src, de = VRAM dst, a = len  -> copied in next VBlank
QueueCopy:
    push af
    ld a, l
    ld [wCopySrc], a
    ld a, h
    ld [wCopySrc+1], a
    ld a, e
    ld [wCopyDst], a
    ld a, d
    ld [wCopyDst+1], a
    pop af
    ld [wCopyLen], a
    ret

WaitVBlank:
    halt
    nop
    ld a, [wVBlankDone]
    and a
    jr z, WaitVBlank
    xor a
    ld [wVBlankDone], a
    ret

; leaves interrupts disabled; caller turns the screen back on
LcdOff:
    di
    ldh a, [rLCDC]
    bit 7, a
    ret z
.w  ldh a, [rLY]
    cp 144
    jr c, .w
    xor a
    ldh [rLCDC], a
    ret

; a = LCDC value
ScreenOn:
    ldh [rLCDC], a
    xor a
    ldh [rIF], a
    ei
    ret

ReadInput:
    ld a, $20                   ; d-pad
    ldh [rP1], a
    ldh a, [rP1]
    ldh a, [rP1]
    cpl
    and $0F
    swap a
    ld b, a
    ld a, $10                   ; buttons
    ldh [rP1], a
    ldh a, [rP1]
    ldh a, [rP1]
    ldh a, [rP1]
    ldh a, [rP1]
    ldh a, [rP1]
    ldh a, [rP1]
    cpl
    and $0F
    or b
    ld b, a
    ld a, $30
    ldh [rP1], a
    ld a, [wKeys]
    xor b
    and b
    ld [wKeysNew], a
    ld a, b
    ld [wKeys], a
    ret

; 16-bit xorshift (7,9,8). Returns a = random. Keeps bc, de, hl.
Rand:
    push hl
    ld a, [wRng+1]
    ld h, a
    ld a, [wRng]
    ld l, a
    ld a, h
    rra
    ld a, l
    rra
    xor h
    ld h, a
    ld a, l
    rra
    ld a, h
    rra
    xor l
    ld l, a
    xor h
    ld h, a
    ld [wRng+1], a
    ld a, l
    ld [wRng], a
    ld a, h
    pop hl
    ret

; |a - b|
AbsDiff:
    sub b
    ret nc
    cpl
    inc a
    ret

; ===============================================================
;  Graphics loading
; ===============================================================
LoadGraphics:
    ld hl, FontData
    ld de, _VRAM
    ld bc, FontDataEnd - FontData
.f  ld a, [hl+]
    ld [de], a
    inc de
    ld [de], a
    inc de
    dec bc
    ld a, b
    or c
    jr nz, .f
    ld hl, GameTiles
    ld de, _VRAM + T_FLOOR * 16
    ld bc, GameTilesEnd - GameTiles
    call Memcpy
    ; build the 2x logo letters from the font
    ld hl, LogoGlyphs
    ld de, _VRAM + T_LOGO * 16
    ld b, 8
.lg push bc
    ld a, [hl+]
    push hl
    call BuildBigGlyph
    pop hl
    pop bc
    dec b
    jr nz, .lg
    ret

LogoGlyphs: db "DASHCORE"

; a = glyph, de = dest (advanced by 64 bytes: TL, TR, BL, BR tiles)
; Each font pixel becomes 2x2; the lower row of each pair is colour 2
; for a striped arcade look.
BuildBigGlyph:
    ld l, a
    ld h, 0
    add hl, hl
    add hl, hl
    add hl, hl
    ld bc, FontData
    add hl, bc
    ld c, 0
    push hl
    call .half
    pop hl
    ld c, 1
    push hl
    call .half
    pop hl
    ld a, l
    add 4
    ld l, a
    ld a, h
    adc 0
    ld h, a
    ld c, 0
    push hl
    call .half
    pop hl
    ld c, 1
    ; fall through
.half                           ; 4 source rows -> one 8x8 tile
    ld b, 4
.row
    ld a, [hl+]
    push hl
    bit 0, c
    jr nz, .right
    swap a
.right
    and $0F
    add LOW(DoubleTable)
    ld l, a
    ld a, 0
    adc HIGH(DoubleTable)
    ld h, a
    ld a, [hl]
    ld [de], a                  ; row: colour 3
    inc de
    ld [de], a
    inc de
    ld l, a
    xor a                       ; row: colour 2
    ld [de], a
    inc de
    ld a, l
    ld [de], a
    inc de
    pop hl
    dec b
    jr nz, .row
    ret

; ===============================================================
;  SRAM high score
; ===============================================================
LoadBest:
    ld a, $0A
    ld [MBC_RAMG], a
    ld hl, _SRAM
    ld de, SaveMagic
    ld b, 4
.m  ld a, [de]
    cp [hl]
    jr nz, .bad
    inc hl
    inc de
    dec b
    jr nz, .m
    ; hl = _SRAM+4: 3 BCD bytes then checksum
    ld a, [hl+]
    ld [wBest], a
    ld b, a
    ld a, [hl+]
    ld [wBest+1], a
    add b
    ld b, a
    ld a, [hl+]
    ld [wBest+2], a
    add b
    xor $A5
    cp [hl]
    jr nz, .bad
    ; reject non-BCD garbage
    ld hl, wBest
    ld b, 3
.v  ld a, [hl]
    and $0F
    cp 10
    jr nc, .bad
    ld a, [hl+]
    and $F0
    cp $A0
    jr nc, .bad
    dec b
    jr nz, .v
    jr .done
.bad
    xor a
    ld [wBest], a
    ld [wBest+1], a
    ld [wBest+2], a
.done
    xor a
    ld [MBC_RAMG], a
    ret

SaveBest:
    ld a, $0A
    ld [MBC_RAMG], a
    ld hl, SaveMagic
    ld de, _SRAM
    ld c, 4
    call Copy8
    ld hl, wBest
    ld c, 3
    call Copy8                  ; de = _SRAM+7 after this
    ld a, [wBest]
    ld b, a
    ld a, [wBest+1]
    add b
    ld b, a
    ld a, [wBest+2]
    add b
    xor $A5
    ld [de], a
    xor a
    ld [MBC_RAMG], a
    ret

SaveMagic: db $44, $53, $48, $43   ; "DSHC" raw bytes

; ===============================================================
;  Title screen
; ===============================================================
TitleScreen:
    ld sp, $E000
    call LcdOff
    ld hl, _SCRN0
    ld bc, 32 * 32
    ld a, T_FLOOR
    call Memset
    ld hl, _SCRN0 + 2 * 32      ; plain backdrop behind the logo and text; tread stays
    ld bc, 5 * 32               ; only in the two parallax bands (rows 0-1 and 7)
    xor a
    call Memset
    ld hl, _SCRN0 + 8 * 32
    ld bc, 10 * 32
    xor a
    call Memset
    ld hl, _SCRN0 + 2 * 32 + 4
    ld a, T_LOGO
    call DrawBigWord4
    ld hl, _SCRN0 + 5 * 32 + 4
    ld a, T_LOGO + 16
    call DrawBigWord4
    PUTL _SCRN0 + 8 * 32 + 4, STR_PRESS
    PUTL _SCRN0 + 10 * 32 + 4, STR_BEST
    ld hl, _SCRN0 + 10 * 32 + 10
    ld de, wBest
    call PrintBCD6
    PUTL _SCRN0 + 12 * 32 + 1, STR_HELP1
    PUTL _SCRN0 + 13 * 32 + 1, STR_HELP2
    PUTL _SCRN0 + 15 * 32 + 2, STR_LANG
    ld hl, _SCRN1
    ld bc, 32
    xor a
    call Memset
    PUTS _SCRN1 + 1, TxtCredit
    ; clear sprites
    ld hl, wShadowOAM
    ld bc, 160
    xor a
    call Memset
    xor a
    ld [wSCX], a
    ld [wSCY], a
    ld [wHudDirty], a
    ld [wCopyLen], a
    ld a, 136
    ld [wWY], a
    ldh [rWY], a
    ld a, PAL_NORMAL
    ld [wBGP], a
    xor a
    ldh [hStatMode], a
    ; HBlank interrupt for the logo ripple (set while LCD is off: no DMG STAT-write glitch)
    ld a, %00001000
    ldh [rSTAT], a
    ld a, %00000011
    ldh [rIE], a
    ld a, LCDC_ON
    call ScreenOn
    ld hl, SongTitle
    call MusicPlay
.loop
    call WaitVBlank
    call ReadInput
    ld hl, wFrame
    inc [hl]
    ldh a, [hWavePhase]
    inc a
    ldh [hWavePhase], a
    ld a, [wFrame]              ; parallax: top band +1/2 px per frame, bottom band -1/2
    srl a
    ldh [hParaA], a
    ld [wSCX], a                ; line 0 takes its SCX from VBlank
    cpl
    inc a
    ldh [hParaB], a
    ld a, [wFrame]
    and 31
    jr nz, .noBlink
    ld a, [wFrame]
    and 32
    ld a, STR_PRESS
    call StrLang
    ld h, d
    ld l, e
    jr z, .show
    ld hl, TxtBlank11
.show
    ld de, _SCRN0 + 8 * 32 + 4
    ld a, 11
    call QueueCopy
.noBlink
    call TitleSprites
    ld a, [wKeysNew]
    bit PAD_SEL, a
    jr z, .noLang
    ld a, [wLang]
    xor 1
    ld [wLang], a
    jp TitleScreen
.noLang
    ld a, [wKeysNew]
    bit PAD_START, a
    jr z, .loop
    ldh a, [rDIV]
    ld [wRng], a
    ld a, [wFrame]
    or 1
    ld [wRng+1], a
    call SfxStart
    jp StartGame

TitleSprites:
    xor a
    ld [wOamLo], a
    ld a, [wFrame]
    add a
    and 63
    ld l, a
    ld h, HIGH(SineTable)
    ld a, [hl]
    add 72
    ld b, a
    ld a, [wFrame]
    and 8
    ld d, S_DRIFT
    jr z, .t
    inc d
.t  ld e, 0
    ld c, 16
    call PutSprite
    ld c, 136
    call PutSprite
    ret

; hl = map dst, a = first logo tile; 4 big letters, 3 columns apart
DrawBigWord4:
    ld b, 4
    ld de, 31
.l  ld [hl+], a
    inc a
    ld [hl], a
    inc a
    ld de, 31
    add hl, de
    ld [hl+], a
    inc a
    ld [hl], a
    inc a
    ld de, -30
    add hl, de
    dec b
    jr nz, .l
    ret

; ===============================================================
;  Game
; ===============================================================
StartGame:
    ld sp, $E000
    call LcdOff
    ld a, %00001000             ; HBlank STAT source stays armed; IE bit 1 gates it
    ldh [rSTAT], a
    ld a, 1
    ldh [hStatMode], a
    ld a, %00000001
    ldh [rIE], a
    ; background: dark outside, framed arena
    ld hl, _SCRN0
    ld bc, 32 * 32
    ld a, T_OUT
    call Memset
    call DrawArena
    ; window: HUD row + game over panel (hidden below the screen)
    ld hl, _SCRN1
    ld bc, 32 * 12
    xor a
    call Memset
    PUTL _SCRN1 + 2 * 32 + 3, STR_OVER
    PUTL _SCRN1 + 4 * 32 + 3, STR_SCORE
    PUTL _SCRN1 + 6 * 32 + 3, STR_BEST
    PUTL _SCRN1 + 10 * 32 + 4, STR_PRESS
    ; reset game state
    ld hl, wGameVars
    ld bc, wGameVarsEnd - wGameVars
    xor a
    call Memset
    ld a, 72
    ld [wPX+1], a
    ld a, 60
    ld [wPY+1], a
    ld a, 1
    ld [wFaceX], a
    ld [wAlive], a
    ld [wCombo], a
    ld a, 50
    ld [wSpawnT], a
    ld a, 8
    ld [wTopY], a
    ld a, 136
    ld [wWY], a
    ldh [rWY], a
    ld a, PAL_NORMAL
    ld [wBGP], a
    ld a, FLASH_FADEIN
    ld [wFlashKind], a
    ld a, 16
    ld [wFlash], a
    xor a
    ld [wSCX], a
    ld [wSCY], a
    ld [wCopyLen], a
    ld [wPaused], a
    ld a, $FF
    ldh [rNR51], a
    ld hl, wTrail               ; trail starts at the player
    ld b, 8
.tr ld a, 72
    ld [hl+], a
    ld a, 60
    ld [hl+], a
    dec b
    jr nz, .tr
    call UpdateHud
    ld hl, wHud
    ld de, _SCRN1
    ld bc, 20
    call Memcpy
    xor a
    ld [wHudDirty], a
    call RenderSprites
    ld a, STR_INTRO
    call SetBanner
    ld a, 150
    ld [wBanner], a
    xor a
    ldh [rBGP], a               ; first frame already white for the fade-in
    ld a, LCDC_ON
    call ScreenOn
    ld hl, SongGame
    call MusicPlay

GameLoop:
    call WaitVBlank
    call ReadInput
    ld hl, wFrame
    inc [hl]
    ; pause (only while alive)
    ld a, [wAlive]
    and a
    jr z, .noPause
    ld a, [wKeysNew]
    bit PAD_START, a
    jr z, .chkPause
    ld a, [wPaused]
    xor 1
    ld [wPaused], a
    ld a, $FF
    jr z, .mix
    xor a
.mix
    ldh [rNR51], a
.chkPause
    ld a, [wPaused]
    and a
    jr nz, GameLoop
.noPause
    ld a, [wKeysNew]
    bit PAD_A, a
    jr z, .noBuf
    ld a, 8
    ld [wDashBuf], a
.noBuf
    call UpdateShake
    call UpdateFlash
    call UpdateWave
    ld a, [wFreeze]
    and a
    jr z, .run
    dec a
    ld [wFreeze], a
    jr .render
.run
    ld a, [wAlive]
    and a
    jr z, .dead
    call UpdatePlayer
    call UpdateEnemies
    call UpdateSpawner
    call UpdateParticles
    call UpdateBoss
    ld a, [wMusOn]              ; a jingle ended: back to the stage music
    and a
    jr nz, .render
    ld hl, SongGame
    call MusicPlay
    jr .render
.dead
    call UpdateEnemies
    call UpdateParticles
    call UpdateDeath
.render
    call UpdateHud
    call RenderSprites
    jp GameLoop

DrawArena:
    ld hl, _SCRN0
    ld a, T_C_TL
    ld [hl+], a
    ld a, T_EDGE_T
    ld b, 18
.t  ld [hl+], a
    dec b
    jr nz, .t
    ld a, T_C_TR
    ld [hl], a
    ld hl, _SCRN0 + 32
    ld c, 15
.r  ld a, T_EDGE_L
    ld [hl+], a
    ld a, T_FLOOR
    ld b, 18
.f  ld [hl+], a
    dec b
    jr nz, .f
    ld a, T_EDGE_R
    ld [hl+], a
    ld de, 12
    add hl, de
    dec c
    jr nz, .r
    ld a, T_C_BL
    ld [hl+], a
    ld a, T_EDGE_B
    ld b, 18
.b  ld [hl+], a
    dec b
    jr nz, .b
    ld a, T_C_BR
    ld [hl], a
    ret

; ---------------------------------------------------------------
UpdateShake:
    ld a, [wShake]
    and a
    jr z, .zero
    dec a
    ld [wShake], a
    ; amplitude decays with the timer: 1..3 px
    srl a
    srl a
    inc a
    cp 4
    jr c, .amp
    ld a, 3
.amp
    ld b, a
    ld a, [wFrame]
    ld c, a
    ld a, b
    bit 1, c
    jr z, .sx
    cpl
    inc a
.sx ld [wSCX], a
    ld a, b
    bit 2, c
    jr z, .sy
    cpl
    inc a
.sy ld [wSCY], a
    ret
.zero
    ld [wSCX], a
    ld [wSCY], a
    ret

; a = amount: shake at least this long
AddShake:
    ld hl, wShake
    cp [hl]
    ret c
    ld [hl], a
    ret

UpdateFlash:
    ld a, [wFlash]
    and a
    jr z, .normal
    dec a
    ld [wFlash], a
    ld b, a
    ld a, [wFlashKind]
    and a
    jr z, .invert
    dec a
    jr z, .cycle
    ld a, b                     ; fade in from white: 16 frames, 4 steps
    srl a
    srl a
    ld hl, PalFadeIn
    jr .table
.cycle                          ; level up: 8 frames of palette rotation
    ld a, b
    srl a
    and 3
    ld hl, PalCycle
.table
    add l
    ld l, a
    adc h
    sub l
    ld h, a
    ld a, [hl]
    jr .set
.invert                         ; death: invert every other frame
    ld a, [wFrame]
    and 2
    ld a, PAL_INVERT
    jr z, .set
.normal
    ld a, PAL_NORMAL
.set
    ld [wBGP], a
    ret

PalFadeIn: db PAL_NORMAL, PAL_LIGHT, %01000000, %00000000
PalCycle:  db PAL_LIGHT, PAL_INVERT, %01001110, PAL_LIGHT

; The wave runs on hit-stop frames: the game logic is idle then, so the
; per-line interrupt (about a third of a frame) is free.
UpdateWave:
    ld a, [wWave]
    and a
    ret z
    dec a
    ld [wWave], a
    ldh a, [hWavePhase]
    add 5
    ldh [hWavePhase], a
    ld a, [wWaveAmp]
    dec a
    add LOW(WaveTables)
    ld l, a
    ld a, 0
    adc HIGH(WaveTables)
    ld h, a
    ld a, [hl]
    ldh [hWaveHi], a
    ret
WaveTables: db HIGH(SineTable), HIGH(SineTable2), HIGH(SineTable3)

; a = amplitude 1..3 (2, 4, 8 px), b = frames
StartWave:
    ld [wWaveAmp], a
    ld a, b
    ld [wWave], a
    ret

; ---------------------------------------------------------------
UpdatePlayer:
    ld a, [wKeys]
    ld b, a
    ld c, 0
    ld d, 0
    bit PAD_RIGHT, b
    jr z, .nr
    inc c
.nr bit PAD_LEFT, b
    jr z, .nl
    dec c
.nl bit PAD_UP, b
    jr z, .nu
    dec d
.nu bit PAD_DOWN, b
    jr z, .nd
    inc d
.nd ld a, c
    ld [wInX], a
    ld a, d
    ld [wInY], a
    or c
    jr z, .nf
    ld a, c
    ld [wFaceX], a
    ld a, d
    ld [wFaceY], a
.nf
    ld a, [wDashBuf]
    and a
    jr z, .nb
    dec a
    ld [wDashBuf], a
.nb
    ld a, [wGrace]
    and a
    jr z, .ng
    dec a
    ld [wGrace], a
.ng
    ld a, [wDash]
    and a
    jr nz, .dashing
    ld a, [wDashCD]
    and a
    jr z, .ready
    dec a
    ld [wDashCD], a
    jr nz, .walk
    call SfxReady
    jr .walk
.ready
    ld a, [wDashBuf]
    and a
    jr z, .walk
    xor a
    ld [wDashBuf], a
    ld a, DASH_FRAMES
    ld [wDash], a
    xor a
    ld [wDashKills], a
    ld a, [wPX + 1]
    call SetPan
    call SfxDash
.dashing
    ld a, [wFaceX]
    ld bc, DASH_SPEED
    call AxisVel
    ld hl, wPX
    call AddVel
    ld a, [wFaceY]
    ld bc, DASH_SPEED
    call AxisVel
    ld hl, wPY
    call AddVel
    ld hl, wDash
    dec [hl]
    jr nz, .clamp
    ; dash over: a dash that hit nothing breaks the chain
    ld a, [wDashKills]
    and a
    jr nz, .kept
    ld a, 1
    ld [wCombo], a
.kept
    ld a, DASH_CD
    ld [wDashCD], a
    ld a, GRACE
    ld [wGrace], a
    jr .clamp
.walk
    ld a, [wInX]
    ld bc, WALK_SPEED
    call AxisVel
    ld hl, wPX
    call AddVel
    ld a, [wInY]
    ld bc, WALK_SPEED
    call AxisVel
    ld hl, wPY
    call AddVel
.clamp
    ld hl, wPX + 1
    ld b, P_MINX
    ld c, P_MAXX
    call ClampPos
    ld hl, wPY + 1
    ld a, [wTopY]
    ld b, a
    ld c, P_MAXY
    call ClampPos
    ; record trail
    ld a, [wTrailIdx]
    ld e, a
    add a
    ld hl, wTrail
    add l
    ld l, a
    adc h
    sub l
    ld h, a
    ld a, [wPX + 1]
    ld [hl+], a
    ld a, [wPY + 1]
    ld [hl], a
    ld a, e
    inc a
    and 7
    ld [wTrailIdx], a
    ret

; a = -1/0/1, bc = speed -> de = signed velocity
AxisVel:
    ld de, 0
    and a
    ret z
    ld d, b
    ld e, c
    bit 7, a
    ret z
    xor a
    sub e
    ld e, a
    ld a, 0
    sbc d
    ld d, a
    ret

; [hl] (16-bit LE) += de
AddVel:
    ld a, [hl]
    add e
    ld [hl+], a
    ld a, [hl]
    adc d
    ld [hl], a
    ret

; [hl] = -[hl] (16-bit LE)
NegVel:
    xor a
    sub [hl]
    ld [hl+], a
    ld a, 0
    sbc [hl]
    ld [hl], a
    ret

; hl -> pixel byte (fraction at hl-1), clamp to [b, c]
ClampPos:
    ld a, [hl]
    cp b
    jr nc, .notMin
    ld [hl], b
    dec hl
    ld [hl], 0
    ret
.notMin
    cp c
    ret c
    ret z
    ld [hl], c
    dec hl
    ld [hl], 0
    ret

; like ClampPos but returns carry if it hit a wall
BouncePos:
    ld a, [hl]
    cp b
    jr nc, .notMin
    ld [hl], b
    scf
    ret
.notMin
    cp c
    jr c, .ok
    jr z, .ok
    ld [hl], c
    scf
    ret
.ok
    and a
    ret

; hl -> velocity low byte, c = max speed (low byte)
ClampVel:
    inc hl
    ld a, [hl]
    dec hl
    bit 7, a
    jr nz, .neg
    and a
    jr nz, .setPos
    ld a, [hl]
    cp c
    ret c
.setPos
    ld [hl], c
    inc hl
    ld [hl], 0
    ret
.neg
    cp $FF
    jr nz, .setNeg
    ld a, c
    cpl
    inc a
    ld b, a
    ld a, [hl]
    cp b
    ret nc
.setNeg
    ld a, c
    cpl
    inc a
    ld [hl+], a
    ld [hl], $FF
    ret

; ---------------------------------------------------------------
UpdateEnemies:
    ld hl, wEnemies
    ld b, MAX_EN
.loop
    push bc
    push hl
    ld a, [hl]
    and a
    jr z, .next
    ld de, wCur
    ld c, EN_SIZE
    call Copy8
    call EnemyStep
    pop hl
    push hl
    ld d, h
    ld e, l
    ld hl, wCur
    ld c, EN_SIZE
    call Copy8
.next
    pop hl
    ld de, EN_SIZE
    add hl, de
    pop bc
    dec b
    jr nz, .loop
    ret

; works on wCur
EnemyStep:
    ld hl, wCur + E_TIMER
    inc [hl]
    ld a, [wCur + E_TYPE]
    cp ET_SPAWN
    jr nz, .active
    ld a, [hl]
    cp SPAWN_TIME
    ret c
    ld a, [wCur + E_NEXT]
    ld [wCur + E_TYPE], a
    ret
.active
    cp ET_CHASE
    call z, ChaseAccel
    ld a, [wCur + E_VXL]
    ld e, a
    ld a, [wCur + E_VXH]
    ld d, a
    ld hl, wCur + E_XL
    call AddVel
    ld hl, wCur + E_XH
    ld b, P_MINX
    ld c, E_MAXX
    call BouncePos
    jr nc, .nbx
    ld hl, wCur + E_VXL
    call NegVel
.nbx
    ld a, [wCur + E_VYL]
    ld e, a
    ld a, [wCur + E_VYH]
    ld d, a
    ld hl, wCur + E_YL
    call AddVel
    ld hl, wCur + E_YH
    ld a, [wTopY]
    ld b, a
    ld c, E_MAXY
    call BouncePos
    jr nc, .nby
    ld hl, wCur + E_VYL
    call NegVel
.nby
    ; fall through
EnemyVsPlayer:
    ld a, [wAlive]
    and a
    ret z
    ld a, [wDash]
    ld b, a
    ld a, [wGrace]
    or b
    ld c, HURT_R
    jr z, .r
    ld c, KILL_R
.r  ld a, [wPX + 1]
    add 4
    ld b, a
    ld a, [wCur + E_XH]
    call AbsDiff
    cp c
    ret nc
    ld a, [wPY + 1]
    add 4
    ld b, a
    ld a, [wCur + E_YH]
    call AbsDiff
    cp c
    ret nc
    ld a, [wDash]
    ld b, a
    ld a, [wGrace]
    or b
    jp nz, KillEnemy
    jp PlayerDie

ChaseAccel:
    ld a, [wLevel]
    add a
    add a
    add a
    add $70
    ld [wTmp], a                ; max speed
    ld a, [wPX + 1]
    add 4
    ld b, a
    ld a, [wCur + E_XH]
    cp b
    ld de, CHASE_ACC
    jr c, .ax
    ld de, -CHASE_ACC
.ax ld hl, wCur + E_VXL
    call AddVel
    ld a, [wTmp]
    ld c, a
    ld hl, wCur + E_VXL
    call ClampVel
    ld a, [wPY + 1]
    add 4
    ld b, a
    ld a, [wCur + E_YH]
    cp b
    ld de, CHASE_ACC
    jr c, .ay
    ld de, -CHASE_ACC
.ay ld hl, wCur + E_VYL
    call AddVel
    ld a, [wTmp]
    ld c, a
    ld hl, wCur + E_VYL
    jp ClampVel

KillEnemy:
    xor a
    ld [wCur + E_TYPE], a
    ld a, [wCur + E_XH]
    ld b, a
    ld a, [wCur + E_YH]
    ld c, a
    ld hl, BurstKill
    call Burst
    ; floating multiplier digit
    ld a, [wCur + E_XH]
    ld b, a
    ld a, [wCur + E_YH]
    sub 6
    ld c, a
    ld d, 0
    ld e, -1
    ld a, [wCombo]
    inc a
    call SpawnPart
    ; score += combo * 10 (BCD)
    ld a, [wCombo]
    swap a
    ld hl, wScore
    add [hl]
    daa
    ld [hl+], a
    ld a, [hl]
    adc 0
    daa
    ld [hl+], a
    ld a, [hl]
    adc 0
    daa
    ld [hl], a
    ld a, [wCur + E_XH]
    call SetPan
    ld a, [wCombo]
    call SfxKill
    ld a, [wCombo]
    cp 9
    jr nc, .maxed
    inc a
    ld [wCombo], a
.maxed
    ld hl, wDashKills
    inc [hl]
    ; each kill stretches the dash so chains are possible
    ld a, [wDash]
    and a
    jr z, .noExt
    add 4
    cp DASH_MAX
    jr c, .ext
    ld a, DASH_MAX
.ext
    ld [wDash], a
.noExt
    ld a, 3
    ld [wFreeze], a
    ld a, 6
    call AddShake
    ld a, [wCombo]              ; wave grows with the chain: x1-3 2 px, x4-6 4 px, x7+ 8 px
    cp 4
    ld a, 1
    jr c, .amp
    ld a, [wCombo]
    cp 7
    ld a, 2
    jr c, .amp
    ld a, 3
.amp
    ld b, 3
    call StartWave
    ld hl, wKillsLvl
    inc [hl]
    ld a, [hl]
    cp 6
    ret c
    ld [hl], 0
    ld a, [wLevel]
    cp 9
    ret nc
    inc a
    ld [wLevel], a
    ld a, 8
    ld [wFlash], a
    ld a, FLASH_CYCLE
    ld [wFlashKind], a
    ld a, 6
    ld [wFreeze], a
    ld a, 3
    ld b, 6
    call StartWave
    ld a, STR_LEVEL
    call SetBanner
    ld a, 1
    ld [wBannerLvl], a
    ld a, 90
    ld [wBanner], a
    ld a, 80
    call SetPan
    call SfxLevel
    ld a, [wLevel]
    jp BossMaybeStart

PlayerDie:
    xor a
    ld [wAlive], a
    ld [wDeadT], a
    ld a, 24
    ld [wFreeze], a
    ld a, 30
    ld [wShake], a
    ld a, 10
    ld [wFlash], a
    xor a
    ld [wFlashKind], a
    ld a, 3
    ld b, 24
    call StartWave
    ld a, [wPX + 1]
    call SetPan
    ld a, [wPX + 1]
    add 4
    ld b, a
    ld a, [wPY + 1]
    add 4
    ld c, a
    ld hl, BurstDeath
    call Burst
    call MusicStop
    jp SfxDeath

; ---------------------------------------------------------------
UpdateSpawner:
    ld hl, wSpawnT
    dec [hl]
    ret nz
    ld a, [wLevel]
    ld b, a
    add a
    add a
    add b
    ld b, a
    ld a, 54
    sub b
    ld [hl], a                  ; 54 .. 9 frames between spawns
    ; cap = 4 + level
    ld hl, wEnemies
    ld b, MAX_EN
    ld c, 0
    ld de, EN_SIZE
.cnt
    ld a, [hl]
    and a
    jr z, .cn
    inc c
.cn add hl, de
    dec b
    jr nz, .cnt
    ld a, [wLevel]
    add 4
    cp MAX_EN + 1
    jr c, .capOk
    ld a, MAX_EN
.capOk
    cp c
    ret c
    ret z
    ld hl, wEnemies
    ld de, EN_SIZE
.ff ld a, [hl]
    and a
    jr z, .got
    add hl, de
    jr .ff
.got
    push hl
    ld e, 4                     ; tries to find a spot away from the player
.try
    call Rand
    and 127
    add 12
    ld b, a
    call Rand
    and 63
    ld c, a
    call Rand
    and 31
    add c
    add 12
    ld c, a
    ld a, [wPX + 1]
    add 4
    ld d, a
    ld a, b
    sub d
    jr nc, .dx
    cpl
    inc a
.dx cp 40
    jr nc, .ok
    ld a, [wPY + 1]
    add 4
    ld d, a
    ld a, c
    sub d
    jr nc, .dy
    cpl
    inc a
.dy cp 40
    jr nc, .ok
    dec e
    jr nz, .try
    pop hl
    ret
.ok
    pop hl
    ld a, [wTopY]
    add 4
    cp c
    jr c, .yok
    ld c, a
.yok
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
    ; speed = $58 + level*12 + rand(0..31)
    ld a, [wLevel]
    ld d, a
    add a
    add d
    add a
    add a
    add $58
    ld d, a
    call Rand
    and 31
    add d
    ld d, a
    call Rand
    ld e, a
    bit 0, e
    ld a, d
    jr z, .vxp
    cpl
    inc a
    ld [hl+], a
    ld a, $FF
    ld [hl+], a
    jr .vy
.vxp
    ld [hl+], a
    xor a
    ld [hl+], a
.vy
    bit 1, e
    ld a, d
    jr z, .vyp
    cpl
    inc a
    ld [hl+], a
    ld a, $FF
    ld [hl+], a
    jr .kind
.vyp
    ld [hl+], a
    xor a
    ld [hl+], a
.kind
    ld b, ET_DRIFT
    ld a, [wLevel]
    cp 2
    jr c, .setK
    ld c, a
    call Rand
    and 15
    cp c
    jr nc, .setK
    ld b, ET_CHASE
.setK
    ld [hl], b
    ret

; ---------------------------------------------------------------
; a = tile, b = x, c = y, d = vx, e = vy. Keeps bc, de, hl.
SpawnPart:
    push hl
    ld [wTmp], a
    ld hl, wParts
    ld a, MAX_PART
.f  push af
    ld a, [hl]
    and a
    jr z, .found
    pop af
    push de
    ld de, PART_SIZE
    add hl, de
    pop de
    dec a
    jr nz, .f
    pop hl
    ret
.found
    pop af
    ld a, PART_LIFE
    ld [hl+], a
    ld a, b
    ld [hl+], a
    ld a, c
    ld [hl+], a
    ld a, d
    ld [hl+], a
    ld a, e
    ld [hl+], a
    ld a, [wTmp]
    ld [hl], a
    pop hl
    ret

; hl = burst table (count, tile, vx/vy pairs), b = x, c = y
Burst:
    ld a, [hl+]
    ld [wTmp2], a
    ld a, [hl+]
    ld [wTmp3], a
.l  ld a, [hl+]
    ld d, a
    ld a, [hl+]
    ld e, a
    ld a, [wTmp3]
    call SpawnPart
    ld a, [wTmp2]
    dec a
    ld [wTmp2], a
    jr nz, .l
    ret

BurstKill:  db 4, S_SPARK, 2, 2, -2, 2, 2, -2, -2, -2
BurstDeath: db 8, S_DOT, 3, 0, -3, 0, 0, 3, 0, -3, 2, 2, -2, 2, 2, -2, -2, -2

UpdateParticles:
    ld hl, wParts
    ld b, MAX_PART
.l  ld a, [hl]
    and a
    jr z, .n
    dec a
    ld [hl], a
    push hl
    inc hl
    ld d, h
    ld e, l                     ; de -> x
    inc hl
    inc hl                      ; hl -> vx
    ld a, [de]
    add [hl]
    ld [de], a
    cp 160
    jr nc, .kill
    inc de
    inc hl
    ld a, [de]
    add [hl]
    ld [de], a
    cp 136
    jr c, .alive
.kill
    pop hl
    xor a
    ld [hl], a
    jr .n
.alive
    pop hl
.n  ld de, PART_SIZE
    add hl, de
    dec b
    jr nz, .l
    ret

; ---------------------------------------------------------------
UpdateDeath:
    ld a, [wOver]
    and a
    jr nz, .over
    ld hl, wDeadT
    inc [hl]
    ld a, [hl]
    cp 50
    ret c
    ld a, 1
    ld [wOver], a
    xor a
    ld [wOverStep], a
    call CheckBest
    ld hl, SongOver
    jp MusicPlay
.over
    ld a, [wOverStep]
    cp 3
    jr nc, .slide
    inc a
    ld [wOverStep], a
    dec a
    jr z, .s0
    dec a
    jr z, .s1
    ld a, [wNewBest]
    and a
    ld a, STR_NEWBEST
    call StrLang
    ld h, d
    ld l, e
    jr nz, .s2
    ld hl, TxtBlank11
.s2 ld de, _SCRN1 + 8 * 32 + 4
    ld a, 11
    call QueueCopy
    jr .slide
.s0 ld hl, wCopyBuf
    ld de, wScore
    call PrintBCD6
    ld hl, wCopyBuf
    ld de, _SCRN1 + 4 * 32 + 10
    ld a, 6
    call QueueCopy
    jr .slide
.s1 ld hl, wCopyBuf
    ld de, wBest
    call PrintBCD6
    ld hl, wCopyBuf
    ld de, _SCRN1 + 6 * 32 + 10
    ld a, 6
    call QueueCopy
.slide
    ld a, [wWY]
    cp PANEL_WY
    jr z, .waitStart
    sub PANEL_WY                ; ease out: move a quarter of the gap
    srl a
    srl a
    inc a
    ld b, a
    ld a, [wWY]
    sub b
    ld [wWY], a
    ret
.waitStart
    ld a, [wKeysNew]
    bit PAD_START, a
    ret z
    call SfxStart
    jp StartGame

CheckBest:
    ld hl, wScore + 2
    ld de, wBest + 2
    ld b, 3
.l  ld a, [de]
    cp [hl]
    jr c, .new
    ret nz
    dec hl
    dec de
    dec b
    jr nz, .l
    ret
.new
    ld a, 1
    ld [wNewBest], a
    ld hl, wScore
    ld de, wBest
    ld c, 3
    call Copy8
    jp SaveBest

; ---------------------------------------------------------------
UpdateHud:
    ld a, [wBanner]
    and a
    jr z, .normal
    dec a
    ld [wBanner], a
    and 8                       ; blink between banner and score
    jr z, .normal
    ld hl, wHud
    ld a, [wBannerTxt]
    ld e, a
    ld a, [wBannerTxt+1]
    ld d, a
    call PrintStr
    ld a, [wBannerLvl]
    and a
    jr z, .dirty
    ld a, [wLevel]
    inc a                       ; levels shown from 1
    inc a                       ; digit tile = value + 1
    ld [wHud + 12], a
.dirty
    ld a, 1
    ld [wHudDirty], a
    ret
.normal
    ld hl, wHud
    ld de, wScore
    call PrintBCD6
    xor a
    ld [hl+], a
    ld a, 'x'
    ld [hl+], a
    ld a, [wCombo]
    inc a
    ld [hl+], a
    xor a
    ld [hl+], a
    call MeterTile
    ld [hl+], a
    xor a
    ld [hl+], a
    ld a, 'H'
    ld [hl+], a
    ld a, 'I'
    ld [hl+], a
    ld de, wBest
    call PrintBCD6
    ld a, 1
    ld [wHudDirty], a
    ret

MeterTile:
    ld a, [wDash]
    and a
    jr nz, .empty
    ld a, [wDashCD]
    and a
    jr z, .full
    cp 10
    jr c, .two
    cp 20
    jr c, .one
.empty
    ld a, T_METER
    ret
.one
    ld a, T_METER + 1
    ret
.two
    ld a, T_METER + 2
    ret
.full
    ld a, T_METER + 3
    ret

; ---------------------------------------------------------------
; b = y, c = x (screen pixels), d = tile, e = attr. Keeps bc, de, hl.
PutSprite:
    ld a, [wWY]
    sub 8
    cp b
    ret c                       ; would overlap the window panel
    push hl
    ld h, HIGH(wShadowOAM)
    ld a, [wOamLo]
    ld l, a
    ld a, [wSCY]
    cpl
    inc a
    add b
    add 16
    ld [hl+], a
    ld a, [wSCX]
    cpl
    inc a
    add c
    add 8
    ld [hl+], a
    ld a, d
    ld [hl+], a
    ld a, e
    ld [hl+], a
    ld a, l
    ld [wOamLo], a
    pop hl
    ret

RenderSprites:
    xor a
    ld [wOamLo], a
    ld a, [wAlive]
    and a
    jp z, .enemies
    ; arrow when the dash is ready
    ld a, [wDash]
    ld d, a
    ld a, [wDashCD]
    or d
    jr nz, .noArrow
    ld e, 0
    ld a, [wFaceX]
    bit 7, a
    jr z, .nfx
    set 5, e
.nfx
    ld a, [wFaceY]
    bit 7, a
    jr z, .nfy
    set 6, e
.nfy
    ld a, [wFaceX]
    call Times11
    ld c, a
    ld a, [wPX + 1]
    add 4
    add c
    ld c, a
    ld a, [wFaceY]
    call Times11
    ld b, a
    ld a, [wPY + 1]
    add 4
    add b
    ld b, a
    ld d, S_AR_D
    ld a, [wFaceX]
    and a
    jr nz, .hx
    ld d, S_AR_V
    jr .putA
.hx ld a, [wFaceY]
    and a
    jr nz, .putA
    ld d, S_AR_H
.putA
    call PutSprite
.noArrow
    ; core body (light palette while dashing)
    ld e, 0
    ld a, [wDash]
    and a
    jr z, .pal
    ld e, $10
.pal
    ld a, [wPY + 1]
    ld b, a
    ld a, [wPX + 1]
    ld c, a
    ld d, S_P_TL
    call PutSprite
    ld a, c
    add 8
    ld c, a
    ld d, S_P_TR
    call PutSprite
    ld a, b
    add 8
    ld b, a
    ld d, S_P_BR
    call PutSprite
    ld a, c
    sub 8
    ld c, a
    ld d, S_P_BL
    call PutSprite
    ; afterimages
    ld a, [wDash]
    ld b, a
    ld a, [wGrace]
    or b
    jr z, .enemies
    ld a, [wTrailIdx]
    sub 3
    call .ghost
    ld a, [wTrailIdx]
    sub 5
    call .ghost
    ld a, [wTrailIdx]
    sub 7
    call .ghost
.enemies
    ld hl, wEnemies
    ld a, MAX_EN
.el push af
    push hl
    ld a, [hl+]
    ld d, a                     ; type
    ld a, [hl+]
    ld e, a                     ; timer
    inc hl
    ld a, [hl+]
    ld c, a                     ; x
    inc hl
    ld a, [hl]
    ld b, a                     ; y
    ld a, d
    and a
    jr z, .eskip
    cp ET_SPAWN
    jr nz, .alive
    bit 2, e                    ; warning marker blinks
    jr nz, .eskip
    ld d, S_MARK
    jr .anim
.alive
    cp ET_DRIFT
    ld d, S_DRIFT
    jr z, .anim
    ld d, S_CHASE
.anim
    ld a, [wFrame]
    and 8
    jr z, .eput
    inc d
.eput
    ld e, 0
    call PutSprite
.eskip
    pop hl
    ld de, EN_SIZE
    add hl, de
    pop af
    dec a
    jr nz, .el
    ; particles
    ld hl, wParts
    ld a, MAX_PART
.pl push af
    push hl
    ld a, [hl+]
    and a
    jr z, .pskip
    cp 6
    jr nc, .pshow
    bit 0, a                    ; flicker out
    jr nz, .pskip
.pshow
    ld a, [hl+]
    ld c, a
    ld a, [hl+]
    ld b, a
    inc hl
    inc hl
    ld d, [hl]
    ld e, 0
    call PutSprite
.pskip
    pop hl
    ld de, PART_SIZE
    add hl, de
    pop af
    dec a
    jr nz, .pl
    ; hide the rest
    ld h, HIGH(wShadowOAM)
    ld a, [wOamLo]
    ld l, a
.clr
    ld a, l
    cp 160
    ret z
    xor a
    ld [hl+], a
    ld [hl+], a
    ld [hl+], a
    ld [hl+], a
    jr .clr

.ghost                          ; a = trail index (wraps)
    and 7
    add a
    ld hl, wTrail
    add l
    ld l, a
    adc h
    sub l
    ld h, a
    ld a, [hl+]
    add 4
    ld c, a
    ld a, [hl]
    add 4
    ld b, a
    ld d, S_GHOST
    ld e, 0
    jp PutSprite

; a = -1/0/1 -> -11/0/11
Times11:
    and a
    ret z
    bit 7, a
    ld a, 11
    ret z
    ld a, -11
    ret

; ===============================================================
;  Text
; ===============================================================
SECTION "Text", ROM0
; a = id -> de = string in the current language
StrLang:
    add a
    ld e, a
    ld d, 0
    ld a, [wLang]
    and a
    ld hl, StrEN
    jr z, .t
    ld hl, StrES
.t  add hl, de
    ld a, [hl+]
    ld d, [hl]
    ld e, a
    ret

StrEN: dw TxtPressStart, TxtBestLabel, TxtHelp1, TxtHelp2, TxtScore, TxtGameOver, TxtNewBest, TxtLevelBanner, TxtIntro, TxtWarden, TxtWardenDown, TxtLangEN
StrES: dw EsPressStart, EsBestLabel, EsHelp1, EsHelp2, EsScore, EsGameOver, EsNewBest, EsLevelBanner, EsIntro, EsWarden, EsWardenDown, TxtLangES

; English and Spanish strings are the same width, so one layout serves both
TxtPressStart: db "PRESS START", STR_END
EsPressStart:  db "PULSA START", STR_END
TxtBlank11:    db "           ", STR_END
TxtBestLabel:  db "BEST ", STR_END
EsBestLabel:   db "MEJOR", STR_END
TxtScore:      db "SCORE ", STR_END
EsScore:       db "PUNTOS", STR_END
TxtGameOver:   db "  GAME OVER  ", STR_END
EsGameOver:    db "FIN DEL JUEGO", STR_END
TxtNewBest:    db " NEW BEST! ", STR_END
EsNewBest:     db "NUEVO MEJOR", STR_END
TxtHelp1:      db "DPAD MOVE  A DASH", STR_END
EsHelp1:       db "CRUZ MUEVE A DASH", STR_END
TxtHelp2:      db "CHAIN KILLS TO x9", STR_END
EsHelp2:       db "ENCADENA HASTA x9", STR_END
TxtLevelBanner: db "   -- LEVEL   --    ", STR_END
EsLevelBanner:  db "   -- NIVEL   --    ", STR_END
TxtCredit:     db "2026 STARFUN GAMES", STR_END
TxtIntro:      db "  PURGE THE CORE!   ", STR_END
EsIntro:       db "  PURGA EL NUCLEO!  ", STR_END
TxtWarden:     db "   -- WARDEN --     ", STR_END
EsWarden:      db "  -- GUARDIAN --    ", STR_END
TxtWardenDown: db "    WARDEN DOWN!    ", STR_END
EsWardenDown:  db "  GUARDIAN CAIDO!   ", STR_END
TxtLangEN:     db "SELECT: ESPANOL", STR_END
TxtLangES:     db "SELECT: ENGLISH", STR_END

INCLUDE "sound.asm"
INCLUDE "gfx.asm"
INCLUDE "tables.asm"
INCLUDE "boss.asm"

; ===============================================================
;  RAM
; ===============================================================
SECTION "ShadowOAM", WRAM0, ALIGN[8]
wShadowOAM: ds 160

SECTION "Vars", WRAM0
wVBlankDone: db
wKeys:      db
wKeysNew:   db
wFrame:     db
wRng:       dw
wSCX:       db
wSCY:       db
wBGP:       db
wWY:        db
wHud:       ds 20
wHudDirty:  db
wCopyLen:   db
wCopySrc:   dw
wCopyDst:   dw
wCopyBuf:   ds 20
wOamLo:     db
wTmp:       db
wTmp2:      db
wTmp3:      db
wBest:      ds 3
wPaused:    db
wLang:      db                  ; 0 = English, 1 = Spanish (SELECT on the title)
wCur:       ds EN_SIZE
; music
wMusOn:     db
wMusDrum:   db                  ; drum pattern 1..4, 0 = none
wSfxLock:   db                  ; frames left before the drums may use CH4 again
wMusSpeed:  db
wMelDuty:   db
wMelEnv:    db
wMusStart:  dw
wMusOrd:    dw
wMusRow:    db
wMusTick:   db
wMusMel:    dw
wMusBass:   dw

; everything below is cleared at the start of each game
wGameVars:
wPX:        dw
wPY:        dw
wInX:       db
wInY:       db
wFaceX:     db
wFaceY:     db
wDash:      db
wDashCD:    db
wDashKills: db
wGrace:     db
wDashBuf:   db
wAlive:     db
wTrail:     ds 16
wTrailIdx:  db
wEnemies:   ds MAX_EN * EN_SIZE
wParts:     ds MAX_PART * PART_SIZE
wScore:     ds 3
wCombo:     db
wKillsLvl:  db
wLevel:     db
wSpawnT:    db
wFreeze:    db
wShake:     db
wFlash:     db
wDeadT:     db
wOver:      db
wOverStep:  db
wNewBest:   db
wBanner:    db
wFlashKind: db
wWave:      db
wWaveAmp:   db
wTopY:      db                  ; top clamp for player and enemies (8, or 32 under the boss)
wBannerTxt: dw
wBannerLvl: db                  ; 1 = poke the level digit into the banner
wBoss:      db
wBossStep:  db
wBossT:     db
wBossNodes: db                  ; bit per node still intact
wBossNext:  db
wBossOpen:  db                  ; open node 0..2, $FF none
wBossOpenT: db
wBossAtk:   db
wBossBeam:  db
wBossBeamT: db
wBossBeamRow: db
wGameVarsEnd:

SECTION "HRAM", HRAM
hOAMDMA: ds DMARoutineEnd - DMARoutine
hStatMode: db                   ; 0 = title ripple, 1 = game wave
hParaA:     db                   ; title parallax SCX, top band
hParaB:     db                   ; title parallax SCX, band under the logo
hWavePhase: db
hWaveHi: db                     ; HIGH(wave table) for the current amplitude
