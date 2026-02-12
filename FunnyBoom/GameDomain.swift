import Foundation

struct BoardDimensions: Equatable, Codable, Sendable {
    let rows: Int
    let columns: Int

    init(rows: Int, columns: Int) {
        self.rows = max(2, rows)
        self.columns = max(2, columns)
    }

    var cellCount: Int {
        rows * columns
    }

    var allCoordinates: [BoardCoordinate] {
        var result: [BoardCoordinate] = []
        result.reserveCapacity(cellCount)
        for row in 0..<rows {
            for column in 0..<columns {
                result.append(BoardCoordinate(row: row, column: column))
            }
        }
        return result
    }

    func isValid(_ coordinate: BoardCoordinate) -> Bool {
        coordinate.row >= 0 && coordinate.row < rows && coordinate.column >= 0 && coordinate.column < columns
    }
}

enum GameDifficulty: String, CaseIterable, Identifiable, Codable, Sendable {
    case debutant
    case amateur
    case expert
    case veteran
    case migraine

    var id: String { rawValue }

    var title: String {
        switch self {
        case .debutant: "Debutant"
        case .amateur: "Amateur"
        case .expert: "Expert"
        case .veteran: "Veteran"
        case .migraine: "Migraine"
        }
    }

    var mineDensity: Double {
        switch self {
        case .debutant: 0.09
        case .amateur: 0.13
        case .expert: 0.16
        case .veteran: 0.19
        case .migraine: 0.22
        }
    }
}

enum BoardSizePreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case tiny15x15
    case rectangular20x15
    case classic20x20
    case large25x20
    case monster35x23
    case phone10x14
    case phone12x18
    case phone14x22

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tiny15x15: "15 x 15"
        case .rectangular20x15: "20 x 15"
        case .classic20x20: "20 x 20"
        case .large25x20: "25 x 20"
        case .monster35x23: "35 x 23"
        case .phone10x14: "10 x 14"
        case .phone12x18: "12 x 18"
        case .phone14x22: "14 x 22"
        }
    }

    var dimensions: BoardDimensions {
        switch self {
        case .tiny15x15: BoardDimensions(rows: 15, columns: 15)
        case .rectangular20x15: BoardDimensions(rows: 15, columns: 20)
        case .classic20x20: BoardDimensions(rows: 20, columns: 20)
        case .large25x20: BoardDimensions(rows: 20, columns: 25)
        case .monster35x23: BoardDimensions(rows: 23, columns: 35)
        case .phone10x14: BoardDimensions(rows: 14, columns: 10)
        case .phone12x18: BoardDimensions(rows: 18, columns: 12)
        case .phone14x22: BoardDimensions(rows: 22, columns: 14)
        }
    }

    static let regularPresets: [BoardSizePreset] = [
        .tiny15x15,
        .rectangular20x15,
        .classic20x20,
        .large25x20,
        .monster35x23
    ]

    static let phonePortraitPresets: [BoardSizePreset] = [
        .phone10x14,
        .phone12x18,
        .phone14x22
    ]
}

struct GameSettings: Equatable, Codable, Sendable {
    var difficulty: GameDifficulty
    var boardSize: BoardSizePreset

    static let `default` = GameSettings(difficulty: .amateur, boardSize: .classic20x20)

    var mineCount: Int {
        let boardCells = boardSize.dimensions.cellCount
        let desired = Int((Double(boardCells) * difficulty.mineDensity).rounded())
        return min(max(1, desired), max(1, boardCells - 1))
    }
}

struct BoardCoordinate: Hashable, Codable, Sendable {
    let row: Int
    let column: Int
}

struct GameBoard: Equatable, Sendable {
    let dimensions: BoardDimensions
    let mines: Set<BoardCoordinate>
    let adjacentMines: [BoardCoordinate: Int]

    var mineCount: Int {
        mines.count
    }

    func isMine(_ coordinate: BoardCoordinate) -> Bool {
        mines.contains(coordinate)
    }

    func adjacentMineCount(at coordinate: BoardCoordinate) -> Int {
        adjacentMines[coordinate, default: 0]
    }

    func neighbors(of coordinate: BoardCoordinate) -> [BoardCoordinate] {
        var result: [BoardCoordinate] = []
        for rowOffset in -1...1 {
            for columnOffset in -1...1 {
                if rowOffset == 0 && columnOffset == 0 {
                    continue
                }
                let neighbor = BoardCoordinate(
                    row: coordinate.row + rowOffset,
                    column: coordinate.column + columnOffset
                )
                if dimensions.isValid(neighbor) {
                    result.append(neighbor)
                }
            }
        }
        return result
    }

    static func generate(
        settings: GameSettings,
        safeCoordinate: BoardCoordinate,
        randomInt: (Int) -> Int
    ) -> GameBoard {
        let dimensions = settings.boardSize.dimensions
        let allCoordinates = dimensions.allCoordinates

        let forbidden = Set([safeCoordinate] + neighbors(for: safeCoordinate, in: dimensions))
        var candidateCoordinates = allCoordinates.filter { !forbidden.contains($0) }

        if settings.mineCount >= candidateCoordinates.count {
            candidateCoordinates = allCoordinates.filter { $0 != safeCoordinate }
        }

        let targetMineCount = min(settings.mineCount, candidateCoordinates.count)
        var mines: Set<BoardCoordinate> = []

        while mines.count < targetMineCount && !candidateCoordinates.isEmpty {
            let randomIndex = boundedRandomInt(randomInt, upperBound: candidateCoordinates.count)
            mines.insert(candidateCoordinates.remove(at: randomIndex))
        }

        var adjacency: [BoardCoordinate: Int] = [:]
        adjacency.reserveCapacity(allCoordinates.count)

        for coordinate in allCoordinates {
            let count = neighbors(for: coordinate, in: dimensions)
                .filter { mines.contains($0) }
                .count
            adjacency[coordinate] = count
        }

        return GameBoard(dimensions: dimensions, mines: mines, adjacentMines: adjacency)
    }

    private static func neighbors(for coordinate: BoardCoordinate, in dimensions: BoardDimensions) -> [BoardCoordinate] {
        var result: [BoardCoordinate] = []
        for rowOffset in -1...1 {
            for columnOffset in -1...1 {
                if rowOffset == 0 && columnOffset == 0 {
                    continue
                }
                let neighbor = BoardCoordinate(
                    row: coordinate.row + rowOffset,
                    column: coordinate.column + columnOffset
                )
                if dimensions.isValid(neighbor) {
                    result.append(neighbor)
                }
            }
        }
        return result
    }

    private static func boundedRandomInt(_ randomInt: (Int) -> Int, upperBound: Int) -> Int {
        guard upperBound > 1 else {
            return 0
        }
        return min(max(0, randomInt(upperBound)), upperBound - 1)
    }
}

enum GamePhase: Equatable, Sendable {
    case idle
    case running
    case won
    case lost
}

enum PlayerMode: Equatable, Sendable {
    case reveal
    case flag
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
        case .xray: "X-Ray"
        case .superhero: "Superhero"
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

struct FunnyBoomOverlay: Equatable, Sendable {
    let clownTiles: Set<BoardCoordinate>
    var revealedClowns: Set<BoardCoordinate>
    var secondsRemaining: Int
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
    var playerMode: PlayerMode
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
    var tileScorePulses: [TileScorePulse]
    var pendingVictory: PendingVictory?
    var scores: [ScoreEntry]
    var soundEnabled: Bool
    var explosionSequence: Int

    init(
        settings: GameSettings = .default,
        board: GameBoard? = nil,
        phase: GamePhase = .idle,
        playerMode: PlayerMode = .reveal,
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
        tileScorePulses: [TileScorePulse] = [],
        pendingVictory: PendingVictory? = nil,
        scores: [ScoreEntry] = [],
        soundEnabled: Bool = true,
        explosionSequence: Int = 0
    ) {
        self.settings = settings
        self.board = board
        self.phase = phase
        self.playerMode = playerMode
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
        self.soundEnabled = soundEnabled
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

    var canInteractWithBoard: Bool {
        phase == .idle || phase == .running
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
    case setPlayerMode(PlayerMode)
    case toggleSound
    case tapCell(BoardCoordinate)
    case toggleFlag(BoardCoordinate)
    case tapFunnyBoomCell(BoardCoordinate)
    case timerTick
    case dismissVictoryPrompt
    case scoresLoaded([ScoreEntry])
}

struct GameEnvironment: Sendable {
    var randomInt: @Sendable (Int) -> Int
    var randomUnit: @Sendable () -> Double
    var now: @Sendable () -> Date

    static let live = GameEnvironment(
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

enum ScoreRules {
    static let revealPoints = 1
    static let eventPoints = 10
    static let xrayDuration = 12
    static let superheroDuration = 12
    static let funnyBoomDuration = 5
    static let tileScorePulseDuration = 2
    static let specialTriggerProbability = 0.36
    static let clownDensity = 0.18

    static func finalScore(points: Int, elapsedSeconds: Int, dimensions: BoardDimensions) -> Int {
        let boardBonus = dimensions.cellCount * 3
        let timeBonus = max(0, boardBonus - (elapsedSeconds * 5))
        return max(0, points * 100 + timeBonus)
    }
}

enum GameReducer {
    static func reduce(state: GameState, action: GameAction, environment: GameEnvironment) -> GameState {
        var nextState = state

        switch action {
        case .startNewRound:
            nextState = resetRound(from: nextState)

        case let .setDifficulty(difficulty):
            nextState.settings.difficulty = difficulty
            nextState = resetRound(from: nextState)

        case let .setBoardSize(boardSize):
            nextState.settings.boardSize = boardSize
            nextState = resetRound(from: nextState)

        case let .setPlayerMode(mode):
            nextState.playerMode = mode

        case .toggleSound:
            nextState.soundEnabled.toggle()

        case let .tapCell(coordinate):
            nextState = tapCell(state: nextState, coordinate: coordinate, environment: environment)

        case let .toggleFlag(coordinate):
            nextState = toggleFlag(state: nextState, coordinate: coordinate)

        case let .tapFunnyBoomCell(coordinate):
            nextState = tapFunnyBoomCell(state: nextState, coordinate: coordinate)

        case .timerTick:
            nextState = tick(state: nextState)

        case .dismissVictoryPrompt:
            nextState.pendingVictory = nil

        case let .scoresLoaded(scores):
            nextState.scores = ScoreEntry.topTen(from: scores)
        }

        return nextState
    }

    private static func resetRound(from state: GameState) -> GameState {
        GameState(
            settings: state.settings,
            board: nil,
            phase: .idle,
            playerMode: .reveal,
            elapsedSeconds: 0,
            points: 0,
            bonusPoints: 0,
            revealedTiles: [],
            flaggedTiles: [],
            neutralizedBombs: [],
            specialRollTiles: [],
            activePower: nil,
            funnyBoomOverlay: nil,
            specialModeNotice: nil,
            tileScorePulses: [],
            pendingVictory: nil,
            scores: state.scores,
            soundEnabled: state.soundEnabled,
            explosionSequence: state.explosionSequence
        )
    }

    private static func tapCell(state: GameState, coordinate: BoardCoordinate, environment: GameEnvironment) -> GameState {
        guard state.canInteractWithBoard else { return state }
        guard state.funnyBoomOverlay == nil else { return state }
        guard state.dimensions.isValid(coordinate) else { return state }

        if state.playerMode == .flag {
            return toggleFlag(state: state, coordinate: coordinate)
        }

        var nextState = state

        if nextState.flaggedTiles.contains(coordinate) {
            return nextState
        }

        if nextState.board == nil {
            nextState.board = GameBoard.generate(
                settings: nextState.settings,
                safeCoordinate: coordinate,
                randomInt: environment.randomInt
            )
            nextState.phase = .running
        }

        guard let board = nextState.board else {
            return nextState
        }

        if nextState.revealedTiles.contains(coordinate) {
            return chordRevealIfPossible(state: nextState, coordinate: coordinate, board: board)
        }

        if board.isMine(coordinate) {
            if nextState.isSuperheroActive {
                nextState.revealedTiles.insert(coordinate)
                nextState.neutralizedBombs.insert(coordinate)
                nextState.flaggedTiles.remove(coordinate)
                return nextState
            }

            nextState.phase = .lost
            nextState.activePower = nil
            nextState.funnyBoomOverlay = nil
            nextState.specialModeNotice = nil
            nextState.tileScorePulses = []
            nextState.pendingVictory = nil
            nextState.revealedTiles.formUnion(board.mines)
            nextState.explosionSequence += 1
            return nextState
        }

        let revealedNow = floodReveal(from: coordinate, board: board, alreadyRevealed: nextState.revealedTiles, flagged: nextState.flaggedTiles)

        let newSafeTiles = revealedNow.subtracting(nextState.revealedTiles)
        nextState.revealedTiles.formUnion(revealedNow)
        nextState.points += newSafeTiles.count * ScoreRules.revealPoints

        maybeApplySpecialEffect(
            state: &nextState,
            board: board,
            tappedCoordinate: coordinate,
            newlyRevealed: newSafeTiles,
            environment: environment
        )

        return completeIfWon(state: nextState, board: board)
    }

    private static func tapFunnyBoomCell(state: GameState, coordinate: BoardCoordinate) -> GameState {
        guard state.phase == .running else { return state }
        guard var overlay = state.funnyBoomOverlay else { return state }

        var nextState = state

        if overlay.clownTiles.contains(coordinate), !overlay.revealedClowns.contains(coordinate) {
            overlay.revealedClowns.insert(coordinate)
            nextState.points += ScoreRules.eventPoints
            nextState.bonusPoints += ScoreRules.eventPoints
        }

        nextState.funnyBoomOverlay = overlay
        return nextState
    }

    private static func toggleFlag(state: GameState, coordinate: BoardCoordinate) -> GameState {
        guard state.canInteractWithBoard else { return state }
        guard state.funnyBoomOverlay == nil else { return state }

        var nextState = state

        guard !nextState.revealedTiles.contains(coordinate) else {
            return nextState
        }

        if nextState.flaggedTiles.contains(coordinate) {
            nextState.flaggedTiles.remove(coordinate)
        } else {
            nextState.flaggedTiles.insert(coordinate)
        }

        return nextState
    }

    private static func tick(state: GameState) -> GameState {
        guard state.phase == .running else { return state }

        var nextState = state
        nextState.elapsedSeconds += 1

        if let activePower = nextState.activePower {
            switch activePower {
            case let .xray(secondsRemaining):
                if secondsRemaining <= 1 {
                    nextState.activePower = nil
                } else {
                    nextState.activePower = .xray(secondsRemaining: secondsRemaining - 1)
                }
            case let .superhero(secondsRemaining):
                if secondsRemaining <= 1 {
                    nextState.activePower = nil
                } else {
                    nextState.activePower = .superhero(secondsRemaining: secondsRemaining - 1)
                }
            }
        }

        if var specialModeNotice = nextState.specialModeNotice {
            specialModeNotice.secondsRemaining -= 1
            if specialModeNotice.secondsRemaining <= 0 {
                nextState.specialModeNotice = nil
            } else {
                nextState.specialModeNotice = specialModeNotice
            }
        }

        nextState.tileScorePulses = nextState.tileScorePulses.compactMap { pulse in
            var nextPulse = pulse
            nextPulse.secondsRemaining -= 1
            return nextPulse.secondsRemaining > 0 ? nextPulse : nil
        }

        if var overlay = nextState.funnyBoomOverlay {
            overlay.secondsRemaining -= 1
            if overlay.secondsRemaining <= 0 {
                nextState.funnyBoomOverlay = nil
            } else {
                nextState.funnyBoomOverlay = overlay
            }
        }

        return nextState
    }

    private static func chordRevealIfPossible(state: GameState, coordinate: BoardCoordinate, board: GameBoard) -> GameState {
        guard board.adjacentMineCount(at: coordinate) > 0 else {
            return state
        }

        let neighbors = board.neighbors(of: coordinate)
        let flaggedNeighbors = neighbors.filter { state.flaggedTiles.contains($0) }.count

        guard flaggedNeighbors == board.adjacentMineCount(at: coordinate) else {
            return state
        }

        var nextState = state

        for neighbor in neighbors where !state.flaggedTiles.contains(neighbor) && !state.revealedTiles.contains(neighbor) {
            if board.isMine(neighbor) {
                if state.isSuperheroActive {
                    nextState.revealedTiles.insert(neighbor)
                    nextState.neutralizedBombs.insert(neighbor)
                } else {
                    nextState.phase = .lost
                    nextState.revealedTiles.formUnion(board.mines)
                    nextState.activePower = nil
                    nextState.funnyBoomOverlay = nil
                    nextState.specialModeNotice = nil
                    nextState.tileScorePulses = []
                    nextState.pendingVictory = nil
                    nextState.explosionSequence += 1
                    return nextState
                }
            } else {
                let revealed = floodReveal(from: neighbor, board: board, alreadyRevealed: nextState.revealedTiles, flagged: nextState.flaggedTiles)
                let newlyRevealed = revealed.subtracting(nextState.revealedTiles)
                nextState.revealedTiles.formUnion(revealed)
                nextState.points += newlyRevealed.count * ScoreRules.revealPoints
            }
        }

        return completeIfWon(state: nextState, board: board)
    }

    private static func completeIfWon(state: GameState, board: GameBoard) -> GameState {
        var nextState = state

        let safeCells = board.dimensions.cellCount - board.mineCount
        let revealedSafeCells = nextState.revealedTiles.filter { !board.isMine($0) }.count

        if revealedSafeCells >= safeCells {
            nextState.phase = .won
            nextState.activePower = nil
            nextState.funnyBoomOverlay = nil
            nextState.specialModeNotice = nil
            nextState.tileScorePulses = []

            let totalScore = ScoreRules.finalScore(
                points: nextState.points,
                elapsedSeconds: nextState.elapsedSeconds,
                dimensions: board.dimensions
            )

            nextState.pendingVictory = PendingVictory(
                id: UUID(),
                points: nextState.points,
                elapsedSeconds: nextState.elapsedSeconds,
                totalScore: totalScore
            )
        }

        return nextState
    }

    private static func maybeApplySpecialEffect(
        state: inout GameState,
        board: GameBoard,
        tappedCoordinate: BoardCoordinate,
        newlyRevealed: Set<BoardCoordinate>,
        environment: GameEnvironment
    ) {
        guard newlyRevealed.contains(tappedCoordinate) else {
            return
        }

        guard board.adjacentMineCount(at: tappedCoordinate) == 0 else {
            return
        }

        guard !state.specialRollTiles.contains(tappedCoordinate) else {
            return
        }

        state.specialRollTiles.insert(tappedCoordinate)

        guard environment.randomUnit() < ScoreRules.specialTriggerProbability else {
            return
        }

        state.activePower = nil
        state.funnyBoomOverlay = nil
        state.specialModeNotice = nil

        let effects = SpecialEffect.allCases
        let index = max(0, min(effects.count - 1, environment.randomInt(effects.count)))

        switch effects[index] {
        case .bonus:
            state.points += ScoreRules.eventPoints
            state.bonusPoints += ScoreRules.eventPoints
            enqueueTileScorePulse(state: &state, coordinate: tappedCoordinate, pointsDelta: ScoreRules.eventPoints)

        case .malus:
            state.points -= ScoreRules.eventPoints
            state.bonusPoints -= ScoreRules.eventPoints
            enqueueTileScorePulse(state: &state, coordinate: tappedCoordinate, pointsDelta: -ScoreRules.eventPoints)

        case .xray:
            state.activePower = .xray(secondsRemaining: ScoreRules.xrayDuration)
            state.specialModeNotice = makeModeNotice(
                style: .xray,
                title: "X-RAY VISION",
                subtitle: "Bombs are visible through the fog",
                symbol: "eye.fill",
                duration: ScoreRules.xrayDuration
            )

        case .superhero:
            state.activePower = .superhero(secondsRemaining: ScoreRules.superheroDuration)
            state.specialModeNotice = makeModeNotice(
                style: .superhero,
                title: "SUPERHERO MODE",
                subtitle: "You can step on bombs safely",
                symbol: "bolt.fill",
                duration: ScoreRules.superheroDuration
            )

        case .funnyBoom:
            let dimensions = board.dimensions
            var candidates = dimensions.allCoordinates
            let clownCount = min(
                max(6, Int(Double(dimensions.cellCount) * ScoreRules.clownDensity)),
                candidates.count
            )

            var clowns: Set<BoardCoordinate> = []
            while clowns.count < clownCount && !candidates.isEmpty {
                let randomIndex = max(0, min(candidates.count - 1, environment.randomInt(candidates.count)))
                clowns.insert(candidates.remove(at: randomIndex))
            }

            state.funnyBoomOverlay = FunnyBoomOverlay(
                clownTiles: clowns,
                revealedClowns: [],
                secondsRemaining: ScoreRules.funnyBoomDuration
            )
            state.specialModeNotice = makeModeNotice(
                style: .funnyBoom,
                title: "FUNNY BOOM",
                subtitle: "Tap clowns fast for bonus points",
                symbol: "face.smiling.fill",
                duration: ScoreRules.funnyBoomDuration
            )
        }
    }

    private static func makeModeNotice(
        style: SpecialModeStyle,
        title: String,
        subtitle: String,
        symbol: String,
        duration: Int
    ) -> SpecialModeNotice {
        SpecialModeNotice(
            id: UUID(),
            style: style,
            title: title,
            subtitle: subtitle,
            symbol: symbol,
            totalSeconds: duration,
            secondsRemaining: duration
        )
    }

    private static func enqueueTileScorePulse(
        state: inout GameState,
        coordinate: BoardCoordinate,
        pointsDelta: Int
    ) {
        state.tileScorePulses.removeAll { $0.coordinate == coordinate }
        state.tileScorePulses.append(
            TileScorePulse(
                id: UUID(),
                coordinate: coordinate,
                pointsDelta: pointsDelta,
                secondsRemaining: ScoreRules.tileScorePulseDuration
            )
        )
    }

    private static func floodReveal(
        from origin: BoardCoordinate,
        board: GameBoard,
        alreadyRevealed: Set<BoardCoordinate>,
        flagged: Set<BoardCoordinate>
    ) -> Set<BoardCoordinate> {
        var revealed = alreadyRevealed
        var queue: [BoardCoordinate] = [origin]

        while let coordinate = queue.popLast() {
            if revealed.contains(coordinate) || flagged.contains(coordinate) {
                continue
            }
            if board.isMine(coordinate) {
                continue
            }

            revealed.insert(coordinate)

            if board.adjacentMineCount(at: coordinate) == 0 {
                for neighbor in board.neighbors(of: coordinate) where !revealed.contains(neighbor) {
                    queue.append(neighbor)
                }
            }
        }

        return revealed
    }
}
