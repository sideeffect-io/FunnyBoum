import Foundation
import Testing
@testable import FunnyBoom

struct FunnyBoomTests {

    @Test func firstTapIsAlwaysSafeAndStartsGame() {
        let environment = GameDependencies(
            randomInt: { _ in 0 },
            randomUnit: { 1 },
            now: { Date(timeIntervalSince1970: 0) }
        )

        let initialState = GameState(settings: .default)
        let firstTap = BoardCoordinate(row: 0, column: 0)

        let nextState = reduce(
            state: initialState,
            action: .tapCell(firstTap),
            dependencies: environment
        )

        #expect(nextState.phase == .running)
        #expect(nextState.board != nil)
        #expect(nextState.board?.isMine(firstTap) == false)
        #expect(nextState.revealedTiles.contains(firstTap))
    }

    @Test func zeroTileRevealExpandsRecursively() {
        let board = makeBoard(
            dimensions: BoardDimensions(rows: 3, columns: 3),
            mines: [BoardCoordinate(row: 2, column: 2)]
        )

        let environment = GameDependencies(
            randomInt: { _ in 0 },
            randomUnit: { 1 },
            now: { Date(timeIntervalSince1970: 0) }
        )

        let initialState = GameState(
            settings: .default,
            board: board,
            phase: .running,
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
            pendingVictory: nil,
            scores: [],
            explosionSequence: 0
        )

        let nextState = reduce(
            state: initialState,
            action: .tapCell(BoardCoordinate(row: 0, column: 0)),
            dependencies: environment
        )

        #expect(nextState.revealedSafeCells == 8)
        #expect(nextState.phase == .won)
    }

    @Test func superheroModePreventsDefeatOnBombTap() {
        let mine = BoardCoordinate(row: 0, column: 0)
        let board = makeBoard(
            dimensions: BoardDimensions(rows: 2, columns: 2),
            mines: [mine]
        )

        let environment = GameDependencies(
            randomInt: { _ in 0 },
            randomUnit: { 1 },
            now: { Date(timeIntervalSince1970: 0) }
        )

        let initialState = GameState(
            settings: .default,
            board: board,
            phase: .running,
            elapsedSeconds: 3,
            points: 20,
            bonusPoints: 0,
            revealedTiles: [],
            flaggedTiles: [],
            neutralizedBombs: [],
            specialRollTiles: [],
            activePower: .superhero(secondsRemaining: 6),
            funnyBoomOverlay: nil,
            specialModeNotice: nil,
            pendingVictory: nil,
            scores: [],
            explosionSequence: 0
        )

        let nextState = reduce(
            state: initialState,
            action: .tapCell(mine),
            dependencies: environment
        )

        #expect(nextState.phase == .running)
        #expect(nextState.revealedTiles.contains(mine))
        #expect(nextState.neutralizedBombs.contains(mine))
        #expect(nextState.explosionSequence == 0)
    }

    @Test func funnyBoomAwardsPointsOnlyOnClownTiles() {
        let dimensions = BoardDimensions(rows: 5, columns: 5)
        let mines = Set((0..<5).map { BoardCoordinate(row: 2, column: $0) })
        let board = makeBoard(dimensions: dimensions, mines: mines)

        let environment = GameDependencies(
            randomInt: { upperBound in
                let value = 4
                return upperBound > 0 ? min(value, upperBound - 1) : 0
            },
            randomUnit: { 0 },
            now: { Date(timeIntervalSince1970: 0) }
        )

        let initialState = GameState(
            settings: .default,
            board: board,
            phase: .running,
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
            pendingVictory: nil,
            scores: [],
            explosionSequence: 0
        )

        let withNotice = reduce(
            state: initialState,
            action: .tapCell(BoardCoordinate(row: 0, column: 0)),
            dependencies: environment
        )

        #expect(withNotice.specialModeNotice?.style == .funnyBoom)
        #expect(withNotice.funnyBoomOverlay == nil)

        let pointsBefore = withNotice.points

        let blockedDuringPreparation = reduce(
            state: withNotice,
            action: .tapFunnyBoomCell(BoardCoordinate(row: 0, column: 0)),
            dependencies: environment
        )

        #expect(blockedDuringPreparation.points == pointsBefore)

        var activeOverlayState = withNotice
        for _ in 0..<ScoreRules.specialModePreparationDuration {
            activeOverlayState = reduce(
                state: activeOverlayState,
                action: .timerTick,
                dependencies: environment
            )
        }

        #expect(activeOverlayState.specialModeNotice == nil)
        #expect(activeOverlayState.funnyBoomOverlay?.isInteractive == true)

        guard let clownTile = activeOverlayState.funnyBoomOverlay?.clownTiles.first else {
            Issue.record("Funny boom overlay did not generate any clown tile")
            return
        }

        let afterClownTap = reduce(
            state: activeOverlayState,
            action: .tapFunnyBoomCell(clownTile),
            dependencies: environment
        )

        #expect(afterClownTap.points == pointsBefore + ScoreRules.eventPoints)
        #expect(afterClownTap.tileScorePulses.count == 1)
        #expect(afterClownTap.tileScorePulses.first?.coordinate == clownTile)
        #expect(afterClownTap.tileScorePulses.first?.pointsDelta == ScoreRules.eventPoints)

        let nonClownTile = dimensions.allCoordinates.first { !(afterClownTap.funnyBoomOverlay?.clownTiles.contains($0) ?? false) }
        #expect(nonClownTile != nil)

        guard let nonClownTile else { return }

        let afterNonClownTap = reduce(
            state: afterClownTap,
            action: .tapFunnyBoomCell(nonClownTile),
            dependencies: environment
        )

        #expect(afterNonClownTap.points == afterClownTap.points)
        #expect(afterNonClownTap.funnyBoomOverlay?.revealedMisses.contains(nonClownTile) == true)
    }

    @Test func timerTickAdvancesTimeAndExpiresPowers() {
        let initialState = GameState(
            settings: .default,
            board: nil,
            phase: .running,
            elapsedSeconds: 41,
            points: 10,
            bonusPoints: 0,
            revealedTiles: [],
            flaggedTiles: [],
            neutralizedBombs: [],
            specialRollTiles: [],
            activePower: .xray(secondsRemaining: 1),
            funnyBoomOverlay: FunnyBoomOverlay(
                clownTiles: [],
                revealedClowns: [],
                revealedMisses: [],
                phase: .active(secondsRemaining: 1)
            ),
            specialModeNotice: nil,
            pendingVictory: nil,
            scores: [],
            explosionSequence: 0
        )

        let environment = GameDependencies(
            randomInt: { _ in 0 },
            randomUnit: { 1 },
            now: { Date(timeIntervalSince1970: 0) }
        )

        let nextState = reduce(
            state: initialState,
            action: .timerTick,
            dependencies: environment
        )

        #expect(nextState.elapsedSeconds == 42)
        #expect(nextState.activePower == nil)
        #expect(nextState.funnyBoomOverlay == nil)
    }

    @Test func specialPowerRequiresPreparationThenActivatesForEightSeconds() {
        let dimensions = BoardDimensions(rows: 5, columns: 5)
        let mines = Set((0..<5).map { BoardCoordinate(row: 2, column: $0) })
        let board = makeBoard(dimensions: dimensions, mines: mines)

        let environment = GameDependencies(
            randomInt: { upperBound in
                // xray index in SpecialEffect.allCases
                let desired = 2
                return upperBound > 0 ? min(desired, upperBound - 1) : 0
            },
            randomUnit: { 0 },
            now: { Date(timeIntervalSince1970: 0) }
        )

        let initialState = GameState(
            settings: .default,
            board: board,
            phase: .running,
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
            pendingVictory: nil,
            scores: [],
            explosionSequence: 0
        )

        let withPower = reduce(
            state: initialState,
            action: .tapCell(BoardCoordinate(row: 0, column: 0)),
            dependencies: environment
        )

        #expect(withPower.activePower == nil)
        #expect(withPower.specialModeNotice?.style == .xray)
        #expect(withPower.specialModeNotice?.secondsRemaining == ScoreRules.specialModePreparationDuration)

        let ticked = reduce(
            state: withPower,
            action: .timerTick,
            dependencies: environment
        )

        #expect(ticked.specialModeNotice?.secondsRemaining == ScoreRules.specialModePreparationDuration - 1)
        #expect(ticked.activePower == nil)

        var afterPreparation = withPower
        for _ in 0..<ScoreRules.specialModePreparationDuration {
            afterPreparation = reduce(
                state: afterPreparation,
                action: .timerTick,
                dependencies: environment
            )
        }

        #expect(afterPreparation.specialModeNotice == nil)
        #expect(afterPreparation.activePower == .xray(secondsRemaining: ScoreRules.xrayActiveDuration))
    }

    @Test func superheroPowerRequiresPreparationThenActivatesForEightSeconds() {
        let dimensions = BoardDimensions(rows: 5, columns: 5)
        let mines = Set((0..<5).map { BoardCoordinate(row: 2, column: $0) })
        let board = makeBoard(dimensions: dimensions, mines: mines)

        let environment = GameDependencies(
            randomInt: { upperBound in
                // superhero index in SpecialEffect.allCases
                let desired = 3
                return upperBound > 0 ? min(desired, upperBound - 1) : 0
            },
            randomUnit: { 0 },
            now: { Date(timeIntervalSince1970: 0) }
        )

        let initialState = GameState(
            settings: .default,
            board: board,
            phase: .running,
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
            pendingVictory: nil,
            scores: [],
            explosionSequence: 0
        )

        let withPower = reduce(
            state: initialState,
            action: .tapCell(BoardCoordinate(row: 0, column: 0)),
            dependencies: environment
        )

        #expect(withPower.activePower == nil)
        #expect(withPower.specialModeNotice?.style == .superhero)

        var afterPreparation = withPower
        for _ in 0..<ScoreRules.specialModePreparationDuration {
            afterPreparation = reduce(
                state: afterPreparation,
                action: .timerTick,
                dependencies: environment
            )
        }

        #expect(afterPreparation.specialModeNotice == nil)
        #expect(afterPreparation.activePower == .superhero(secondsRemaining: ScoreRules.superheroActiveDuration))
    }

    @Test func skipSpecialModeCountdownActivatesXrayImmediately() {
        let state = GameState(
            settings: .default,
            phase: .running,
            specialModeNotice: SpecialModeNotice(
                id: UUID(),
                style: .xray,
                title: "X-RAY CHARGING",
                subtitle: "Scan starts soon",
                symbol: "eye.fill",
                totalSeconds: ScoreRules.specialModePreparationDuration,
                secondsRemaining: ScoreRules.specialModePreparationDuration
            )
        )

        let nextState = reduce(
            state: state,
            action: .skipSpecialModeCountdown,
            dependencies: .live
        )

        #expect(nextState.specialModeNotice == nil)
        #expect(nextState.activePower == .xray(secondsRemaining: ScoreRules.xrayActiveDuration))
    }

    @Test func skipSpecialModeCountdownActivatesFunnyBoomImmediately() {
        let board = makeBoard(
            dimensions: BoardDimensions(rows: 4, columns: 4),
            mines: [BoardCoordinate(row: 3, column: 3)]
        )

        let state = GameState(
            settings: .default,
            board: board,
            phase: .running,
            specialModeNotice: SpecialModeNotice(
                id: UUID(),
                style: .funnyBoom,
                title: "CLOWN HUNT LOADING",
                subtitle: "Tap clown faces for points.",
                symbol: "theatermasks.fill",
                totalSeconds: ScoreRules.specialModePreparationDuration,
                secondsRemaining: ScoreRules.specialModePreparationDuration
            )
        )

        let nextState = reduce(
            state: state,
            action: .skipSpecialModeCountdown,
            dependencies: .live
        )

        #expect(nextState.specialModeNotice == nil)
        #expect(nextState.funnyBoomOverlay?.isInteractive == true)
        #expect(nextState.funnyBoomOverlay?.secondsRemaining == ScoreRules.funnyBoomPlayDuration)
    }

    @Test func bonusEffectShowsTilePulseAndPulseExpires() {
        let dimensions = BoardDimensions(rows: 5, columns: 5)
        let mines = Set((0..<5).map { BoardCoordinate(row: 2, column: $0) })
        let board = makeBoard(dimensions: dimensions, mines: mines)

        let environment = GameDependencies(
            randomInt: { _ in 0 }, // bonus
            randomUnit: { 0 }, // trigger special
            now: { Date(timeIntervalSince1970: 0) }
        )

        let initialState = GameState(
            settings: .default,
            board: board,
            phase: .running,
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
            pendingVictory: nil,
            scores: [],
            explosionSequence: 0
        )

        let tappedCoordinate = BoardCoordinate(row: 0, column: 0)

        let withPulse = reduce(
            state: initialState,
            action: .tapCell(tappedCoordinate),
            dependencies: environment
        )

        #expect(withPulse.tileScorePulses.count == 1)
        #expect(withPulse.tileScorePulses.first?.coordinate == tappedCoordinate)
        #expect(withPulse.tileScorePulses.first?.pointsDelta == ScoreRules.eventPoints)
        #expect(withPulse.specialModeNotice == nil)

        let afterOneTick = reduce(
            state: withPulse,
            action: .timerTick,
            dependencies: environment
        )
        #expect(afterOneTick.tileScorePulses.count == 1)

        let afterTwoTicks = reduce(
            state: afterOneTick,
            action: .timerTick,
            dependencies: environment
        )
        #expect(afterTwoTicks.tileScorePulses.isEmpty)
    }

    @MainActor
    @Test func funnyBoomCountdownBeepsInLastThreeSeconds() {
        var countdownBeepCount = 0

        let soundPlayer = SoundClient(
            play: { effect in
                if case .countdownBeep = effect {
                    countdownBeepCount += 1
                }
            }
        )

        let scoresClient = ScoresClient(
            loadTopScores: { [] },
            saveScore: { _ in [] }
        )

        let initialState = GameState(
            settings: .default,
            phase: .running,
            funnyBoomOverlay: FunnyBoomOverlay(
                clownTiles: [],
                revealedClowns: [],
                revealedMisses: [],
                phase: .active(secondsRemaining: 4)
            )
        )

        let store = GameStore(
            state: initialState,
            dependencies: .live,
            scoresClient: scoresClient,
            soundClient: soundPlayer
        )

        store.send(.timerTick)
        #expect(countdownBeepCount == 1)
    }

    @Test func tappingMineEmitsExplosionAndLossRevealEvents() {
        let mine = BoardCoordinate(row: 0, column: 1)
        let board = makeBoard(
            dimensions: BoardDimensions(rows: 2, columns: 2),
            mines: [mine]
        )

        let initialState = GameState(
            settings: .default,
            board: board,
            phase: .running
        )

        let transition = transition(
            state: initialState,
            action: .tapCell(mine),
            dependencies: .live
        )

        #expect(transition.state.phase == .lost)
        #expect(transition.events.contains(.playSound(.explosion)))
        #expect(transition.events.contains(.scheduleLossCardReveal))
    }

    @Test func addingFlagEmitsFlagPlacedSoundEvent() {
        let coordinate = BoardCoordinate(row: 0, column: 0)
        let initialState = GameState(settings: .default, phase: .idle)

        let transition = transition(
            state: initialState,
            action: .toggleFlag(coordinate),
            dependencies: .live
        )

        #expect(transition.state.flaggedTiles.contains(coordinate))
        #expect(transition.events.contains(.playSound(.flagPlaced)))
    }

    @Test func specialTriggerEmitsSpecialDiscoverySoundEvent() {
        let board = makeBoard(
            dimensions: BoardDimensions(rows: 5, columns: 5),
            mines: [BoardCoordinate(row: 4, column: 4)]
        )
        let initialState = GameState(
            settings: .default,
            board: board,
            phase: .running
        )
        let dependencies = GameDependencies(
            randomInt: { _ in 0 },
            randomUnit: { 0 },
            now: Date.init
        )

        let transition = transition(
            state: initialState,
            action: .tapCell(BoardCoordinate(row: 0, column: 0)),
            dependencies: dependencies
        )

        #expect(transition.events.contains(.playSound(.specialSquareDiscovered)))
    }

    private func transition(
        state: GameState,
        action: GameAction,
        dependencies: GameDependencies
    ) -> GameTransition {
        GameReducer.reduce(
            state: state,
            action: action,
            dependencies: dependencies
        )
    }

    private func reduce(
        state: GameState,
        action: GameAction,
        dependencies: GameDependencies
    ) -> GameState {
        transition(
            state: state,
            action: action,
            dependencies: dependencies
        ).state
    }

    private func makeBoard(dimensions: BoardDimensions, mines: Set<BoardCoordinate>) -> GameBoard {
        var adjacentMines: [BoardCoordinate: Int] = [:]

        for coordinate in dimensions.allCoordinates {
            let adjacentCount = neighbors(of: coordinate, dimensions: dimensions)
                .filter { mines.contains($0) }
                .count
            adjacentMines[coordinate] = adjacentCount
        }

        return GameBoard(dimensions: dimensions, mines: mines, adjacentMines: adjacentMines)
    }

    private func neighbors(of coordinate: BoardCoordinate, dimensions: BoardDimensions) -> [BoardCoordinate] {
        var result: [BoardCoordinate] = []
        for rowOffset in -1...1 {
            for columnOffset in -1...1 {
                if rowOffset == 0 && columnOffset == 0 { continue }
                let neighbor = BoardCoordinate(row: coordinate.row + rowOffset, column: coordinate.column + columnOffset)
                if dimensions.isValid(neighbor) {
                    result.append(neighbor)
                }
            }
        }
        return result
    }
}
