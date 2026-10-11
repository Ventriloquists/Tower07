# Tower 07: Harvest Protocol

An idle / incremental game built with [LÖVE](https://love2d.org/) in a clean, Oblivion-inspired sci-fi HUD style.

You are the last technician of Tower 07. Tap the reactor, build a harvesting fleet, pump hydro from the rigs, fabricate drones, push back scav raiders on the tactical map, loot crates and reboot the cycle for permanent Core Data. The tower keeps harvesting while you're away.

## Features

- **Reactor core**: tap for energy, build tap chains and trigger Core Surge. 1 in 1000 taps hits a jackpot.
  - **Core heat**: every tap heats the core. Keep it in the 75-95% sweet spot for x2.5 taps; hold the rhythm for 12s to ignite a free Core Surge. Mashing past 100% overheats and locks taps for 4s.
- **20 unit types** with milestone multipliers, 200+ tech upgrades, Smart Buy and hold-to-buy.
- **Hydro rigs**: tanks fill over time (even offline). Collect at peak pressure for a bonus.
- **Drone hangar**: every fabrication shows 3 drones and you keep 1. Five rarities (STD to OMEGA), traits, pity counters, upgrades and equippable modules. Every drone has a callsign; PROTO and OMEGA drones earn a second word.
- **Fusion**: drag a drone onto another of the same rarity (or press COMBINE) to fuse 3 into 1 of the next rarity. The result keeps the best MK and level, inherits traits, and returns modules to the vault.
- **PRISM / PRISMATIC**: a holographic top rarity for drones and modules with a rainbow foil look. Drop-only (best crates), never fabricated, fused or forged, and it gets the biggest Signal Lock moment (below).
- **Signal Lock (loot reveals)**: every drop speaks one language. A targeting reticle snaps onto the crate (or frames the drone card), the name decodes out of scrambled glyphs and a readout card pins beside it with what you got. Rarity scales the lock speed, the decode length and the frame: LEGENDARY adds a scan line across the screen, MYTHIC gold brackets on the screen corners, PRISM holographic brackets, a rainbow decode and one holo sweep over the HUD. No screen shake, no flashes, no banners; several drops at once stack their cards instead of overlapping.
- **Loot Fiesta**: mass fabrication (x10 / x25 / x50 / x100 / MAX) with free bonus pulls and one ELITE+ guaranteed per 10 pulls. The best of every 3 candidates is kept automatically, then a fusion cascade merges everything as far up as it can go, and overflow is recycled into parts.
- **Auto-fuse**: fuses every 3 drones of one rarity up to a rarity you choose, in the hangar and during fiestas. Lock favourite drones to keep them out of fusion and scrapping.
- **Fleet autopilot**: auto-loadout keeps the best modules on the strongest drones, auto-upgrade spends parts, auto-salvage recycles low-rarity modules.
- **Module forge** (vault): 3 modules of the same type, rarity and item level fuse into 1 at item level +1 (keeping the best roll); 10 modules of one rarity become 1 of the next rarity.
- **Mythic Altar**: feed 10 MYTHIC modules to forge a perk point whose cards are all ENHANCED or PRIME.
- **Tactical map**: fog of war, sector claiming, scav enemies, motherships, endless zones and loot crates in six rarities.
  - **Weather** changes every few minutes: TAILWIND (faster drones and missions), FOG (hidden scavs, crates one rarity higher), STORM (slower drones, double strike damage).
  - **Radiation sectors** take twice as long to claim but always drop an extra crate.
  - **TET uplink**: an orbital strike that charges over time and with every kill, hitting all scavs within 3 sectors.
  - **Map layers**: switch between TERRAIN, THREAT, LOOT and RADIATION overlays.
  - **Scav alert**: claiming sectors and destroying scavs raise the zone alert; at 100% the mothership arrives. More territory spawns more scavs, and drones far stronger than a sector claim it much faster, so a maxed fleet clears a zone in about 1.5 minutes.
  - **Mothership bounty**: kill the zone boss within 5 minutes for 2 LEGENDARY crates and 3 fab tokens. An alert follows you on every screen while it is alive.
- **Meta progression**: technician ranks with pick-1-of-3 perks, an endless Signal Track reward ladder, directives, a daily supply streak, timed world events and 300+ log entries.
- **Reboot (prestige)**: trade the cycle for Core Data and spend it in a zoomable, pannable protocol skill tree: 6 branches, 54 nodes, 200+ ranks (output, tapping, fleet, map range, salvage, signals).
- **Reactor saturation**: once a reboot would double your Core Data, output falls in proportion to how far past that line the run is (twice past = half output), a hard wall instead of a soft curve. Every reward worth "N seconds of production" (crates, directives, signals, offline time) uses the saturated output, so nothing bypasses it. One reboot can at most triple your Core Data, and that cap charges up over the first 60 minutes of a run (x2 after 30), so reboots cannot cascade in minutes.
- **Glossary**: every game term is highlighted in the UI and explained on hover.
- **Settings**: the COMMAND house style plus 70+ color themes (including high-contrast, colorblind-safe, memey and three unlockable themes), audio channels, comfort options (shake, flash, reduced motion), save export/import/backup, and quality-of-life extras:
  - **Boss key (F12)**: disguises the game as a spreadsheet or build log.
  - **Nap mode** and **eco mode** to save power.
  - **Touch-grass reminders**.
  - **Lazy mode**: automatically claims routine rewards.
  - **Memes**: a meme theme pack (memes only appear while one of these themes is active: real meme sound effects from the `sounds/` folder, Impact-font captions for big moments, press F to pay respects, meme chatter, meme rank titles and callsigns) (MLG PRO, MUCH DOGE, ILLUMINATI CONFIRMED, AMOGUS, THIS IS FINE, AVERAGE TOWER ENJOYER).
  - **Themes**: 50+ palettes, from proper (Blueprint, Sakura, Arctic) to memes (Hotdog Stand, MS Paint, Bliss.jpg) and cursed, nearly unplayable ones (F9 always resets the theme). Desktop-app themes (macOS with a magnifying Dock, Windows 11, YouTube, Reddit, Twitter) switch to rounded, shadowed panels, sentence case and the system font; **macOS GLASS** makes the window see-through on Windows. Warp themes move the whole screen (upside down, mirrored, drunk, DVD screensaver...) and stay clickable.

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
| Tab / Shift+Tab, Enter | Move keyboard focus between controls, press the focused one |
| P | Spend perk points |
| C | Collect all instant rewards (daily, logs, signal tiers, directives, peaked rigs) |
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

Sound effects are synthesized at startup; the meme themes can also play MP3s from `sounds/`. The game uses no image assets.

### Design system

**Structure.** The tower is one continuous place. The eight stations sit side by side on **the Spine** (bottom): a transit line where every station shows a live readout of what is happening there (perks waiting, tech ready, tank levels, crates, mothership, reboot gain, rewards), amber when something can be collected and red when it needs you now. Switching stations pans the camera along the line: the old station slides out, the new one slides in, and the background grid drifts with the trip. The **CORE** is the command center. The **reactor** in the middle is Tower 07 itself, in elevation above the cloud layer, and its crown is the core you tap. The crown's colour is the heat (ice, gold in the sweet spot, red, dark and steaming while venting), heat haze rises off it and the heat gauge wraps it (gold sweet-spot band, red overheat zone, rhythm building along the gold band). Taps compress the crown and roll a ripple across the clouds. SURGE collars light up the mast bottom to top; when they reach the deck the crown ignites (output x3). Production rises as shafts of light out of the clouds, one per unit type you run and brighter the more it contributes, with energy climbing each shaft and streaking across to the tower. Heat and surge are read off engineering callouts on the flanks. Around it: the **Action Stack** on the left (one COLLECT ALL command, key C, for every instant reward, then the things that need a decision or a trip, then NEXT UP progress), and **Telemetry** on the right (surge, chain and tap power, a PRODUCTION FLOW chart of the last minute plus each unit type's share of output, rigs, Signal Track).

The other stations follow the same line language: **OPS** puts the Signal Track on a road (tier nodes on one line, rewards above, your position on it, every visit opens at your next claim), the three directives as dossiers with progress rings, and a SCHEDULE with the daily streak, the live or next event and the event roster. **ARCHIVE** is a codex: the milestone line on top, the ~40 log series as an index with one tick per entry, and the selected series as a readable ladder (name, condition, reward, claim). **RIGS** is a flow diagram: tanks fill live through intake pipes, collecting sends the water down the manifold into the reserve, and the reserve tells you how many drone fabrications it buys. The **module vault** is a view of the HANGAR (FLEET / VAULT), not a pop-up, and you can switch the equip target drone without leaving it. MAP (already a spatial tactical view) and REBOOT (the zoomable protocol tree) keep their own layouts.


The house style is **COMMAND** (the default theme): graphite surfaces, ice-white interface light and one warm signal amber for anything that needs action. Every HUD theme shares the same building blocks; desktop-app themes (macOS, Windows, web) keep their own drawing.

- **Tokens** (`lib/hud.lua`): palette roles in `H.C` (`bg`, `panel`, `line` = interface light, `white` = text, `dim`, `faint` = separators, `orange` = action, `red` = danger, `gold` = reward), spacing `H.SP` (8 pt grid), motion speeds `H.MO`, easing curves `H.ease`, chamfer size `H.CUT`.
- **Silhouette**: panel-sized rectangles lose their top-left and bottom-right corners (`V.chamfer` in `lib/view.lua`); corner brackets follow the cut.
- **Type**: Bahnschrift for the interface, Franklin Gothic for display (`H.fonts.huge`, `d1`, `dxl`, `d2`, `d3`), falling back to Bahnschrift.
- **Components**: `H.button` (hover fill sweep, press sink, lock-on focus ticks, light sweep on primary actions, hatched disabled state), `H.card`, `H.rowFrame`, `H.segmented` (sliding selection), `H.heading`, `H.bar` (gliding fill with a lit leading edge), `H.focusRing`, `H.badge`.
- **Interaction**: idle controls are calm; hover fills, brightens the edge and runs one light sweep; press sinks 1px; a refused click shakes the control red and buzzes. The system cursor turns into a hand over anything clickable (the reactor included) and a "no" sign over disabled controls. **TAB / SHIFT+TAB** move a keyboard focus (lock-on corner ticks) through every control in reading order, **ENTER** presses it, **ESC** clears it. One filled call to action per area; red means danger only.
- **Layout grid**: every station shares one header band (`H.HEAD`): title at y 56 with its subtitle 16px after it (`H.screenTitle`), header controls at y 58 and 26px tall, content from y 92, 16px gutters between columns and cards.
- **Motion**: `H.tween` / `H.hoverT` give immediate-mode elements eased state. Stations pan side by side along the Spine (the marker travels the line with them), modals fade their backdrop and draw their frame, tooltips rise into place, banners open as a letterbox. **Reduced motion** (Settings > Comfort) snaps all of it and stops the background drift and grain.

**Self-test**: drives every system headlessly, captures screenshots and writes `selftest_result.txt` to its save folder.

```bash
love . --selftest
```

**Economy probes**: `--econdiag` writes every output multiplier of your real save to `econdiag.txt` (read-only), `--longrun` / `--longrun-reboot` simulate 12 / 24 hours from a fresh start, `--longrun-save` simulates 3 hours from a copy of your save.

**Pacing probe**: simulates a new player for 30 minutes and writes an unlock timeline to `pace.txt`.

```bash
love . --pace
```

**Zone pacing**: simulates a zone with a weak, a mid and a maxed fleet and writes clear times to `zonesim.txt`.

```bash
love . --zonesim
```

**Sandbox**: runs the normal game with a separate save folder (`tower_harvest_sandbox`), so your real save stays untouched. Any crash writes `crash.txt` to the save folder.

```bash
love . --sandbox
```

## Credits

The visual style is inspired by the UI graphics of *Oblivion* (2013). This is a fan-made, non-commercial project with no affiliation to the film.
