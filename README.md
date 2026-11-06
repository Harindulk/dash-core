# DASH CORE

A one-screen arcade game for the original Game Boy (DMG), written entirely in assembly
for [GBRetroDev'26: Heroes of ASM 3](https://itch.io/jam/gbretrodev26).

You are a small core in a closed arena. Touching anything kills you, unless you are
dashing. Dash through enemies to destroy them, and every kill inside a dash stretches
the dash and raises your multiplier, up to x9. A dash that hits nothing resets it. Splitters break into two drifters when you dash
through them, so one kill can feed a longer chain.

At levels 4, 7 and 10 the Warden drops in: a machine the width of the arena, drawn on the
background layer. It spits drifters in a line and sweeps a beam across your row. Its
three nodes open one at a time; dash into an open node to break it, break all three to
bring it down.

## Controls

| Button | Action |
|---|---|
| D-pad | Move (also sets dash direction, 8 ways) |
| A | Dash |
| START | Start / pause / retry |
| SELECT | On the title: switch between English and Spanish |

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
make test       # headless checks (needs Python with pyboy and pillow in .venv)
```

`tools/test_rom.py` plays the real ROM headless: dash kills and chains, wall limits,
death, save and reload after a power cycle, the whole Warden fight, a frame-budget test
(12 chasers and 12 particles, then the same with the Warden live, 60 game frames in
60 LCD frames) and 12,000 frames of random input. The Python files in `tools/` are test
and capture helpers only; nothing in them ends up in the ROM.

## What's inside

- `src/main.asm`: boot, interrupts, title, game loop, enemies, particles, HUD, text in
  two languages, SRAM save
- `src/boss.asm`: the Warden. Every change to its tiles goes through a one-slot VBlank
  copy queue, so each routine writes at most one tile run per frame
- `src/sound.asm`: a small pattern tracker on all four channels (pulse lead on CH2,
  triangle bass on CH3, noise drums on CH4) with four songs (title, game, boss, win).
  Sound effects use CH1 and borrow CH4 from the drums for a few frames. Effects are panned left or right (NR51) by where they happen
- `src/gfx.asm`: the font (1bpp, expanded at load) and all tiles, drawn as source
- `src/tables.asm`, `src/notes.inc`: note frequencies and the sine tables
- The big title letters are built at boot by scaling font glyphs 2x in code
- Raster: one HBlank (STAT mode 0) interrupt changes SCX per line. On the title it runs a
  three-band parallax (tread band left, logo ripple, tread band right); in game it draws the
  shockwave. The in-game one runs on hit-stop frames, when the game
  logic is idle, and grows with the chain
- Palette: fade-in from white at boot, a BGP cycle on level-up, a flash on death
- Game feel: hit-stop on kills, screen shake that decays, afterimages, input buffering
  for the dash, a blinking warning before each enemy appears

## License

MIT, see `LICENSE`. All graphics, music and code were made for this jam.
