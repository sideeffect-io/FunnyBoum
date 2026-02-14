import Foundation

actor ScorePersistence {
    private let userDefaults: UserDefaults
    private let key = "funnyboom.top-scores.v1"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadScores() -> [ScoreEntry] {
        guard let data = userDefaults.data(forKey: key) else {
            return []
        }

        do {
            let decoded = try JSONDecoder().decode([ScoreEntry].self, from: data)
            return ScoreEntry.topTen(from: decoded)
        } catch {
            return []
        }
    }

    func save(score: ScoreEntry) -> [ScoreEntry] {
        var allScores = loadScores()
        allScores.append(score)
        let topScores = ScoreEntry.topTen(from: allScores)

        do {
            let encoded = try JSONEncoder().encode(topScores)
            userDefaults.set(encoded, forKey: key)
        } catch {
            return topScores
        }

        return topScores
    }
}

extension ScoresClient {
    static let live: ScoresClient = {
        let persistence = ScorePersistence()
        return ScoresClient(
            loadTopScores: {
                await persistence.loadScores()
            },
            saveScore: { score in
                await persistence.save(score: score)
            }
        )
    }()
}
