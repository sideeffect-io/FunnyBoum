import Foundation

enum GamePhase: Equatable, Sendable {
    case idle
    case running
    case won
    case lost
}

enum SpecialEffect: CaseIterable, Sendable {
    case bonus
    case malus
    case xray
    case superhero
    case funnyBoom
}

enum ActivePower: Equatable, Sendable {
    case xray(secondsRemaining: Int)
    case superhero(secondsRemaining: Int)

    var label: String {
        switch self {
        case .xray:
            String(localized: "power.xray", defaultValue: "X-Ray")
        case .superhero:
            String(localized: "power.superhero", defaultValue: "Superhero")
        }
    }

    var secondsRemaining: Int {
        switch self {
        case let .xray(seconds), let .superhero(seconds):
            seconds
        }
    }
}

enum SpecialModeStyle: Sendable {
    case xray
    case superhero
    case funnyBoom
}

struct SpecialModeNotice: Identifiable, Equatable, Sendable {
    let id: UUID
    let style: SpecialModeStyle
    let title: String
    let subtitle: String
    let symbol: String
    let totalSeconds: Int
    var secondsRemaining: Int

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(secondsRemaining) / Double(totalSeconds)
    }

    var isActivationCountdown: Bool {
        switch style {
        case .xray, .superhero, .funnyBoom:
            return true
        }
    }
}

struct TileScorePulse: Identifiable, Equatable, Sendable {
    let id: UUID
    let coordinate: BoardCoordinate
    let pointsDelta: Int
    var secondsRemaining: Int

    var label: String {
        if pointsDelta > 0 {
            return "+\(pointsDelta)"
        }
        return "\(pointsDelta)"
    }
}

enum FunnyBoomPhase: Equatable, Sendable {
    case briefing(secondsRemaining: Int)
    case active(secondsRemaining: Int)

    var secondsRemaining: Int {
        switch self {
        case let .briefing(seconds), let .active(seconds):
            return seconds
        }
    }

    var isInteractive: Bool {
        if case .active = self {
            return true
        }
        return false
    }
}

struct FunnyBoomOverlay: Equatable, Sendable {
    let clownTiles: Set<BoardCoordinate>
    var revealedClowns: Set<BoardCoordinate>
    var revealedMisses: Set<BoardCoordinate>
    var phase: FunnyBoomPhase

    var secondsRemaining: Int {
        phase.secondsRemaining
    }

    var isInteractive: Bool {
        phase.isInteractive
    }

    var isBriefing: Bool {
        if case .briefing = phase {
            return true
        }
        return false
    }
}

struct PendingVictory: Identifiable, Equatable, Sendable {
    let id: UUID
    let points: Int
    let elapsedSeconds: Int
    let totalScore: Int
}

struct ScoreEntry: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let nickname: String
    let points: Int
    let elapsedSeconds: Int
    let totalScore: Int
    let boardSize: BoardSizePreset
    let difficulty: GameDifficulty
    let playedAt: Date

    static func topTen(from scores: [ScoreEntry]) -> [ScoreEntry] {
        Array(
            scores.sorted {
                if $0.totalScore != $1.totalScore {
                    return $0.totalScore > $1.totalScore
                }
                if $0.elapsedSeconds != $1.elapsedSeconds {
                    return $0.elapsedSeconds < $1.elapsedSeconds
                }
                return $0.playedAt > $1.playedAt
            }
            .prefix(10)
        )
    }
}

struct GameState: Equatable, Sendable {
    var settings: GameSettings
    var board: GameBoard?
    var phase: GamePhase
    var elapsedSeconds: Int
    var points: Int
    var bonusPoints: Int
    var revealedTiles: Set<BoardCoordinate>
    var flaggedTiles: Set<BoardCoordinate>
    var neutralizedBombs: Set<BoardCoordinate>
    var specialRollTiles: Set<BoardCoordinate>
    var activePower: ActivePower?
    var funnyBoomOverlay: FunnyBoomOverlay?
    var specialModeNotice: SpecialModeNotice?
    var tileScorePulses: [BoardCoordinate: TileScorePulse]
    var pendingVictory: PendingVictory?
    var scores: [ScoreEntry]
    var explosionSequence: Int

    init(
        settings: GameSettings = .default,
        board: GameBoard? = nil,
        phase: GamePhase = .idle,
        elapsedSeconds: Int = 0,
        points: Int = 0,
        bonusPoints: Int = 0,
        revealedTiles: Set<BoardCoordinate> = [],
        flaggedTiles: Set<BoardCoordinate> = [],
        neutralizedBombs: Set<BoardCoordinate> = [],
        specialRollTiles: Set<BoardCoordinate> = [],
        activePower: ActivePower? = nil,
        funnyBoomOverlay: FunnyBoomOverlay? = nil,
        specialModeNotice: SpecialModeNotice? = nil,
        tileScorePulses: [BoardCoordinate: TileScorePulse] = [:],
        pendingVictory: PendingVictory? = nil,
        scores: [ScoreEntry] = [],
        explosionSequence: Int = 0
    ) {
        self.settings = settings
        self.board = board
        self.phase = phase
        self.elapsedSeconds = elapsedSeconds
        self.points = points
        self.bonusPoints = bonusPoints
        self.revealedTiles = revealedTiles
        self.flaggedTiles = flaggedTiles
        self.neutralizedBombs = neutralizedBombs
        self.specialRollTiles = specialRollTiles
        self.activePower = activePower
        self.funnyBoomOverlay = funnyBoomOverlay
        self.specialModeNotice = specialModeNotice
        self.tileScorePulses = tileScorePulses
        self.pendingVictory = pendingVictory
        self.scores = scores
        self.explosionSequence = explosionSequence
    }

    var dimensions: BoardDimensions {
        board?.dimensions ?? settings.boardSize.dimensions
    }

    var mineCount: Int {
        board?.mineCount ?? settings.mineCount
    }

    var remainingBombs: Int {
        max(0, mineCount - flaggedTiles.count - neutralizedBombs.count)
    }

    var isXrayActive: Bool {
        if case .xray = activePower {
            return true
        }
        return false
    }

    var isSuperheroActive: Bool {
        if case .superhero = activePower {
            return true
        }
        return false
    }

    var isSpecialModePreparationActive: Bool {
        specialModeNotice?.isActivationCountdown == true
    }

    var canInteractWithBoard: Bool {
        (phase == .idle || phase == .running) && !isSpecialModePreparationActive
    }

    var cellsToWin: Int {
        dimensions.cellCount - mineCount
    }

    var revealedSafeCells: Int {
        guard let board else { return 0 }
        return revealedTiles.filter { !board.isMine($0) }.count
    }
}

enum GameAction: Sendable {
    case startNewRound
    case setDifficulty(GameDifficulty)
    case setBoardSize(BoardSizePreset)
    case forceSpecialMode(SpecialModeStyle)
    case tapCell(BoardCoordinate)
    case toggleFlag(BoardCoordinate)
    case tapFunnyBoomCell(BoardCoordinate)
    case skipSpecialModeCountdown
    case timerTick
    case dismissVictoryPrompt
    case scoresLoaded([ScoreEntry])
}

struct GameDependencies: Sendable {
    var randomInt: @Sendable (Int) -> Int
    var randomUnit: @Sendable () -> Double
    var now: @Sendable () -> Date

    static let live = GameDependencies(
        randomInt: { upperBound in
            guard upperBound > 1 else { return 0 }
            return Int.random(in: 0..<upperBound)
        },
        randomUnit: {
            Double.random(in: 0...1)
        },
        now: {
            Date()
        }
    )
}

enum GameSoundEffect: Equatable, Sendable {
    case explosion
    case specialSquareDiscovered
    case victory
    case countdownBeep
    case flagPlaced
}

struct BoardStartedAnalytics: Equatable, Sendable {
    let difficulty: GameDifficulty
    let boardSize: BoardDimensions

    var boardSizeLabel: String {
        "\(boardSize.columns)x\(boardSize.rows)"
    }
}

enum GameDomainEvent: Equatable, Sendable {
    case playSound(GameSoundEffect)
    case scheduleLossCardReveal
    case trackBoardStarted(BoardStartedAnalytics)
}

struct GameTransition: Sendable {
    var state: GameState
    var events: [GameDomainEvent]

    init(state: GameState, events: [GameDomainEvent] = []) {
        self.state = state
        self.events = events
    }
}
