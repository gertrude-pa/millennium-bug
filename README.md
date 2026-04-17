# Millennium Bug

A Y2K-themed 4-player local arena brawler for Xbox 360 wireless pads (or keyboard).
Built in Godot 4.6 over a weekend for a Y2K party. Last sysadmin standing wins the millennium.

![engine](https://img.shields.io/badge/engine-Godot_4.6-478CBF)
![players](https://img.shields.io/badge/players-1--4_local-ff00aa)
![vibe](https://img.shields.io/badge/vibe-Y2K-ffee00)

## What's in the box

- **Twin-stick arena brawler** — move with left stick, aim with right, throw floppy disks
- **3 lives × 3 rounds** — best of three rounds wins the match
- **Pickups** — CD-ROM (piercing shots), 56K modem (speed boost), floppy stack (3-way spread)
- **BSOD hazard** — a blue screen of death sweeps across the arena periodically; touch it, lose a life
- **Clippy popups** — "It looks like you're trying to survive Y2K. Would you like help?"
- **Scrolling Y2K news marquee** — Napster, Pets.com, Furby, ICQ, AOL free hours, all your base…
- **Win98 death dialogs** — "PLAYER2.EXE has performed an illegal operation"
- **CRT shader** — scanlines, barrel curvature, chromatic aberration, vignette
- **Dial-up round intro** — CONNECTING → HANDSHAKE → CONNECTED / FIGHT!

## Running it

1. Install **Godot 4.6** (Standard, not .NET): https://godotengine.org/download/windows/
2. Plug in the Xbox 360 wireless receiver; pair all 4 pads
3. Confirm Windows sees all 4 in Control Panel → *Set up USB game controllers*
4. Open Godot → Import → point at this folder's `project.godot` → press F5

Keyboard fallback if no pad is on slot 1: **WASD** move, **mouse** aim, **Space** / **LMB** throw.

## Controls (per pad)

| Input | Action |
| --- | --- |
| Left stick | Move |
| Right stick | Aim |
| A button / Right trigger | Throw floppy |

Pickups auto-apply on contact. Pickups show a glowing ring around the player while active.

## Project layout

```
project.godot          Godot project config (main scene = title.tscn)
scenes/
  title.tscn           Title screen (CRT + fake Win98 taskbar)
  main.tscn            Arena root (HUD + CRT overlay)
  player.tscn          Per-player CharacterBody2D
  floppy.tscn          Projectile (Area2D)
  pickup.tscn          CD / Modem / Floppy stack pickup
  bsod.tscn            BSOD sweep hazard
scripts/
  title.gd             Title screen (floating clip-art, rotating tips, any-key boot)
  game.gd              Round/match flow, spawners, HUD, marquee, death popups
  player.gd            Twin-stick, pickups, CRT-monitor sprite
  floppy.gd            Projectile motion, piercing mode
  pickup.gd            CD / Modem / Floppy-stack draw + effect
  bsod.gd              Vertical sweep hazard
  clippy.gd            Sliding speech-bubble popup with rotating quips
  clippy_draw.gd       Paperclip-with-googly-eyes draw helper
shaders/
  crt.gdshader         Scanlines + curvature + chromatic aberration + vignette
```

## Tuning knobs

Feel is controlled by a handful of constants. First stops if something feels off:

- `player.gd` — `BASE_SPEED` (340), `ACCEL`, `FRICTION`, `PICKUP_SPEED_MULT` (1.6), `PICKUP_PIERCE_SHOTS` (4), `PICKUP_SPREAD_SHOTS` (12), `HIT_INVULN` (0.6s)
- `floppy.gd` — `SPEED` (720), `LIFETIME` (1.4s)
- `bsod.gd` — `SPEED` (160), `WIDTH` (180)
- `game.gd` — pickup/BSOD/Clippy timer ranges in `_process`, marquee scroll speed in `_tick_marquee`
- `shaders/crt.gdshader` — set via `ShaderMaterial` params in `main.tscn` (`scanline_strength`, `curvature`, `chromatic`, `vignette`)

## Known sharp edges

- Controller slots are assigned in connection order. Scores are keyed by `device_id`, so a reconnect keeps a player's round wins.
- The CRT shader uses `hint_screen_texture`. If performance tanks, drop `curvature` first, then disable the CRT layer entirely.
- On Godot 4.6's first import, you may see "invalid UID" warnings — let it finish reimporting and press F5 again.
- Keyboard fallback only applies to P1 (device id -1). P2–P4 require pads.

## Credits

- Built in Godot 4.6 with GDScript.
- Clippy, BSOD, Win98 taskbar, dial-up, Napster, Pets.com, ICQ, AOL, Furby, and Tamagotchi — all © their respective late-90s overlords. No likeness used, just vibes.
