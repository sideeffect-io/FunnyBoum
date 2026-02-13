import Foundation
import Testing
@testable import FunnyBoom

struct FunnyBoomTests {

    @Test func firstTapIsAlwaysSafeAndStartsGame() {
        let environment = GameEnvironment(
            randomInt: { _ in 0 },
            randomUnit: { 1 },
            now: { Date(timeIntervalSince1970: 0) }
        )

        let initialState = GameState(settings: .default)
        let firstTap = BoardCoordinate(row: 0, column: 0)

        let nextState = GameReducer.reduce(
            state: initialState,
            action: .tapCell(firstTap),
            environment: environment
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

        let environment = GameEnvironment(
            randomInt: { _ in 0 },
            randomUnit: { 1 },
            now: { Date(timeIntervalSince1970: 0) }
        )

        let initialState = GameState(
            settings: .default,
            board: board,
            phase: .running,
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
            pendingVictory: nil,
            scores: [],
            soundEnabled: true,
            explosionSequence: 0
        )

        let nextState = GameReducer.reduce(
            state: initialState,
            action: .tapCell(BoardCoordinate(row: 0, column: 0)),
            environment: environment
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

        let environment = GameEnvironment(
            randomInt: { _ in 0 },
            randomUnit: { 1 },
            now: { Date(timeIntervalSince1970: 0) }
        )

        let initialState = GameState(
            settings: .default,
            board: board,
            phase: .running,
            playerMode: .reveal,
            elapsedSeconds: 3,
            points: 20,
            bonusPoints: 0,
            revealedTiles: [],
            flaggedTiles: [],
            neutralizedBombs: [],
            specialRollTiles: [],
            activePower: .superhero(secondsRemaining: 6),
            funnyBoomOverlay: nil,
            pendingVictory: nil,
            scores: [],
            soundEnabled: true,
            explosionSequence: 0
        )

        let nextState = GameReducer.reduce(
            state: initialState,
            action: .tapCell(mine),
            environment: environment
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

        let environment = GameEnvironment(
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
            pendingVictory: nil,
            scores: [],
            soundEnabled: true,
            explosionSequence: 0
        )

        let withOverlay = GameReducer.reduce(
            state: initialState,
            action: .tapCell(BoardCoordinate(row: 0, column: 0)),
            environment: environment
        )

        #expect(withOverlay.funnyBoomOverlay != nil)

        guard let clownTile = withOverlay.funnyBoomOverlay?.clownTiles.first else {
            Issue.record("Funny boom overlay did not generate any clown tile")
            return
        }

        let pointsBefore = withOverlay.points

        let blockedDuringBriefing = GameReducer.reduce(
            state: withOverlay,
            action: .tapFunnyBoomCell(clownTile),
            environment: environment
        )

        #expect(blockedDuringBriefing.points == pointsBefore)

        var activeOverlayState = withOverlay
        for _ in 0..<ScoreRules.funnyBoomBriefingDuration {
            activeOverlayState = GameReducer.reduce(
                state: activeOverlayState,
                action: .timerTick,
                environment: environment
            )
        }

        #expect(activeOverlayState.funnyBoomOverlay?.isInteractive == true)

        let afterClownTap = GameReducer.reduce(
            state: activeOverlayState,
            action: .tapFunnyBoomCell(clownTile),
            environment: environment
        )

        #expect(afterClownTap.points == pointsBefore + ScoreRules.eventPoints)

        let nonClownTile = dimensions.allCoordinates.first { !(afterClownTap.funnyBoomOverlay?.clownTiles.contains($0) ?? false) }
        #expect(nonClownTile != nil)

        guard let nonClownTile else { return }

        let afterNonClownTap = GameReducer.reduce(
            state: afterClownTap,
            action: .tapFunnyBoomCell(nonClownTile),
            environment: environment
        )

        #expect(afterNonClownTap.points == afterClownTap.points)
    }

    @Test func timerTickAdvancesTimeAndExpiresPowers() {
        let initialState = GameState(
            settings: .default,
            board: nil,
            phase: .running,
            playerMode: .reveal,
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
                phase: .active(secondsRemaining: 1)
            ),
            pendingVictory: nil,
            scores: [],
            soundEnabled: true,
            explosionSequence: 0
        )

        let environment = GameEnvironment(
            randomInt: { _ in 0 },
            randomUnit: { 1 },
            now: { Date(timeIntervalSince1970: 0) }
        )

        let nextState = GameReducer.reduce(
            state: initialState,
            action: .timerTick,
            environment: environment
        )

        #expect(nextState.elapsedSeconds == 42)
        #expect(nextState.activePower == nil)
        #expect(nextState.funnyBoomOverlay == nil)
    }

    @Test func specialPowerTriggersNoticeWithCountdown() {
        let dimensions = BoardDimensions(rows: 5, columns: 5)
        let mines = Set((0..<5).map { BoardCoordinate(row: 2, column: $0) })
        let board = makeBoard(dimensions: dimensions, mines: mines)

        let environment = GameEnvironment(
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
            pendingVictory: nil,
            scores: [],
            soundEnabled: true,
            explosionSequence: 0
        )

        let withPower = GameReducer.reduce(
            state: initialState,
            action: .tapCell(BoardCoordinate(row: 0, column: 0)),
            environment: environment
        )

        #expect(withPower.activePower == .xray(secondsRemaining: ScoreRules.xrayDuration))
        #expect(withPower.specialModeNotice?.style == .xray)
        #expect(withPower.specialModeNotice?.secondsRemaining == ScoreRules.xrayDuration)

        let ticked = GameReducer.reduce(
            state: withPower,
            action: .timerTick,
            environment: environment
        )

        #expect(ticked.specialModeNotice?.secondsRemaining == ScoreRules.xrayDuration - 1)
    }

    @Test func bonusEffectShowsTilePulseAndPulseExpires() {
        let dimensions = BoardDimensions(rows: 5, columns: 5)
        let mines = Set((0..<5).map { BoardCoordinate(row: 2, column: $0) })
        let board = makeBoard(dimensions: dimensions, mines: mines)

        let environment = GameEnvironment(
            randomInt: { _ in 0 }, // bonus
            randomUnit: { 0 }, // trigger special
            now: { Date(timeIntervalSince1970: 0) }
        )

        let initialState = GameState(
            settings: .default,
            board: board,
            phase: .running,
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
            pendingVictory: nil,
            scores: [],
            soundEnabled: true,
            explosionSequence: 0
        )

        let tappedCoordinate = BoardCoordinate(row: 0, column: 0)

        let withPulse = GameReducer.reduce(
            state: initialState,
            action: .tapCell(tappedCoordinate),
            environment: environment
        )

        #expect(withPulse.tileScorePulses.count == 1)
        #expect(withPulse.tileScorePulses.first?.coordinate == tappedCoordinate)
        #expect(withPulse.tileScorePulses.first?.pointsDelta == ScoreRules.eventPoints)
        #expect(withPulse.specialModeNotice == nil)

        let afterOneTick = GameReducer.reduce(
            state: withPulse,
            action: .timerTick,
            environment: environment
        )
        #expect(afterOneTick.tileScorePulses.count == 1)

        let afterTwoTicks = GameReducer.reduce(
            state: afterOneTick,
            action: .timerTick,
            environment: environment
        )
        #expect(afterTwoTicks.tileScorePulses.isEmpty)
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
