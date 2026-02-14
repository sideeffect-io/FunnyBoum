import Foundation

enum ScoreRules {
    static let revealPoints = 1
    static let eventPoints = 10
    static let specialModePreparationDuration = 5
    static let xrayActiveDuration = 8
    static let superheroActiveDuration = 8
    static let funnyBoomPlayDuration = 8
    static let tileScorePulseDuration = 2
    static let specialTriggerProbability = 0.36
    static let clownDensity = 0.18

    static func finalScore(points: Int, elapsedSeconds: Int, dimensions: BoardDimensions) -> Int {
        let boardBonus = dimensions.cellCount * 3
        let timeBonus = max(0, boardBonus - (elapsedSeconds * 5))
        return max(0, points * 100 + timeBonus)
    }
}
