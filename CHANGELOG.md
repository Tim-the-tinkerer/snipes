# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.0] — 2026-09-27

Adds an optional procedural ambient soundtrack while keeping all audio asset-free.

### Added

- **Procedural dark ambient music** — generated in real time with `AVAudioEngine`; no bundled music files.
- **Reactive tension** — the ambience responds to Snipe population, nearby threats, difficulty, and low lives.
- **Three music modes** — **OFF**, **LOW**, and **FULL**, cycled with **N** or the main-menu **MUSIC** button. The setting is remembered.
- **Atmospheric layers** — low beating drones, filtered electrical noise, sparse metallic clusters, dissonant overtones, and a low double-pulse danger layer.
- **Independent music path** — music uses its own player/level while retaining the existing synthesized effects. **M** still acts as the master game-audio mute.

### Changed

- Version bumped to **1.2.0** (build 3).


## [1.1.0] — 2026-09-27

Rule corrections and a small feedback pass on the 2D game.

### Fixed

- **Line of sight** — fog, enemy sight, and spawn checks follow the cells a straight segment actually enters, instead of a diagonal-then-straight dogleg.
- **Hive hit points** — A–J hives fall in one hit. Tough hives from letter K take two. The old path doubled `hiveResistance`, so ordinary hives took two hits and tough hives took four.
- **Reinforcements** — a new Snipe only appears in the neighborhood of a living hive. If none of those cells is a fair spawn, the game waits and tries again.

### Added

- **Hit and death feedback** — a short flash when a Snipe or hive is hit, a ring and a low pulse when a hive is destroyed, a two-frame swell on a step, a muzzle dot on a shot, and a screen flash with a half-second hold before respawn. Respawn shows **INVULNERABLE**. Explored fog clears on respawn, after that hold.
- **CRT look** — optional scanlines, a short phosphor trail, and a slight glow. Toggle with **C** or the menu **CRT** button. The choice is remembered.
- **Level banner** — starting a level names the rules that are on, such as **TOUGH HIVES** or **FASTER SNIPES**.
- **High scores** — the top ten runs are kept on this Mac. The best is shown on the menu and the game-over screen. Beating it shows **NEW HIGH SCORE**.
- **Audio balance** — repeated shots are quieter, slightly varied in pitch, and will not all stack at once.
- **Help documentation** — `docs/HELP.md` covering controls, gameplay, difficulty, scoring, fog of war, tips, and troubleshooting.
- **Help menu** — **Snipes Help** (⌘?) opens an in-app help window styled to match the game.

### Changed

- Version numbers restarted. The 2D releases formerly called 3.0.0 and 3.1.0 are **1.0.0** and **1.1.0**. Bundle version is **1.1.0** (build 2).

## [1.0.0] — 2026-07-14

Complete native macOS remake of the 1983 Novell classic. Replaces earlier web and 3D prototypes with a focused 2D top-down experience.

### Added

- **Native AppKit app** — Swift package with no browser, WebView, or external game engine.
- **2D top-down gameplay** — CRT-green maze graphics with a 60 fps render loop.
- **Original-style controls** — arrow keys for 8-way grid movement; WASD to shoot; Space + arrows to sprint.
- **Difficulty selection** — letter A–Z and level 1–9 on the in-game menu (e.g. A1 … Z9).
- **Procedural mazes** — recursive backtracker, Prim’s algorithm, rooms, braiding, and loops; fresh random seed on each level and restart.
- **Fog of war** — limited viewport (17×13) centered on the player; line-of-sight visibility within `visionRadius`.
- **Explored-path memory** — dim silhouettes for corridors seen during a life; fog resets on death.
- **Enemy spawning** — Snipes emerge from hive portals only when visible, with minimum distance and no line-of-sight to the player at spawn.
- **Difficulty scaling** — more enemies, faster shooting, and higher accuracy at higher letters; wall kills from letter S; tough hives from letter K.
- **Scoring** — points for Snipes, hives, maze clears, and life bonuses.
- **Synthesized audio** — procedural chiptune-style effects via `AVAudioEngine` (M toggles mute).
- **In-game UI** — main menu, pause (P), game over, and maze-cleared screens.
- **App icon** — generated via `MakeIcon` target and bundled as `AppIcon.icns`.
- **Build pipeline** — `build-app.sh` compiles, signs, bundles, and installs to `~/Applications/Snipes.app`.
- **macOS menu bar** — standard Snipes application menu.
- **About Snipes** — standard About panel with version, original SuperSet credits, and control summary.
- **Quit** — ⌘Q and **Quit Snipes** menu item.
- **README** — build instructions, controls, gameplay notes, and troubleshooting.

### Changed

- Project renamed from `snipes-3d` to `snipes` to reflect the 2D design.
- Bundle version set to **1.0.0** (build 1) in `AppInfo.plist`. This is the first numbered release. An earlier numbering called it 3.0.0; that numbering was retired in 1.1.0.

### Removed

- Web-based prototype (`index.html`, `js/`, `vendor/`).
- Earlier macOS 3D experiment code (`macos/`).
- Legacy **Snipes 3D** app install path (`~/Applications/Snipes 3D.app`).

## Early prototypes — superseded

These experiments came before version 1.0.0. They are not numbered releases. Their code was removed in 1.0.0.

### Browser prototype

Initial browser-based 3D prototype built with HTML/JavaScript. Served as a proof of concept for Snipes mechanics.

### Native 3D prototype

Early native macOS 3D prototype. Explored first-person maze rendering before the project pivoted to a faithful 2D top-down model.

---

**Original Snipes (1983)** — Drew Major, Dale Neibaur, Mark Hurst, and Kyle Powell at SuperSet Software (distributed by Novell).