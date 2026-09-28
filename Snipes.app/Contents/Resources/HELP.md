# Snipes Help

A native macOS remake of the 1983 Novell classic. Navigate procedural mazes, destroy Snipes and hive portals, and clear each level before you run out of lives.

---

## Getting started

1. Launch **Snipes** from `~/Applications/Snipes.app` (or run `./build-app.sh` to build and install).
2. On the main menu, choose a **difficulty letter** (A–Z) and **level number** (1–9).
3. Read the level summary (enemy count, hives, lives, and special rules).
4. Click **ENTER THE MAZE** or press the button to begin.
5. Destroy every **Snipe** and **hive** to clear the maze.

Click the game window if keyboard input does not respond — the window must have focus.

---

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

Movement repeats while you hold arrow keys. Shooting has a short cooldown between bolts.

---

## Objective

Clear the maze by eliminating:

- **Snipes** — orange enemies that roam the corridors and fire at you.
- **Hives** — red portal tiles that spawn new Snipes until destroyed.

You win when no Snipes and no hives remain. A **MAZE CLEARED** screen appears and you can advance to the next level.

You lose when you run out of lives. A **GAME OVER** screen lets you return to the main menu.

---

## Vision and fog of war

Snipes uses **limited vision**, like the original:

- You see only a **viewport** around your position (not the full maze).
- Tiles within your **vision radius** and **line of sight** are lit.
- Corridors you have seen before appear as **dim silhouettes** while you are alive.
- When you **respawn**, explored memory is **wiped** — the maze goes dark again until you re-explore. The maze holds for half a second first.

Snipes and hives are drawn only when they are currently visible. New Snipes spawn beside a living hive, out of your line of sight. You will not see them appear in front of you. If none of those cells is a fair spawn, the game waits.

---

## Enemies and hives

### Snipes

- Spawn periodically from living hives when the Snipe count is below the level maximum. They appear in the cells around a living hive, out of your line of sight. If none of those cells is a fair spawn, the game waits.
- Move through the maze and shoot when they have line of sight to you.
- Touching a Snipe costs a life.
- Destroying a Snipe awards **+100** points.
- A hit flashes the target. Destroying a hive also draws a short ring. Moving and shooting each show a brief pulse.

### Hives

- Fixed portal tiles placed when the maze is generated.
- One hit destroys a hive. **Tough hives** take two (see below).
- Destroying a hive awards **+250** points and stops spawns from that hive.
- Damaging a tough hive without destroying it shows remaining hit points.

---

## Difficulty (letter + number)

Difficulty follows the original **letter + number** scheme (e.g. **A1**, **M5**, **Z9**).

### Letter (A–Z)

Higher letters generally mean:

- More Snipes on the map at once
- Faster enemy shooting
- Better enemy accuracy
- More hive portals (from letter M onward)

Special rules by letter:

| Letter | Rule |
|--------|------|
| **K** and above | **Tough hives** — hives take two hits to destroy |
| **S** and above | **Wall kills** — moving into a wall is fatal |

### Number (1–9)

Higher numbers within a letter increase pressure (more Snipes, faster fire, fewer starting lives). Lower numbers are more forgiving.

The menu **summary line** describes the exact settings for your current selection, including **random maze** (layout changes every run).

When a level starts, a banner names the rules that are on for that letter and number: **TOUGH HIVES**, **WALL KILLS**, **FASTER SNIPES**, **SHARPER AIM**, **MORE SNIPES**, and **EXTRA HIVES**.

---

## Scoring

| Event | Points |
|-------|--------|
| Snipe destroyed | +100 |
| Hive destroyed | +250 |
| Maze cleared | +500, plus **+100 per remaining life** |

Your score is shown in the HUD at the top of the screen and on game-over / level-cleared panels.

The top ten scores are kept on this Mac. The best is shown on the main menu and the game-over screen as **BEST** plus the score and level. Beating it shows **NEW HIGH SCORE**.

---

## Maze layout

Each level uses a **procedurally generated maze**:

- Algorithms include recursive backtracker, Prim’s spanning tree, optional rooms, braiding, and extra loops.
- A **new random seed** is chosen when you start a level or press **R** to restart.
- The same letter/number can produce different layouts every time.

Maze size is **31×21** cells; your view shows a **17×13** window centered on the player.

---

## Pause, restart, and menus

- **P** pauses gameplay and shows **PAUSED** on screen. Press **P** again to resume.
- **R** restarts the current letter/number with a **fresh maze**; your score and lives carry over.
- After you die, the screen flashes and the maze holds for half a second. Respawn then shows **INVULNERABLE** while you cannot be hit.
- **C**, or the menu **CRT** button, toggles a restrained CRT look: scanlines, a short phosphor trail, and a slight glow. It is off until you turn it on, and the choice is remembered.
- **N**, or the menu **MUSIC** button, cycles the procedural soundtrack through **OFF**, **LOW**, and **FULL**. The choice is remembered.
- After **GAME OVER**, choose **BACK TO MENU** to change difficulty.
- After **MAZE CLEARED**, choose **NEXT LEVEL** to advance the level number. After **9**, the number returns to **1** and the letter advances. **Z9** continues at **A1**.

Closing the game window also quits the app.

---

## Sound and procedural music

All audio is synthesized in real time (no external audio files).

- **M** toggles all game audio, including the soundtrack.
- **N** cycles music through **OFF**, **LOW**, and **FULL**. You can also click the **MUSIC** button on the main menu.
- The music setting is remembered between launches.
- The soundtrack is deliberately atmospheric rather than melodic: low beating drones, filtered electrical noise, sparse metallic clusters, quiet dissonance, and—at higher danger—a low double pulse.
- **FULL** reacts more strongly to enemy pressure, nearby Snipes, difficulty, and low lives. **LOW** keeps the drone and sparse texture but removes most of the danger layer.
- Events include shots, explosions, hive hits, spawns, level start, level clear, and game over.
- A hive destruction is a low double pulse. A Snipe explosion is a short crackle. Your own death is a longer, lower hit.
- Repeated shots are quieter, slightly varied in pitch, and will not all stack at once.

---

## Application menu

Use the **Snipes** menu in the menu bar:

- **About Snipes** — version, credits, and a quick control summary
- **Hide Snipes** (⌘H), **Hide Others** (⌘⌥H), **Show All**
- **Quit Snipes** (⌘Q)

Use the **Help** menu:

- **Snipes Help** (⌘?) — opens this guide

---

## Tips

- Clear **hives early** to slow enemy reinforcements.
- Use **fog** to your advantage — listen for spawn sounds and advance carefully into unseen corridors.
- **Sprint** (Space) helps escape tight spots but can slam you into walls on **S+** difficulties.
- On higher letters, enemies shoot more often and more accurately — keep moving and fight from corridors with cover.
- Restart (**R**) if you dislike a maze layout; you get a new random map without returning to the menu.

---

## Troubleshooting

### Keyboard does not work

Click inside the game window so it has keyboard focus.

### No sound

Press **M** to ensure audio is enabled. Check macOS system volume and output device.

### Dock icon looks outdated after rebuild

Run `killall Dock` or log out and back in.

### Build or install issues

See **README.md** in the project folder for build steps and Terminal troubleshooting.

---

## About the original game

**Snipes** (1983) was created by Drew Major, Dale Neibaur, Mark Hurst, and Kyle Powell at SuperSet Software, and distributed by Novell. It was one of the first network games for IBM PCs and helped demonstrate Novell NetWare.

This remake is a personal project — a faithful top-down interpretation with modern macOS graphics and audio, not a commercial product.

---

## Version

Snipes **1.2.0** (build 3) — native macOS remake (AppKit, Swift).