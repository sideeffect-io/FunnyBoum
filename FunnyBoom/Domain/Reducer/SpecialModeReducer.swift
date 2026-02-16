import Foundation

extension GameReducer {
    static func forceSpecialMode(
        state: GameState,
        style: SpecialModeStyle,
        dependencies: GameDependencies
    ) -> GameState {
        guard state.phase == .idle || state.phase == .running else {
            return state
        }

        var nextState = state
        nextState.activePower = nil
        nextState.funnyBoomOverlay = nil
        nextState.specialModeNotice = nil
        nextState = ensureBoardForForcedSpecialMode(
            state: nextState,
            dependencies: dependencies
        )
        nextState.specialModeNotice = makeModeNotice(for: style)
        return nextState
    }

    static func ensureBoardForForcedSpecialMode(
        state: GameState,
        dependencies: GameDependencies
    ) -> GameState {
        var nextState = state

        if nextState.board == nil {
            let dimensions = nextState.settings.boardSize.dimensions
            let safeCoordinate = BoardCoordinate(
                row: dimensions.rows / 2,
                column: dimensions.columns / 2
            )
            nextState.board = GameBoard.generate(
                settings: nextState.settings,
                safeCoordinate: safeCoordinate,
                randomInt: dependencies.randomInt
            )
        }

        if nextState.phase == .idle {
            nextState.phase = .running
        }

        return nextState
    }

    static func maybeApplySpecialEffect(
        state: inout GameState,
        board: GameBoard,
        tappedCoordinate: BoardCoordinate,
        newlyRevealed: Set<BoardCoordinate>,
        dependencies: GameDependencies
    ) -> [GameDomainEvent] {
        guard newlyRevealed.contains(tappedCoordinate) else {
            return []
        }

        guard board.adjacentMineCount(at: tappedCoordinate) == 0 else {
            return []
        }

        guard !state.specialRollTiles.contains(tappedCoordinate) else {
            return []
        }

        state.specialRollTiles.insert(tappedCoordinate)

        guard dependencies.randomUnit() < ScoreRules.specialTriggerProbability else {
            return []
        }

        let events: [GameDomainEvent] = [.playSound(.specialSquareDiscovered)]
        state.activePower = nil
        state.funnyBoomOverlay = nil
        state.specialModeNotice = nil

        let effects = SpecialEffect.allCases
        let index = max(0, min(effects.count - 1, dependencies.randomInt(effects.count)))

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
            state.specialModeNotice = makeModeNotice(for: .xray)

        case .superhero:
            state.specialModeNotice = makeModeNotice(for: .superhero)

        case .funnyBoom:
            state.specialModeNotice = makeModeNotice(for: .funnyBoom)
        }

        return events
    }

    static func makeModeNotice(for style: SpecialModeStyle) -> SpecialModeNotice {
        switch style {
        case .xray:
            return makeModeNotice(
                style: .xray,
                title: String(
                    localized: "special_notice.xray.title",
                    defaultValue: "X-RAY CHARGING"
                ),
                subtitle: String(
                    localized: "special_notice.xray.subtitle",
                    defaultValue: "Scan starts soon. Bombs will be visible for \(ScoreRules.xrayActiveDuration)s."
                ),
                symbol: "eye.fill",
                duration: ScoreRules.specialModePreparationDuration
            )

        case .superhero:
            return makeModeNotice(
                style: .superhero,
                title: String(
                    localized: "special_notice.superhero.title",
                    defaultValue: "SUIT POWERING UP"
                ),
                subtitle: String(
                    localized: "special_notice.superhero.subtitle",
                    defaultValue: "Armor starts soon. Bomb tiles are safe for \(ScoreRules.superheroActiveDuration)s."
                ),
                symbol: "bolt.fill",
                duration: ScoreRules.specialModePreparationDuration
            )

        case .funnyBoom:
            return makeModeNotice(
                style: .funnyBoom,
                title: String(
                    localized: "special_notice.funny_boom.title",
                    defaultValue: "CLOWN HUNT LOADING"
                ),
                subtitle: String(
                    localized: "special_notice.funny_boom.subtitle",
                    defaultValue: "Stress-click the board to reveal clown heads (+\(ScoreRules.eventPoints) each). Hunt lasts \(ScoreRules.funnyBoomPlayDuration)s."
                ),
                symbol: "theatermasks.fill",
                duration: ScoreRules.specialModePreparationDuration
            )
        }
    }

    static func makeModeNotice(
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

    static func skipSpecialModeCountdown(
        state: GameState,
        dependencies: GameDependencies
    ) -> GameState {
        guard let notice = state.specialModeNotice, notice.isActivationCountdown else {
            return state
        }

        return activatePreparedSpecialModeIfNeeded(
            state: state,
            style: notice.style,
            dependencies: dependencies
        )
    }

    static func activatePreparedSpecialModeIfNeeded(
        state: GameState,
        style: SpecialModeStyle,
        dependencies: GameDependencies
    ) -> GameState {
        var nextState = state

        switch style {
        case .xray:
            nextState.activePower = .xray(secondsRemaining: ScoreRules.xrayActiveDuration)

        case .superhero:
            nextState.activePower = .superhero(secondsRemaining: ScoreRules.superheroActiveDuration)

        case .funnyBoom:
            if let board = nextState.board {
                nextState.funnyBoomOverlay = makeFunnyBoomOverlay(
                    board: board,
                    dependencies: dependencies
                )
            }
        }

        nextState.specialModeNotice = nil
        return nextState
    }

    static func makeFunnyBoomOverlay(
        board: GameBoard,
        dependencies: GameDependencies
    ) -> FunnyBoomOverlay {
        let dimensions = board.dimensions
        var candidates = dimensions.allCoordinates
        let clownCount = min(
            max(6, Int(Double(dimensions.cellCount) * ScoreRules.clownDensity)),
            candidates.count
        )

        var clowns: Set<BoardCoordinate> = []
        while clowns.count < clownCount && !candidates.isEmpty {
            let randomIndex = max(0, min(candidates.count - 1, dependencies.randomInt(candidates.count)))
            clowns.insert(candidates.remove(at: randomIndex))
        }

        return FunnyBoomOverlay(
            clownTiles: clowns,
            revealedClowns: [],
            revealedMisses: [],
            phase: .active(secondsRemaining: ScoreRules.funnyBoomPlayDuration)
        )
    }

    static func enqueueTileScorePulse(
        state: inout GameState,
        coordinate: BoardCoordinate,
        pointsDelta: Int
    ) {
        state.tileScorePulses[coordinate] = TileScorePulse(
            id: UUID(),
            coordinate: coordinate,
            pointsDelta: pointsDelta,
            secondsRemaining: ScoreRules.tileScorePulseDuration
        )
    }
}
