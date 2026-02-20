import Foundation

extension GameReducer {
    static func tapCell(
        state: GameState,
        coordinate: BoardCoordinate,
        dependencies: GameDependencies
    ) -> GameTransition {
        guard state.canInteractWithBoard else { return GameTransition(state: state) }
        guard state.funnyBoomOverlay == nil else { return GameTransition(state: state) }
        guard state.dimensions.isValid(coordinate) else { return GameTransition(state: state) }

        var nextState = state
        var events: [GameDomainEvent] = []

        if nextState.flaggedTiles.contains(coordinate) {
            return GameTransition(state: nextState)
        }

        if nextState.board == nil {
            nextState.board = GameBoard.generate(
                settings: nextState.settings,
                safeCoordinate: coordinate,
                randomInt: dependencies.randomInt
            )
            nextState.phase = .running
        }

        guard let board = nextState.board else {
            return GameTransition(state: nextState)
        }

        if nextState.revealedTiles.contains(coordinate) {
            return chordRevealIfPossible(state: nextState, coordinate: coordinate, board: board)
        }

        if board.isMine(coordinate) {
            if nextState.isSuperheroActive {
                nextState.revealedTiles.insert(coordinate)
                nextState.neutralizedBombs.insert(coordinate)
                nextState.flaggedTiles.remove(coordinate)
                let completion = completeIfWon(state: nextState, board: board)
                nextState = completion.state
                events.append(contentsOf: completion.events)
                appendBoardStartedEventIfNeeded(
                    previousState: state,
                    nextState: nextState,
                    events: &events
                )
                return GameTransition(state: nextState, events: events)
            }

            var loss = loseRound(state: nextState, board: board)
            appendBoardStartedEventIfNeeded(
                previousState: state,
                nextState: loss.state,
                events: &loss.events
            )
            return loss
        }

        let revealedNow = floodReveal(
            from: coordinate,
            board: board,
            alreadyRevealed: nextState.revealedTiles,
            flagged: nextState.flaggedTiles
        )

        let newSafeTiles = revealedNow.subtracting(nextState.revealedTiles)
        nextState.revealedTiles.formUnion(revealedNow)
        nextState.points += newSafeTiles.count * ScoreRules.revealPoints

        events.append(contentsOf: maybeApplySpecialEffect(
            state: &nextState,
            board: board,
            tappedCoordinate: coordinate,
            newlyRevealed: newSafeTiles,
            dependencies: dependencies
        ))

        let completion = completeIfWon(state: nextState, board: board)
        nextState = completion.state
        events.append(contentsOf: completion.events)
        appendBoardStartedEventIfNeeded(
            previousState: state,
            nextState: nextState,
            events: &events
        )

        return GameTransition(state: nextState, events: events)
    }

    static func appendBoardStartedEventIfNeeded(
        previousState: GameState,
        nextState: GameState,
        events: inout [GameDomainEvent]
    ) {
        guard previousState.revealedTiles.isEmpty else {
            return
        }
        guard !nextState.revealedTiles.isEmpty else {
            return
        }

        events.append(
            .trackBoardStarted(
                BoardStartedAnalytics(
                    difficulty: nextState.settings.difficulty,
                    boardSize: nextState.dimensions
                )
            )
        )
    }

    static func tapFunnyBoomCell(state: GameState, coordinate: BoardCoordinate) -> GameState {
        guard state.phase == .running else { return state }
        guard var overlay = state.funnyBoomOverlay else { return state }
        guard overlay.isInteractive else { return state }

        var nextState = state

        if overlay.clownTiles.contains(coordinate) {
            let insertion = overlay.revealedClowns.insert(coordinate)
            guard insertion.inserted else {
                return state
            }
            nextState.points += ScoreRules.eventPoints
            nextState.bonusPoints += ScoreRules.eventPoints
            enqueueTileScorePulse(
                state: &nextState,
                coordinate: coordinate,
                pointsDelta: ScoreRules.eventPoints
            )
        } else {
            let insertion = overlay.revealedMisses.insert(coordinate)
            guard insertion.inserted else {
                return state
            }
        }

        nextState.funnyBoomOverlay = overlay
        return nextState
    }

    static func toggleFlag(state: GameState, coordinate: BoardCoordinate) -> GameTransition {
        guard state.canInteractWithBoard else { return GameTransition(state: state) }
        guard state.funnyBoomOverlay == nil else { return GameTransition(state: state) }

        var nextState = state

        guard !nextState.revealedTiles.contains(coordinate) else {
            return GameTransition(state: nextState)
        }

        var events: [GameDomainEvent] = []
        if nextState.flaggedTiles.contains(coordinate) {
            nextState.flaggedTiles.remove(coordinate)
        } else {
            nextState.flaggedTiles.insert(coordinate)
            events.append(.playSound(.flagPlaced))
        }

        return GameTransition(state: nextState, events: events)
    }

    static func chordRevealIfPossible(
        state: GameState,
        coordinate: BoardCoordinate,
        board: GameBoard
    ) -> GameTransition {
        guard board.adjacentMineCount(at: coordinate) > 0 else {
            return GameTransition(state: state)
        }

        let neighbors = board.neighbors(of: coordinate)
        let flaggedNeighbors = neighbors.filter { state.flaggedTiles.contains($0) }.count

        guard flaggedNeighbors == board.adjacentMineCount(at: coordinate) else {
            return GameTransition(state: state)
        }

        var nextState = state
        var events: [GameDomainEvent] = []

        for neighbor in neighbors where !state.flaggedTiles.contains(neighbor) && !state.revealedTiles.contains(neighbor) {
            if board.isMine(neighbor) {
                if state.isSuperheroActive {
                    nextState.revealedTiles.insert(neighbor)
                    nextState.neutralizedBombs.insert(neighbor)
                } else {
                    return loseRound(state: nextState, board: board)
                }
            } else {
                let revealed = floodReveal(
                    from: neighbor,
                    board: board,
                    alreadyRevealed: nextState.revealedTiles,
                    flagged: nextState.flaggedTiles
                )
                let newlyRevealed = revealed.subtracting(nextState.revealedTiles)
                nextState.revealedTiles.formUnion(revealed)
                nextState.points += newlyRevealed.count * ScoreRules.revealPoints
            }
        }

        let completion = completeIfWon(state: nextState, board: board)
        nextState = completion.state
        events.append(contentsOf: completion.events)

        return GameTransition(state: nextState, events: events)
    }

    static func completeIfWon(state: GameState, board: GameBoard) -> GameTransition {
        var nextState = state

        let safeCells = board.dimensions.cellCount - board.mineCount
        let revealedSafeCells = nextState.revealedTiles.filter { !board.isMine($0) }.count

        if revealedSafeCells >= safeCells {
            nextState.phase = .won
            nextState.activePower = nil
            nextState.funnyBoomOverlay = nil
            nextState.specialModeNotice = nil
            nextState.tileScorePulses = [:]

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

            return GameTransition(state: nextState, events: [.playSound(.victory)])
        }

        return GameTransition(state: nextState)
    }

    static func loseRound(state: GameState, board: GameBoard) -> GameTransition {
        var nextState = state
        nextState.phase = .lost
        nextState.activePower = nil
        nextState.funnyBoomOverlay = nil
        nextState.specialModeNotice = nil
        nextState.tileScorePulses = [:]
        nextState.pendingVictory = nil
        nextState.revealedTiles.formUnion(board.mines)
        nextState.explosionSequence += 1

        return GameTransition(
            state: nextState,
            events: [.playSound(.explosion), .scheduleLossCardReveal]
        )
    }

    static func floodReveal(
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
