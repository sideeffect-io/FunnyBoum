import Foundation

enum GameReducer {
    static func reduce(
        state: GameState,
        action: GameAction,
        dependencies: GameDependencies
    ) -> GameTransition {
        var nextState = state
        var events: [GameDomainEvent] = []

        switch action {
        case .startNewRound:
            nextState = resetRound(from: nextState)

        case let .setDifficulty(difficulty):
            nextState.settings.difficulty = difficulty
            nextState = resetRound(from: nextState)

        case let .setBoardSize(boardSize):
            nextState.settings.boardSize = boardSize
            nextState = resetRound(from: nextState)

        case let .forceSpecialMode(style):
            nextState = forceSpecialMode(
                state: nextState,
                style: style,
                dependencies: dependencies
            )

        case let .tapCell(coordinate):
            let transition = tapCell(
                state: nextState,
                coordinate: coordinate,
                dependencies: dependencies
            )
            nextState = transition.state
            events.append(contentsOf: transition.events)

        case let .toggleFlag(coordinate):
            let transition = toggleFlag(state: nextState, coordinate: coordinate)
            nextState = transition.state
            events.append(contentsOf: transition.events)

        case let .tapFunnyBoomCell(coordinate):
            nextState = tapFunnyBoomCell(state: nextState, coordinate: coordinate)

        case .skipSpecialModeCountdown:
            nextState = skipSpecialModeCountdown(state: nextState, dependencies: dependencies)

        case .timerTick:
            let transition = tick(state: nextState, dependencies: dependencies)
            nextState = transition.state
            events.append(contentsOf: transition.events)

        case .dismissVictoryPrompt:
            nextState.pendingVictory = nil

        case let .scoresLoaded(scores):
            nextState.scores = ScoreEntry.topTen(from: scores)
        }

        return GameTransition(state: nextState, events: events)
    }

    static func resetRound(from state: GameState) -> GameState {
        GameState(
            settings: state.settings,
            board: nil,
            phase: .idle,
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
            tileScorePulses: [:],
            pendingVictory: nil,
            scores: state.scores,
            explosionSequence: state.explosionSequence
        )
    }
}
