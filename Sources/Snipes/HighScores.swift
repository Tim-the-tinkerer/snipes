import Foundation

struct ScoreEntry: Codable, Equatable {
    var score: Int
    var level: String
    var date: Date
}

enum HighScores {
    private static let key = "snipes.highScores"
    private static let limit = 10

    static func entries() -> [ScoreEntry] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([ScoreEntry].self, from: data)) ?? []
    }

    static var bestEntry: ScoreEntry? { entries().first }

    /// Keeps the top ten. Returns true when this run beats the previous best.
    @discardableResult
    static func record(score: Int, level: String) -> Bool {
        guard score > 0 else { return false }
        var list = entries()
        let previousBest = list.first?.score ?? 0
        list.append(ScoreEntry(score: score, level: level, date: Date()))
        list.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.date > rhs.date
        }
        if list.count > limit { list.removeLast(list.count - limit) }
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: key)
        }
        return score > previousBest
    }
}
