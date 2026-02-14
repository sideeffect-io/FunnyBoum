import Foundation

struct ScoresClient: Sendable {
    var loadTopScores: @Sendable () async -> [ScoreEntry]
    var saveScore: @Sendable (ScoreEntry) async -> [ScoreEntry]
}
