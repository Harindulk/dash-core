# DASH CORE

A one-screen arcade game for the original Game Boy (DMG), written entirely in assembly
for [GBRetroDev'26: Heroes of ASM 3](https://itch.io/jam/gbretrodev26).

You are a small core in a closed arena. Touching anything kills you, unless you are
dashing. Dash through enemies to destroy them, and every kill inside a dash stretches
the dash and raises your multiplier, up to x9. A dash that hits nothing resets it.

## Controls

| Button | Action |
|---|---|
| D-pad | Move (also sets dash direction, 8 ways) |
| A | Dash |
| START | Start / pause / retry |

The arrow in front of the core shows the dash direction and only appears when the dash
is ready. The box in the HUD fills up while it recharges.

## Cartridge

- Cartridge type 3: MBC1 + RAM + BATTERY
- 32 KiB ROM, 8 KiB SRAM (only the best score is stored, with a magic tag and checksum)
- DMG only, tested in Emulicious and PyBoy

## Building

Needs [RGBDS](https://rgbds.gbdev.io) 1.0 or newer.

```sh
make            # builds build/dashcore.gb
make dist       # dist/DashCore.gb + source zip
```

`make test` runs the headless checks in `tools/test_rom.py` (needs Python with
`pyboy` and `pillow`). The Python files in `tools/` are test and capture helpers only;
nothing in them ends up in the ROM.

## What's inside

- `src/main.asm`: boot, interrupts, title, game loop, enemies, particles, HUD, SRAM save
- `src/sound.asm`: a small pattern tracker (pulse lead on CH2, triangle bass on CH3)
  plus sound effects on CH1 and CH4, so effects never cut the music
- `src/gfx.asm`: the font (1bpp, expanded at load) and all tiles, drawn as source
- `src/tables.asm`, `src/notes.inc`: note frequencies and the sine used by the title
- The big title letters are built at boot by scaling font glyphs 2x in code
- The title ripple is an HBlank (STAT mode 0) interrupt that changes SCX per line
- Game feel: hit-stop on kills, screen shake that decays, palette flash, afterimages,
  input buffering for the dash, a blinking warning before each enemy appears

## License

MIT, see `LICENSE`. All graphics, music and code were made for this jam.
