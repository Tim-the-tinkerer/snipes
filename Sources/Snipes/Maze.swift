import Foundation

struct GridPoint: Hashable {
    var x: Int
    var y: Int
}

struct WorldPoint {
    var x: Float
    var z: Float
}

final class Maze {
    let width = GameConstants.mazeW
    let height = GameConstants.mazeH
    let seed: UInt32
    private(set) var grid: [Cell]
    private(set) var spawn = GridPoint(x: 1, y: 1)
    private var hiveSpots: [GridPoint] = []

    init(seed: UInt32) {
        self.seed = seed
        self.grid = Array(repeating: .wall, count: width * height)
        generate()
    }

    private func idx(_ x: Int, _ y: Int) -> Int { y * width + x }

    func inBounds(_ x: Int, _ y: Int) -> Bool {
        x >= 0 && y >= 0 && x < width && y < height
    }

    func get(_ x: Int, _ y: Int) -> Cell {
        guard inBounds(x, y) else { return .wall }
        return grid[idx(x, y)]
    }

    func set(_ x: Int, _ y: Int, _ value: Cell) {
        guard inBounds(x, y) else { return }
        grid[idx(x, y)] = value
    }

    func isWall(_ x: Int, _ y: Int) -> Bool {
        !inBounds(x, y) || get(x, y) == .wall
    }

    func isWalkable(_ x: Int, _ y: Int) -> Bool {
        let c = get(x, y)
        return c == .floor || c == .hive
    }

    func worldToCell(wx: Float, wz: Float) -> GridPoint {
        GridPoint(
            x: Int(floor(wx / GameConstants.cellSize + Float(width) / 2)),
            y: Int(floor(wz / GameConstants.cellSize + Float(height) / 2))
        )
    }

    func cellToWorld(cx: Int, cy: Int) -> WorldPoint {
        WorldPoint(
            x: (Float(cx) - Float(width) / 2 + 0.5) * GameConstants.cellSize,
            z: (Float(cy) - Float(height) / 2 + 0.5) * GameConstants.cellSize
        )
    }

    private func generate() {
        var rng = SeededRNG(seed: seed)
        grid = Array(repeating: .wall, count: width * height)

        switch seed % 4 {
        case 0:
            carveBacktracker(rng: &rng)
        case 1:
            carvePrim(rng: &rng)
        case 2:
            carveBacktracker(rng: &rng)
            carveExtraRooms(rng: &rng)
        default:
            carvePrim(rng: &rng)
            addLoops(rng: &rng, chance: 0.18 + rng.nextFloat() * 0.12)
        }

        addLoops(rng: &rng, chance: 0.10 + rng.nextFloat() * 0.18)
        braidDeadEnds(rng: &rng)
        addRandomShortcuts(rng: &rng)
        scatterOpenings(rng: &rng)
        pickSpawn(rng: &rng)
        pickHiveSpots(rng: &rng)
    }

    private func oddCells() -> [GridPoint] {
        var cells: [GridPoint] = []
        for y in stride(from: 1, to: height - 1, by: 2) {
            for x in stride(from: 1, to: width - 1, by: 2) {
                cells.append(GridPoint(x: x, y: y))
            }
        }
        return cells
    }

    private func carveBacktracker(rng: inout SeededRNG) {
        var starts = oddCells()
        starts.shuffle(using: &rng)
        guard let start = starts.first else { return }

        func carve(_ x: Int, _ y: Int) {
            var dirs = [(0, -2), (0, 2), (-2, 0), (2, 0)]
            dirs.shuffle(using: &rng)
            for (dx, dy) in dirs {
                let nx = x + dx
                let ny = y + dy
                if inBounds(nx, ny), get(nx, ny) == .wall {
                    set(x + dx / 2, y + dy / 2, .floor)
                    set(nx, ny, .floor)
                    carve(nx, ny)
                }
            }
        }

        set(start.x, start.y, .floor)
        carve(start.x, start.y)

        if rng.nextFloat() < 0.55, let second = starts.dropFirst().first(where: { get($0.x, $0.y) == .wall }) {
            set(second.x, second.y, .floor)
            carve(second.x, second.y)
            connectComponents(rng: &rng)
        }
    }

    private func carvePrim(rng: inout SeededRNG) {
        var starts = oddCells()
        starts.shuffle(using: &rng)
        guard let first = starts.first else { return }

        set(first.x, first.y, .floor)
        var inMaze: Set<GridPoint> = [first]
        var frontier: [(GridPoint, GridPoint)] = []

        func pushFrontier(from cell: GridPoint) {
            for (dx, dy) in [(0, -2), (0, 2), (-2, 0), (2, 0)] {
                let tx = cell.x + dx
                let ty = cell.y + dy
                let wx = cell.x + dx / 2
                let wy = cell.y + dy / 2
                let target = GridPoint(x: tx, y: ty)
                if inBounds(tx, ty), get(tx, ty) == .wall, !inMaze.contains(target) {
                    frontier.append((GridPoint(x: wx, y: wy), target))
                }
            }
        }

        pushFrontier(from: first)

        while !frontier.isEmpty {
            let pick = Int(rng.nextFloat() * Float(frontier.count))
            let (wall, target) = frontier.remove(at: pick)
            guard get(target.x, target.y) == .wall else { continue }
            set(wall.x, wall.y, .floor)
            set(target.x, target.y, .floor)
            inMaze.insert(target)
            pushFrontier(from: target)
        }
    }

    private func connectComponents(rng: inout SeededRNG) {
        var unvisited = oddCells().filter { get($0.x, $0.y) == .wall }
        guard !unvisited.isEmpty else { return }

        for _ in 0..<6 {
            guard let target = unvisited.randomElement(using: &rng) else { break }
            var best: (GridPoint, GridPoint)?
            var bestDist = Int.max

            for y in 1..<(height - 1) {
                for x in 1..<(width - 1) where get(x, y) == .floor {
                    let dist = abs(x - target.x) + abs(y - target.y)
                    if dist < bestDist {
                        bestDist = dist
                        best = (GridPoint(x: x, y: y), target)
                    }
                }
            }

            guard let (from, to) = best else { return }
            tunnel(from: from, to: to, rng: &rng)
            unvisited.removeAll { get($0.x, $0.y) == .floor }
        }
    }

    private func tunnel(from: GridPoint, to: GridPoint, rng: inout SeededRNG) {
        var x = from.x
        var y = from.y
        while x != to.x || y != to.y {
            set(x, y, .floor)
            if x != to.x, rng.nextFloat() < 0.8 {
                x += (to.x - x).signum()
            } else if y != to.y {
                y += (to.y - y).signum()
            } else {
                x += (to.x - x).signum()
            }
        }
        set(to.x, to.y, .floor)
    }

    private func addLoops(rng: inout SeededRNG, chance: Float) {
        for y in stride(from: 1, to: height - 1, by: 2) {
            for x in stride(from: 1, to: width - 1, by: 2) {
                if rng.nextFloat() < chance, get(x, y) == .wall {
                    set(x, y, .floor)
                    let options = [
                        (x + 1, y), (x, y + 1), (x - 1, y), (x, y - 1),
                    ].filter { inBounds($0.0, $0.1) && get($0.0, $0.1) == .wall }
                    if let pick = options.randomElement(using: &rng) {
                        set(pick.0, pick.1, .floor)
                    }
                }
            }
        }
    }

    private func braidDeadEnds(rng: inout SeededRNG) {
        let braidChance = 0.30 + rng.nextFloat() * 0.40
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) where get(x, y) == .floor {
                if floorNeighborCount(x, y) != 1 { continue }
                var dirs = [(1, 0), (-1, 0), (0, 1), (0, -1)]
                dirs.shuffle(using: &rng)
                for (dx, dy) in dirs where rng.nextFloat() < braidChance {
                    let wx = x + dx
                    let wy = y + dy
                    let tx = x + dx * 2
                    let ty = y + dy * 2
                    if inBounds(tx, ty), get(wx, wy) == .wall {
                        set(wx, wy, .floor)
                        if get(tx, ty) == .wall { set(tx, ty, .floor) }
                        break
                    }
                }
            }
        }
    }

    private func floorNeighborCount(_ x: Int, _ y: Int) -> Int {
        [
            (x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1),
        ].filter { inBounds($0.0, $0.1) && isWalkable($0.0, $0.1) }.count
    }

    private func carveExtraRooms(rng: inout SeededRNG) {
        let rooms = 2 + Int(rng.nextFloat() * 5)
        for _ in 0..<rooms {
            let cx = 2 + Int(rng.nextFloat() * Float(width - 5))
            let cy = 2 + Int(rng.nextFloat() * Float(height - 5))
            let rw = 2 + Int(rng.nextFloat() * 2)
            let rh = 2 + Int(rng.nextFloat() * 2)
            for dy in 0...rh {
                for dx in 0...rw {
                    let x = cx + dx
                    let y = cy + dy
                    if inBounds(x, y) { set(x, y, .floor) }
                }
            }
        }
    }

    private func addRandomShortcuts(rng: inout SeededRNG) {
        let punches = 8 + Int(rng.nextFloat() * 16)
        for _ in 0..<punches {
            let x = 1 + Int(rng.nextFloat() * Float(width - 2))
            let y = 1 + Int(rng.nextFloat() * Float(height - 2))
            guard get(x, y) == .wall else { continue }
            let neighbors = [
                (x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1),
            ].filter { inBounds($0.0, $0.1) && get($0.0, $0.1) == .floor }
            if neighbors.count >= 2 {
                set(x, y, .floor)
            }
        }
    }

    private func scatterOpenings(rng: inout SeededRNG) {
        let openings = 6 + Int(rng.nextFloat() * 12)
        for _ in 0..<openings {
            let x = 1 + Int(rng.nextFloat() * Float(width - 2))
            let y = 1 + Int(rng.nextFloat() * Float(height - 2))
            guard get(x, y) == .wall else { continue }
            let adjacentFloor = [
                (x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1),
            ].contains { inBounds($0.0, $0.1) && get($0.0, $0.1) == .floor }
            if adjacentFloor { set(x, y, .floor) }
        }
    }

    private func pickSpawn(rng: inout SeededRNG) {
        var candidates: [GridPoint] = []
        for y in 2..<(height - 2) {
            for x in 2..<(width - 2) {
                if get(x, y) == .floor, floorNeighborCount(x, y) >= 2 {
                    candidates.append(GridPoint(x: x, y: y))
                }
            }
        }
        if candidates.isEmpty {
            for y in 2..<(height - 2) {
                for x in 2..<(width - 2) where get(x, y) == .floor {
                    candidates.append(GridPoint(x: x, y: y))
                }
            }
        }
        candidates.shuffle(using: &rng)
        spawn = candidates.first ?? GridPoint(x: 1, y: 1)
    }

    private func pickHiveSpots(rng: inout SeededRNG) {
        let minDist = 5 + Int(rng.nextFloat() * 7)
        var floors: [(GridPoint, Int)] = []
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                if get(x, y) == .floor {
                    let dist = abs(x - spawn.x) + abs(y - spawn.y)
                    if dist > minDist { floors.append((GridPoint(x: x, y: y), dist)) }
                }
            }
        }
        floors.shuffle(using: &rng)
        floors.sort { a, b in
            if a.1 != b.1 { return a.1 > b.1 }
            return rng.nextFloat() < 0.5
        }
        hiveSpots = floors.prefix(16).map(\.0)
    }

    func placeHives(count: Int) -> [GridPoint] {
        var rng = SeededRNG(seed: seed &+ 404 &+ UInt32.random(in: 0...999_999))
        var spots = hiveSpots
        spots.shuffle(using: &rng)
        var placed: [GridPoint] = []
        for i in 0..<min(count, spots.count) {
            let p = spots[i]
            set(p.x, p.y, .hive)
            placed.append(p)
        }
        return placed
    }

    /// Cells the segment between the two centers enters. A step that passes
    /// through a grid corner advances diagonally, so a shallow line is not
    /// collapsed into a dogleg. A wall anywhere on that trace blocks sight.
    func lineOfSight(x0: Int, y0: Int, x1: Int, y1: Int) -> Bool {
        if isWall(x0, y0) || isWall(x1, y1) { return false }
        if x0 == x1 && y0 == y1 { return true }

        let dx = x1 - x0
        let dy = y1 - y0
        let nx = abs(dx)
        let ny = abs(dy)
        let signX = dx.signum()
        let signY = dy.signum()
        var x = x0
        var y = y0
        var ix = 0
        var iy = 0

        while ix < nx || iy < ny {
            let alongX = (1 + 2 * ix) * ny
            let alongY = (1 + 2 * iy) * nx
            if alongX == alongY {
                x += signX
                y += signY
                ix += 1
                iy += 1
            } else if alongX < alongY {
                x += signX
                ix += 1
            } else {
                y += signY
                iy += 1
            }
            if isWall(x, y) { return false }
        }
        return true
    }

    func randomFloorCell(minDistFrom: GridPoint?, excluding: Set<GridPoint> = []) -> GridPoint? {
        var cells: [GridPoint] = []
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let point = GridPoint(x: x, y: y)
                if excluding.contains(point) { continue }
                if isWalkable(x, y) {
                    if let minDistFrom {
                        let d = hypot(Float(x - minDistFrom.x), Float(y - minDistFrom.y))
                        if d < 6 { continue }
                    }
                    cells.append(point)
                }
            }
        }
        if let pick = cells.randomElement() { return pick }
        return nil
    }
}

struct SeededRNG: RandomNumberGenerator {
    private var state: UInt32
    init(seed: UInt32) { state = seed == 0 ? 1 : seed }
    mutating func next() -> UInt64 {
        state = state &* 1_664_525 &+ 1_013_904_223
        return UInt64(state)
    }
    mutating func nextFloat() -> Float {
        Float(next() % 10_000) / 10_000
    }
}

private extension Array {
    mutating func shuffle(using generator: inout SeededRNG) {
        guard count > 1 else { return }
        for i in stride(from: count - 1, through: 1, by: -1) {
            let j = Int(generator.next() % UInt64(i + 1))
            swapAt(i, j)
        }
    }

    func randomElement(using generator: inout SeededRNG) -> Element? {
        guard !isEmpty else { return nil }
        return self[Int(generator.next() % UInt64(count))]
    }
}