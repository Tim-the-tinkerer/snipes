import Foundation
import CoreGraphics

enum Cell: UInt8 {
    case floor = 0
    case wall = 1
    case hive = 2
}

enum GameConstants {
    static let mazeW = 31
    static let mazeH = 21
    static let cellSize: Float = 2
    static let tilePixels: CGFloat = 32
    static let playerRadius: Float = 0.35
    static let snipeRadius: Float = 0.4
    static let boltSpeed: Float = 22
    static let boltLifetime: Float = 1.1
    static let fireCooldown: Float = 0.22
    static let moveStep: Float = cellSize
    static let inputRepeatDelay: Float = 0.22
    static let inputRepeatRate: Float = 0.11
    static let dir8: [(Int, Int)] = [
        (0, -1), (1, -1), (1, 0), (1, 1),
        (0, 1), (-1, 1), (-1, 0), (-1, -1),
    ]
    static let viewportW = 17
    static let viewportH = 13
    static let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    static var mazePixelWidth: CGFloat { CGFloat(mazeW) * tilePixels }
    static var mazePixelHeight: CGFloat { CGFloat(mazeH) * tilePixels }
}

struct LevelConfig {
    let letter: Character
    let number: Int
    let label: String
    let mazeSeed: UInt32
    let maxSnipes: Int
    let hiveCount: Int
    let lives: Int
    let snipeShootRate: Float
    let snipeAccuracy: Float
    let wallKills: Bool
    let hiveResistance: Int
    let visionRadius: Int

    static func make(letter: Character, number: Int) -> LevelConfig {
        let li = max(0, min(25, GameConstants.letters.firstIndex(of: letter) ?? 0))
        let ni = max(1, min(9, number))
        return LevelConfig(
            letter: letter,
            number: ni,
            label: "\(letter)\(ni)",
            mazeSeed: UInt32(li * 97 + ni * 131),
            maxSnipes: 3 + ni * 2 + li / 8,
            hiveCount: 1 + ni / 3 + (li >= 13 ? 1 : 0),
            lives: 4 + (9 - ni) / 2,
            snipeShootRate: max(0.8, 2.8 - Float(ni) * 0.2 - Float(li) * 0.03),
            snipeAccuracy: 0.25 + Float(ni) * 0.05 + Float(li) * 0.015,
            wallKills: li >= 18,
            hiveResistance: li >= 10 ? 2 : 1,
            visionRadius: 9 + ni / 2
        )
    }

    var summary: String {
        var parts = ["\(maxSnipes) snipes", "\(hiveCount) hive\(hiveCount == 1 ? "" : "s")", "\(lives) lives"]
        if wallKills { parts.append("wall kills") }
        if hiveResistance > 1 { parts.append("tough hives") }
        return "\(label) — \(parts.joined(separator: ", ")), random maze"
    }

    /// Rules that differ enough from A1 to name on the level banner.
    var ruleTags: [String] {
        let base = LevelConfig.make(letter: "A", number: 1)
        var tags: [String] = []
        if hiveResistance > 1 { tags.append("TOUGH HIVES") }
        if wallKills { tags.append("WALL KILLS") }
        if snipeShootRate <= base.snipeShootRate - 0.3 { tags.append("FASTER SNIPES") }
        if snipeAccuracy >= base.snipeAccuracy + 0.15 { tags.append("SHARPER AIM") }
        if maxSnipes >= base.maxSnipes + 4 { tags.append("MORE SNIPES") }
        if hiveCount > base.hiveCount { tags.append("EXTRA HIVES") }
        return tags
    }

    var startBanner: String {
        let tags = ruleTags
        if tags.isEmpty { return "LEVEL \(label)" }
        return "LEVEL \(label) — \(tags.joined(separator: " / "))"
    }
}

enum ControlCopy {
    static let lineOne = "Arrows move · WASD shoot · Space sprint"
    static let lineTwo = "P pause · R restart · M sound · N music · C CRT"
}

enum GamePalette {
    static let background = "#020a05"
    static let floor = "#061a0c"
    static let floorAlt = "#081f0e"
    static let wall = "#0f3a1c"
    static let wallEdge = "#3dff7a"
    static let player = "#5cff8a"
    static let snipe = "#ffaa00"
    static let hive = "#ff2244"
    static let playerBolt = "#88ffcc"
    static let enemyBolt = "#ff4466"
    static let hud = "#5cff8a"
    static let fog = "#000000"
}