import Foundation

struct PlayerState {
    var x: Float = 0
    var z: Float = 0
    var cx: Int = 0
    var cy: Int = 0
    var facing: Int = 0
}

struct Snipe: Identifiable {
    let id = UUID()
    var x: Float
    var z: Float
    var cx: Int
    var cy: Int
    var dir: Int
    var moveTimer: Float
    var shootTimer: Float
    var pulse: Float = 0
    var alive = true
}

struct Hive: Identifiable {
    let id = UUID()
    var x: Int
    var y: Int
    var hp: Int
    var flash: Float = 0
    var alive = true
}

struct Impact {
    enum Kind {
        case hit
        case hiveDestroy
        case muzzle
    }

    var x: Float
    var z: Float
    var life: Float
    var maxLife: Float
    var kind: Kind
}

struct Bolt: Identifiable {
    let id = UUID()
    var x: Float
    var z: Float
    var dx: Float
    var dz: Float
    var life: Float
    var fromPlayer: Bool
}

enum GamePhase {
    case menu, playing, levelCleared, gameOver
}

@MainActor
final class GameEngine {
    var phase: GamePhase = .menu
    var letter: Character = "A"
    var number: Int = 1
    var score = 0
    var lives = 3
    var message = ""
    var paused = false
    var mazeDirty = true

    private(set) var config = LevelConfig.make(letter: "A", number: 1)
    private(set) var maze = Maze(seed: 0)
    private(set) var player = PlayerState()
    private(set) var snipes: [Snipe] = []
    private(set) var hives: [Hive] = []
    private(set) var bolts: [Bolt] = []
    private(set) var enemyBolts: [Bolt] = []
    private(set) var explored = Set<GridPoint>()
    private(set) var impacts: [Impact] = []
    private(set) var screenFlash: Float = 0
    private(set) var playerPulse: Float = 0
    private(set) var respawnInvuln: Float = 0
    private(set) var newHighScore = false
    var crtEnabled = UserDefaults.standard.bool(forKey: "snipes.crt") {
        didSet { UserDefaults.standard.set(crtEnabled, forKey: "snipes.crt") }
    }

    var keysDown = Set<UInt16>()

    private var fireCooldown: Float = 0
    private var spawnTimer: Float = 0
    private var messageTimer: Float = 0
    private var deathFreeze: Float = 0
    private var awaitingRespawn = false
    private var inputRepeatTimer: Float = 0
    private let dir4 = [(0, -1), (1, 0), (0, 1), (-1, 0)]
    private let arrowKeyCodes: Set<UInt16> = [123, 124, 126, 125]
    private let fireKeyCodes: Set<UInt16> = [0, 1, 2, 13]
    private let audio = AudioManager.shared

    var levelSummary: String { LevelConfig.make(letter: letter, number: number).summary }
    var snipesLeft: Int { snipes.filter(\.alive).count }
    var hivesLeft: Int { hives.filter(\.alive).count }

    var viewOrigin: GridPoint {
        GridPoint(
            x: player.cx - GameConstants.viewportW / 2,
            y: player.cy - GameConstants.viewportH / 2
        )
    }

    func cellVisible(_ x: Int, _ y: Int) -> Bool {
        let dist = hypot(Float(x - player.cx), Float(y - player.cy))
        guard dist <= Float(config.visionRadius) else { return false }
        return maze.lineOfSight(x0: player.cx, y0: player.cy, x1: x, y1: y)
    }

    func revealVisibleCells() {
        let r = config.visionRadius
        for dy in -r...r {
            for dx in -r...r {
                let x = player.cx + dx
                let y = player.cy + dy
                if cellVisible(x, y) {
                    explored.insert(GridPoint(x: x, y: y))
                }
            }
        }
    }

    func beginGame() {
        config = LevelConfig.make(letter: letter, number: number)
        score = 0
        lives = config.lives
        paused = false
        clearInput()
        startLevel()
        phase = .playing
        newHighScore = false
        showMessage(config.startBanner, seconds: 3.2)
        refreshMusicState()
    }

    func restartLevel() {
        guard phase == .playing || phase == .levelCleared else { return }
        paused = false
        clearInput()
        startLevel()
        phase = .playing
        showMessage(config.startBanner, seconds: 3.2)
        refreshMusicState()
    }

    func restartToMenu() {
        phase = .menu
        paused = false
        clearInput()
        refreshMusicState()
    }

    func nextLevel() {
        number += 1
        if number > 9 {
            number = 1
            if let idx = GameConstants.letters.firstIndex(of: letter) {
                letter = GameConstants.letters[(idx + 1) % 26]
            }
        }
        config = LevelConfig.make(letter: letter, number: number)
        paused = false
        clearInput()
        startLevel()
        phase = .playing
        showMessage(config.startBanner, seconds: 3.2)
        refreshMusicState()
    }

    private func clearInput() {
        keysDown.removeAll()
        inputRepeatTimer = 0
    }

    func pressKey(_ keyCode: UInt16) {
        guard phase == .playing, !paused else { return }
        if arrowKeyCodes.contains(keyCode) {
            performMoveAction()
            inputRepeatTimer = GameConstants.inputRepeatDelay
        } else if fireKeyCodes.contains(keyCode) {
            tryFire(keyCode: keyCode)
        }
    }

    private static func makeMazeSeed(config: LevelConfig) -> UInt32 {
        var seed = UInt32.random(in: 1...UInt32.max)
        seed ^= config.mazeSeed &* 0x9E37_79B9
        seed &+= UInt32.random(in: 1...UInt32.max)
        seed ^= UInt32(truncatingIfNeeded: UInt64(ProcessInfo.processInfo.systemUptime * 1000))
        return seed == 0 ? 1 : seed
    }

    private func startLevel() {
        maze = Maze(seed: Self.makeMazeSeed(config: config))
        let spawn = maze.cellToWorld(cx: maze.spawn.x, cy: maze.spawn.y)
        player = PlayerState(x: spawn.x, z: spawn.z, cx: maze.spawn.x, cy: maze.spawn.y, facing: 0)
        hives = maze.placeHives(count: config.hiveCount).map {
            Hive(x: $0.x, y: $0.y, hp: config.hiveResistance, alive: true)
        }
        snipes = []
        bolts = []
        enemyBolts = []
        fireCooldown = 0
        spawnTimer = 0
        respawnInvuln = 2.0
        deathFreeze = 0
        awaitingRespawn = false
        screenFlash = 0
        playerPulse = 0
        impacts.removeAll()
        mazeDirty = true
        explored.removeAll()
        revealVisibleCells()
        audio.play(.levelStart)
        for _ in 0..<config.maxSnipes { spawnSnipe(announce: false) }
    }

    func toggleCRT() {
        crtEnabled.toggle()
    }

    private func refreshMusicState() {
        guard phase == .playing else {
            audio.setMusicState(active: false, paused: false, intensity: 0, danger: 0)
            return
        }

        let aliveSnipes = snipes.filter(\.alive)
        let population = min(1, Float(aliveSnipes.count) / Float(max(1, config.maxSnipes)))
        let letterIndex = Float(GameConstants.letters.firstIndex(of: config.letter) ?? 0) / 25
        let numberPressure = Float(max(0, config.number - 1)) / 8
        let difficulty = min(1, letterIndex * 0.45 + numberPressure * 0.55)

        let nearest = aliveSnipes.map {
            hypot($0.x - player.x, $0.z - player.z)
        }.min() ?? GameConstants.cellSize * 12
        let nearby = max(0, 1 - nearest / (GameConstants.cellSize * 8))
        let lowLives: Float = lives <= 1 ? 1 : (lives == 2 ? 0.55 : 0)

        let intensity = min(1, population * 0.6 + difficulty * 0.4)
        let danger = min(1, population * 0.3 + nearby * 0.5 + lowLives * 0.25)

        audio.setMusicState(
            active: true,
            paused: paused,
            intensity: intensity,
            danger: danger
        )
    }

    func update(dt: Float) {
        guard phase == .playing, !paused, dt > 0 else { return }

        decayTransients(dt: dt)
        if deathFreeze > 0 {
            deathFreeze -= dt
            if deathFreeze <= 0 { finishDeath() }
            return
        }

        respawnInvuln = max(0, respawnInvuln - dt)
        updatePlayer(dt: dt)
        if deathFreeze > 0 { return }
        revealVisibleCells()
        updateSnipes(dt: dt)
        if deathFreeze > 0 { return }
        updateBolts(dt: dt)
        if deathFreeze > 0 { return }
        updateSpawning(dt: dt)
        checkWin()
        snipes.removeAll { !$0.alive }
        refreshMusicState()
    }

    private func decayTransients(dt: Float) {
        messageTimer -= dt
        if messageTimer <= 0 { message = "" }
        if screenFlash > 0 { screenFlash = max(0, screenFlash - dt / 0.22) }
        if playerPulse > 0 { playerPulse = max(0, playerPulse - dt) }
        for i in hives.indices where hives[i].flash > 0 {
            hives[i].flash = max(0, hives[i].flash - dt)
        }
        for i in snipes.indices where snipes[i].pulse > 0 {
            snipes[i].pulse = max(0, snipes[i].pulse - dt)
        }
        if impacts.isEmpty { return }
        impacts = impacts.compactMap { impact in
            var impact = impact
            impact.life -= dt
            return impact.life > 0 ? impact : nil
        }
    }

    func togglePause() {
        guard phase == .playing else { return }
        paused.toggle()
        if paused { clearInput() }
        refreshMusicState()
    }

    func consumeMazeDirty() -> Bool {
        guard mazeDirty else { return false }
        mazeDirty = false
        return true
    }

    private func updatePlayer(dt: Float) {
        updateInputRepeat(dt: dt)
        fireCooldown = max(0, fireCooldown - dt)
    }

    private func anyArrowHeld() -> Bool {
        !keysDown.isDisjoint(with: arrowKeyCodes)
    }

    private func updateInputRepeat(dt: Float) {
        guard anyArrowHeld() else {
            inputRepeatTimer = 0
            return
        }
        inputRepeatTimer -= dt
        if inputRepeatTimer <= 0 {
            performMoveAction()
            inputRepeatTimer = GameConstants.inputRepeatRate
        }
    }

    private func arrowMoveDirection() -> Int? {
        let left = keysDown.contains(123)
        let right = keysDown.contains(124)
        let down = keysDown.contains(125)
        let up = keysDown.contains(126)
        if left && right { return nil }
        if up && down { return nil }

        switch (up, down, left, right) {
        case (true, false, false, false): return 0
        case (true, false, false, true): return 1
        case (false, false, false, true): return 2
        case (false, true, false, true): return 3
        case (false, true, false, false): return 4
        case (false, true, true, false): return 5
        case (false, false, true, false): return 6
        case (true, false, true, false): return 7
        default: return nil
        }
    }

    private func performMoveAction() {
        guard let dir = arrowMoveDirection() else { return }
        let steps = keysDown.contains(49) ? 2 : 1
        movePlayerGrid(dir: dir, steps: steps)
    }

    private func movePlayerGrid(dir: Int, steps: Int) {
        var cx = player.cx
        var cy = player.cy
        let delta = GameConstants.dir8[dir]

        for _ in 0..<steps {
            let nx = cx + delta.0
            let ny = cy + delta.1
            if !maze.isWalkable(nx, ny) {
                if config.wallKills, maze.isWall(nx, ny) { die(reason: "WALL IMPACT!", sound: .explodePlayer) }
                break
            }
            cx = nx
            cy = ny
        }

        let moved = cx != player.cx || cy != player.cy
        let world = maze.cellToWorld(cx: cx, cy: cy)
        player.x = world.x
        player.z = world.z
        player.cx = cx
        player.cy = cy
        player.facing = dir
        if moved { playerPulse = 0.04 }
        revealVisibleCells()
    }

    private func fireDirection(for keyCode: UInt16) -> Int? {
        switch keyCode {
        case 13: return 0
        case 2: return 2
        case 1: return 4
        case 0: return 6
        default: return nil
        }
    }

    private func tryFire(keyCode: UInt16) {
        guard fireCooldown <= 0, let dir = fireDirection(for: keyCode) else { return }
        firePlayerBolt(dir: dir)
        fireCooldown = GameConstants.fireCooldown
    }

    private func firePlayerBolt(dir: Int) {
        let d = GameConstants.dir8[dir]
        let len = max(0.001, hypot(Float(d.0), Float(d.1)))
        let dx = Float(d.0) / len
        let dz = Float(d.1) / len
        bolts.append(Bolt(
            x: player.x, z: player.z,
            dx: dx, dz: dz,
            life: GameConstants.boltLifetime, fromPlayer: true
        ))
        addImpact(x: player.x + dx * 0.55, z: player.z + dz * 0.55, life: 0.034, kind: .muzzle)
        audio.play(.bullet)
    }

    private func updateSnipes(dt: Float) {
        let pc = maze.worldToCell(wx: player.x, wz: player.z)
        for i in snipes.indices where snipes[i].alive {
            let sc = maze.worldToCell(wx: snipes[i].x, wz: snipes[i].z)
            snipes[i].cx = sc.x
            snipes[i].cy = sc.y
            let sees = maze.lineOfSight(x0: sc.x, y0: sc.y, x1: pc.x, y1: pc.y)

            snipes[i].moveTimer -= dt
            if snipes[i].moveTimer <= 0 {
                snipes[i].moveTimer = 0.25 + Float.random(in: 0...0.35)
                var dir = snipes[i].dir
                if sees, Float.random(in: 0...1) < 0.65 {
                    let dx = (pc.x - sc.x).signum()
                    let dy = (pc.y - sc.y).signum()
                    let options = (0..<4).filter { maze.isWalkable(sc.x + dir4[$0].0, sc.y + dir4[$0].1) }
                    let toward = options.filter { dir4[$0].0 == dx || dir4[$0].1 == dy }
                    if let pick = toward.randomElement() ?? options.randomElement() { dir = pick }
                } else {
                    let options = (0..<4).filter { maze.isWalkable(sc.x + dir4[$0].0, sc.y + dir4[$0].1) }
                    if let pick = options.randomElement() { dir = pick }
                }
                snipes[i].dir = dir
                let d = dir4[dir]
                if maze.isWalkable(sc.x + d.0, sc.y + d.1) {
                    let nw = maze.cellToWorld(cx: sc.x + d.0, cy: sc.y + d.1)
                    snipes[i].x = nw.x
                    snipes[i].z = nw.z
                    snipes[i].pulse = 0.04
                }
            }

            snipes[i].shootTimer -= dt
            if snipes[i].shootTimer <= 0, sees {
                snipes[i].shootTimer = config.snipeShootRate * Float.random(in: 0.7...1.3)
                if Float.random(in: 0...1) < config.snipeAccuracy {
                    let dx = Float(pc.x - sc.x)
                    let dy = Float(pc.y - sc.y)
                    let len = max(0.001, hypot(dx, dy))
                    let bx = dx / len
                    let bz = dy / len
                    enemyBolts.append(Bolt(x: snipes[i].x, z: snipes[i].z, dx: bx, dz: bz,
                                           life: GameConstants.boltLifetime * 0.8, fromPlayer: false))
                    addImpact(x: snipes[i].x + bx * 0.55, z: snipes[i].z + bz * 0.55, life: 0.034, kind: .muzzle)
                    audio.play(.spear)
                }
            }

            if respawnInvuln <= 0 {
                let dist = hypot(snipes[i].x - player.x, snipes[i].z - player.z)
                if dist < GameConstants.playerRadius + GameConstants.snipeRadius {
                    die(reason: "SNIPE COLLISION!", sound: .explodePlayer)
                    return
                }
            }
        }
    }

    private func updateBolts(dt: Float) {
        var kept: [Bolt] = []
        for var b in bolts {
            guard advance(&b, dt: dt) else { continue }
            var hit = false
            for i in snipes.indices where snipes[i].alive {
                if hypot(snipes[i].x - b.x, snipes[i].z - b.z) < GameConstants.snipeRadius + 0.2 {
                    addImpact(x: snipes[i].x, z: snipes[i].z, life: 0.08, kind: .hit)
                    snipes[i].alive = false
                    score += 100
                    showMessage("SNIPE +100")
                    audio.play(.explodeSnipe)
                    hit = true
                    break
                }
            }
            if hit { continue }
            for i in hives.indices where hives[i].alive {
                let w = maze.cellToWorld(cx: hives[i].x, cy: hives[i].y)
                if hypot(w.x - b.x, w.z - b.z) < 0.9 {
                    hives[i].hp -= 1
                    if hives[i].hp <= 0 {
                        hives[i].alive = false
                        maze.set(hives[i].x, hives[i].y, .floor)
                        addImpact(x: w.x, z: w.z, life: 0.42, kind: .hiveDestroy)
                        score += 250
                        showMessage("HIVE +250")
                        audio.play(.explodeHive)
                    } else {
                        hives[i].flash = 0.1
                        showMessage("HIVE HIT (\(hives[i].hp))")
                        audio.play(.hiveHit)
                    }
                    hit = true
                    break
                }
            }
            if !hit { kept.append(b) }
        }
        bolts = kept

        var keptEnemy: [Bolt] = []
        for var b in enemyBolts {
            guard advance(&b, dt: dt) else { continue }
            if respawnInvuln <= 0, hypot(b.x - player.x, b.z - player.z) < GameConstants.playerRadius + 0.15 {
                die(reason: "HIT!", sound: .explodePlayer)
                enemyBolts = []
                return
            }
            keptEnemy.append(b)
        }
        enemyBolts = keptEnemy
    }

    private func advance(_ b: inout Bolt, dt: Float) -> Bool {
        b.life -= dt
        if b.life <= 0 { return false }
        let steps = max(1, Int(ceil(GameConstants.boltSpeed * dt / 0.4)))
        let sub = dt / Float(steps)
        for _ in 0..<steps {
            let nx = b.x + b.dx * GameConstants.boltSpeed * sub
            let nz = b.z + b.dz * GameConstants.boltSpeed * sub
            let c = maze.worldToCell(wx: nx, wz: nz)
            if maze.isWall(c.x, c.y) { return false }
            b.x = nx
            b.z = nz
        }
        return true
    }

    private func updateSpawning(dt: Float) {
        let aliveH = hives.filter(\.alive).count
        let aliveS = snipes.filter(\.alive).count
        if aliveH == 0, aliveS == 0 { return }
        spawnTimer -= dt
        if spawnTimer <= 0, aliveS < config.maxSnipes, aliveH > 0 {
            spawnTimer = Float.random(in: 2.5...4.5)
            spawnSnipe(announce: true)
        }
    }

    private func spawnSnipe(announce: Bool) {
        guard snipes.filter(\.alive).count < config.maxSnipes else { return }
        let pc = maze.worldToCell(wx: player.x, wz: player.z)
        var occupied = Set(snipes.filter(\.alive).map { GridPoint(x: $0.cx, y: $0.cy) })
        occupied.insert(pc)

        // Beside a living hive, out of sight and away from the player.
        // If every hive neighborhood is blocked, wait for the next attempt.
        let minGridDist: Float = 7
        let minWorldDist = GameConstants.cellSize * minGridDist

        for hive in hives.filter(\.alive).shuffled() {
            if let cell = pickSpawnCell(
                around: GridPoint(x: hive.x, y: hive.y),
                playerCell: pc,
                minGridDist: minGridDist,
                minWorldDist: minWorldDist,
                excluding: occupied
            ) {
                addSnipe(at: cell, announce: announce)
                return
            }
        }
    }

    private func pickSpawnCell(
        around origin: GridPoint,
        playerCell: GridPoint,
        minGridDist: Float,
        minWorldDist: Float,
        excluding: Set<GridPoint>
    ) -> GridPoint? {
        var candidates: [GridPoint] = []
        for dy in -2...2 {
            for dx in -2...2 {
                let point = GridPoint(x: origin.x + dx, y: origin.y + dy)
                if isValidSpawnCell(
                    point, playerCell: playerCell,
                    minGridDist: minGridDist, minWorldDist: minWorldDist,
                    excluding: excluding
                ) {
                    candidates.append(point)
                }
            }
        }
        return candidates.randomElement()
    }

    private func isValidSpawnCell(
        _ point: GridPoint,
        playerCell: GridPoint,
        minGridDist: Float,
        minWorldDist: Float,
        excluding: Set<GridPoint>
    ) -> Bool {
        if excluding.contains(point) { return false }
        guard maze.isWalkable(point.x, point.y) else { return false }

        let gridDist = hypot(Float(point.x - playerCell.x), Float(point.y - playerCell.y))
        if gridDist < minGridDist { return false }

        let world = maze.cellToWorld(cx: point.x, cy: point.y)
        if hypot(world.x - player.x, world.z - player.z) < minWorldDist { return false }
        if maze.lineOfSight(x0: point.x, y0: point.y, x1: playerCell.x, y1: playerCell.y) { return false }

        return true
    }

    private func addSnipe(at cell: GridPoint, announce: Bool) {
        let w = maze.cellToWorld(cx: cell.x, cy: cell.y)
        snipes.append(Snipe(
            x: w.x, z: w.z, cx: cell.x, cy: cell.y,
            dir: Int.random(in: 0...3),
            moveTimer: Float.random(in: 0.2...0.6),
            shootTimer: Float.random(in: 1...3)
        ))
        if announce { audio.play(.snipeSpawn) }
    }

    private func checkWin() {
        guard phase == .playing else { return }
        if snipes.filter(\.alive).isEmpty, hives.filter(\.alive).isEmpty {
            score += 500 + lives * 100
            phase = .levelCleared
            clearInput()
            showMessage("MAZE CLEARED!")
            audio.play(.levelClear)
            refreshMusicState()
        }
    }

    private func die(reason: String, sound: GameSound = .explodePlayer) {
        guard phase == .playing, respawnInvuln <= 0, deathFreeze <= 0 else { return }
        lives -= 1
        showMessage(reason)
        bolts = []
        enemyBolts = []
        clearInput()
        screenFlash = 1
        deathFreeze = 0.5
        awaitingRespawn = lives > 0
        audio.play(sound)
        refreshMusicState()
    }

    private func finishDeath() {
        deathFreeze = 0
        if !awaitingRespawn {
            phase = .gameOver
            newHighScore = HighScores.record(score: score, level: config.label)
            audio.play(.gameOver)
            refreshMusicState()
            return
        }
        let s = maze.cellToWorld(cx: maze.spawn.x, cy: maze.spawn.y)
        player.x = s.x
        player.z = s.z
        player.cx = maze.spawn.x
        player.cy = maze.spawn.y
        player.facing = 0
        explored.removeAll()
        revealVisibleCells()
        respawnInvuln = 2
        awaitingRespawn = false
        showMessage("INVULNERABLE", seconds: 1.2)
    }

    private func addImpact(x: Float, z: Float, life: Float, kind: Impact.Kind) {
        impacts.append(Impact(x: x, z: z, life: life, maxLife: life, kind: kind))
    }

    private func showMessage(_ text: String, seconds: Float = 2.5) {
        message = text
        messageTimer = seconds
    }
}