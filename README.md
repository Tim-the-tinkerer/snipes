# Snipes

A native macOS remake of the 1983 Novell classic **Snipes** — a top-down maze shooter with CRT-green graphics, limited vision, procedural mazes, and retro synthesized audio.

**Version 1.2.0** (build 3).

## Requirements

- macOS 13 or later
- Xcode Command Line Tools or full Xcode (for `swift`, `codesign`, and `iconutil`)

```bash
xcode-select --install
```

## Quick start

Build, package, and install the app:

```bash
cd /Users/timbestler/Apps-Games/snipes
./build-app.sh
open ~/Applications/Snipes.app
```

`build-app.sh` will:

1. Generate `AppIcon.icns` (via `make-icon.sh`)
2. Compile the game in release mode
3. Assemble `Snipes.app`
4. Copy it to `~/Applications/Snipes.app`

### Run without installing

```bash
swift build -c release
.build/release/Snipes
```

## Help

Full in-app and offline documentation: **[docs/HELP.md](docs/HELP.md)**

In the running app, open **Help → Snipes Help** (⌘?) for the same guide in a help window.

## Controls

| Key | Action |
|-----|--------|
| **↑ ↓ ← →** | Move one maze cell (8 directions; hold two arrows for diagonals) |
| **W** | Shoot upward |
| **A** | Shoot left |
| **S** | Shoot downward |
| **D** | Shoot right |
| **Space + arrows** | Sprint (two cells per step) |
| **P** | Pause / resume |
| **R** | Restart level (new random maze) |
| **M** | Toggle all game audio |
| **N** | Cycle procedural music: **OFF → LOW → FULL** |
| **C** | Toggle the CRT look |
| **⌘?** | Open Snipes Help |
| **⌘Q** | Quit Snipes |

Click the game window if keyboard input does not respond — the window must have focus.

## Gameplay

- Destroy all **Snipes** and **hive portals** to clear the maze.
- Snipes spawn beside a living hive, out of your line of sight. If none of those cells is a fair spawn, the game waits.
- Each level uses a **random maze** — layout changes every run and restart.
- You see only a **limited viewport** around your position; unexplored areas stay dark.
- Previously explored corridors show as dim silhouettes during a life, but **fog resets when you respawn**. The maze holds for half a second first.

### Difficulty (letter + number)

Difficulty follows the original **letter + number** scheme (e.g. **A1**, **M5**, **Z9**).

Higher letters generally mean:

- More Snipes on the map at once
- Faster enemy shooting
- Better enemy accuracy
- More hive portals (from letter M onward)

| Letter | Rule |
|--------|------|
| **K** and above | **Tough hives** — hives take two hits to destroy |
| **S** and above | **Wall kills** — moving into a wall is fatal |

Higher numbers within a letter increase pressure (more Snipes, faster fire, fewer starting lives). Lower numbers are more forgiving.

The menu **summary line** describes the exact settings for your current selection, including **random maze** (layout changes every run).

When a level starts, a banner names the rules that are on for that letter and number: **TOUGH HIVES**, **WALL KILLS**, **FASTER SNIPES**, **SHARPER AIM**, **MORE SNIPES**, and **EXTRA HIVES**.

### Scoring

| Event | Points |
|-------|--------|
| Snipe destroyed | +100 |
| Hive destroyed | +250 |
| Maze cleared | +500, plus **+100 per remaining life** |

The top ten scores are kept on this Mac. The best is shown on the main menu and the game-over screen as **BEST** plus the score and level. Beating it shows **NEW HIGH SCORE**.

After you die, the screen flashes and the maze holds for half a second. Respawn then shows **INVULNERABLE** while you cannot be hit.

A hit flashes the target. Destroying a hive also draws a short ring. Moving and shooting each show a brief pulse.

**C**, or the menu **CRT** button, toggles a restrained CRT look: scanlines, a short phosphor trail, and a slight glow. It is off until you turn it on, and the choice is remembered.

**N**, or the menu **MUSIC** button, cycles the procedural soundtrack through **OFF**, **LOW**, and **FULL**. The choice is remembered. Music is generated in real time from low drones, filtered noise, sparse metallic clusters, and a subtle danger pulse. It reacts to enemy pressure, nearby Snipes, difficulty, and low lives without becoming a repeating melody.

After **MAZE CLEARED**, choose **NEXT LEVEL** to advance the level number. After **9**, the number returns to **1** and the letter advances. **Z9** continues at **A1**.

## Project layout

```
snipes/
├── Package.swift              # Swift package (Snipes + MakeIcon)
├── AppInfo.plist              # macOS bundle metadata
├── build-app.sh               # Build, sign, and install
├── make-icon.sh               # Generate AppIcon.icns
├── AppIcon.icns               # Built app icon (generated)
├── Assets/
│   └── icon-1024.png          # Master icon image (generated)
├── docs/
│   └── HELP.md                # Full help documentation
├── Sources/
│   ├── Snipes/
│   │   ├── SnipesApp.swift        # App entry point, app & help menus
│   │   ├── HelpWindowController.swift  # In-app help window (⌘?)
│   │   ├── GameWindowController.swift  # Window, menu, keyboard
│   │   ├── GameEngine.swift       # Rules, physics, AI, scoring
│   │   ├── HighScores.swift       # Top ten scores kept on this Mac
│   │   ├── Maze.swift             # Procedural maze generation
│   │   ├── MazeRenderer.swift     # 2D view, fog of war
│   │   ├── TopDownView.swift      # Render loop
│   │   ├── GameConfig.swift       # Levels, constants, palette
│   │   └── AudioManager.swift     # Synthesized effects + procedural ambient music
│   └── MakeIcon/
│       └── main.swift             # Icon generator
└── Snipes.app                 # Local build output (generated)
```

Installed copy: `~/Applications/Snipes.app`

## Building

### Full app bundle

```bash
./build-app.sh
```

### Icon only

```bash
./make-icon.sh
# or
swift run -c release MakeIcon
```

### Debug build

```bash
swift build
swift run Snipes
```

## Troubleshooting

### Terminal shows “A session ended very soon after starting”

This is a **Terminal profile warning**, not a build failure. It appears when the shell exits immediately (for example after `build-app.sh; exit`).

**Fix:** Run the script without `; exit`, or in Terminal → Settings → Profiles → Default, disable “Close if the shell exited cleanly”.

### Dock icon does not update

```bash
killall Dock
```

Or log out and back in.

### `codesign` or Xcode tools missing

Install command line tools:

```bash
xcode-select --install
```

### Build succeeds but no icon

Ensure `make-icon.sh` ran (you should see `Building app icon...` in the output). Regenerate manually:

```bash
bash ./make-icon.sh
./build-app.sh
```

## Architecture notes

- **Native AppKit** — no browser, WebView, or external game engine
- **Grid movement** — faithful to the original keyboard model
- **Fog of war** — line-of-sight visibility within `visionRadius`; viewport centered on the player
- **Maze generation** — multiple algorithms (recursive backtracker, Prim’s, rooms, braiding) with a fresh random seed each level
- **Audio** — procedural effects and a reactive dark ambient soundtrack via `AVAudioEngine` (no bundled sound files). Repeated shots are quieter, slightly varied in pitch, and will not all stack at once. Music can be OFF/LOW/FULL and reacts to game pressure
- **Version 1.2.0** (build 3) — see [CHANGELOG.md](CHANGELOG.md)

## License

Personal remake project. Original Snipes (1983) was created by Drew Major, Dale Neibaur, Mark Hurst, and Kyle Powell at SuperSet Software.