# Tower 07: Harvest Protocol

An idle / incremental game built with [LÖVE](https://love2d.org/) in a clean, Oblivion-inspired sci-fi HUD style.

You are the last technician of Tower 07. Tap the reactor, build a harvesting fleet, pump hydro from the rigs, fabricate drones, push back scav raiders on the tactical map, loot crates and reboot the cycle for permanent Core Data. The tower keeps harvesting while you're away.

## Features

- **Reactor core**: tap for energy, build tap chains and trigger Core Surge. 1 in 1000 taps hits a jackpot.
- **20 unit types** with milestone multipliers, 200+ tech upgrades, Smart Buy and hold-to-buy.
- **Hydro rigs**: tanks fill over time (even offline). Collect at peak pressure for a bonus.
- **Drone hangar**: every fabrication shows 3 drones and you keep 1. Five rarities (STD to OMEGA), traits, pity counters, upgrades and equippable modules.
- **Tactical map**: fog of war, sector claiming, scav enemies, motherships, endless zones and loot crates in six rarities.
- **Meta progression**: technician ranks with pick-1-of-3 perks, an endless Signal Track reward ladder, directives, a daily supply streak, timed world events and 300+ log entries.
- **Reboot (prestige)**: trade the cycle for Core Data and spend it in a five-branch protocol tree.
- **Glossary**: every game term is highlighted in the UI and explained on hover.
- **Settings**: 10 color themes (including a colorblind-safe palette and three unlockable themes), audio channels, comfort options (shake, flash, reduced motion), save export/import/backup, and quality-of-life extras:
  - **Boss key (F12)**: disguises the game as a spreadsheet or build log.
  - **Nap mode** and **eco mode** to save power.
  - **Touch-grass reminders**.
  - **Lazy mode**: automatically claims routine rewards.

## Running

1. Install [LÖVE 11.x](https://love2d.org/).
2. Clone the repo and run the folder:

```bash
love path/to/tower-harvest
```

On Windows:

```bash
"C:\Program Files\LOVE\love.exe" "C:\path\to\tower-harvest"
```

The window can be resized, and fullscreen is supported (F11).

## Controls

| Input | Action |
|---|---|
| Click / Space | Tap the core |
| Hold mouse | Keep buying |
| 1–8 | Switch scenes |
| P | Spend perk points |
| B | Cycle buy amount (x1 / x10 / x100 / MAX) |
| M | Mute |
| Esc | Back to CORE, or open settings |
| F11 / Alt+Enter | Fullscreen |
| F12 | Boss key |

## Saves

Progress autosaves and is stored in LÖVE's save directory (`%APPDATA%\LOVE\tower_harvest` on Windows). Settings are stored separately, so resetting your save keeps them. **Settings → Data** can export your save to the clipboard, import it, restore the last backup, or wipe the save.

## Development

```
main.lua            entry point, game loop, input, self-test
conf.lua            window config
lib/                virtual resolution scaling, HUD drawing primitives, keyword rendering
game/               game state & logic (core, tactical map, meta loops, data, glossary, settings, fx/audio)
ui/                 frame (top bar / dock / comms), one file per scene, overlays, settings, themes
```

All sound effects are synthesized at startup. The game uses no image or audio assets.

**Self-test**: drives every system headlessly, captures screenshots and writes `selftest_result.txt` to its save folder.

```bash
love . --selftest
```

**Pacing probe**: simulates a new player for 30 minutes and writes an unlock timeline to `pace.txt`.

```bash
love . --pace
```

## Credits

The visual style is inspired by the UI graphics of *Oblivion* (2013). This is a fan-made, non-commercial project with no affiliation to the film.
