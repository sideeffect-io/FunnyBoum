import Foundation
import Observation

@MainActor
@Observable
final class GameStore {
    private actor Worker {
        private let dependencies: GameDependencies

        init(dependencies: GameDependencies) {
            self.dependencies = dependencies
        }

        func reduce(state: GameState, action: GameAction) -> GameTransition {
            GameReducer.reduce(
                state: state,
                action: action,
                dependencies: dependencies
            )
        }
    }

    private(set) var state: GameState
    private(set) var isLossCardVisible: Bool

    @ObservationIgnored
    private let dependencies: GameDependencies
    @ObservationIgnored
    private let scoresClient: ScoresClient
    @ObservationIgnored
    private let effectRunner: GameEffectRunner
    @ObservationIgnored
    private let worker: Worker

    @ObservationIgnored
    private var timerTask: Task<Void, Never>?
    @ObservationIgnored
    private var lossCardTask: Task<Void, Never>?
    @ObservationIgnored
    private var scoreLoadTask: Task<Void, Never>?
    @ObservationIgnored
    private var scoreSaveTask: Task<Void, Never>?
    @ObservationIgnored
    private var actionProcessingTask: Task<Void, Never>?
    @ObservationIgnored
    private var pendingActions: [GameAction] = []

    init(
        state: GameState = GameState(),
        dependencies: GameDependencies = .live,
        scoresClient: ScoresClient = .live,
        soundClient: SoundClient? = nil,
        analyticsClient: AnalyticsClient = .noop
    ) {
        self.state = state
        self.dependencies = dependencies
        self.scoresClient = scoresClient
        self.effectRunner = GameEffectRunner(
            soundClient: soundClient ?? SoundClient.live(),
            analyticsClient: analyticsClient
        )
        self.worker = Worker(dependencies: dependencies)
        isLossCardVisible = false

        scheduleScoreLoad()
    }

    deinit {
        timerTask?.cancel()
        lossCardTask?.cancel()
        scoreLoadTask?.cancel()
        scoreSaveTask?.cancel()
        actionProcessingTask?.cancel()
    }

    func send(_ action: GameAction) {
        if action.requiresBackgroundReduction {
            enqueueAction(action)
            return
        }

        if actionProcessingTask == nil && pendingActions.isEmpty {
            let transition = GameReducer.reduce(
                state: state,
                action: action,
                dependencies: dependencies
            )
            applyTransition(transition)
            return
        }

        enqueueAction(action)
    }

    @discardableResult
    func submitVictory(nickname: String) -> UUID? {
        guard let pendingVictory = state.pendingVictory else {
            return nil
        }

        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNickname.isEmpty else {
            return nil
        }

        let entry = ScoreEntry(
            id: UUID(),
            nickname: trimmedNickname,
            points: pendingVictory.points,
            elapsedSeconds: pendingVictory.elapsedSeconds,
            totalScore: pendingVictory.totalScore,
            boardSize: state.settings.boardSize,
            difficulty: state.settings.difficulty,
            playedAt: dependencies.now()
        )

        send(.dismissVictoryPrompt)
        scheduleScoreSave(entry)

        return entry.id
    }

    func clearVictoryPrompt() {
        send(.dismissVictoryPrompt)
    }

    func restartGame() {
        send(.startNewRound)
    }

    private func scheduleScoreLoad() {
        scoreLoadTask?.cancel()

        scoreLoadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let topScores = await self.scoresClient.loadTopScores()
            guard !Task.isCancelled else { return }
            self.send(.scoresLoaded(topScores))
        }
    }

    private func scheduleScoreSave(_ entry: ScoreEntry) {
        scoreSaveTask?.cancel()

        scoreSaveTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let topScores = await self.scoresClient.saveScore(entry)
            guard !Task.isCancelled else { return }
            self.send(.scoresLoaded(topScores))
        }
    }

    private func synchronizeTimer(previous: GamePhase, current: GamePhase) {
        guard previous != current else {
            return
        }

        if current == .running {
            startTimerIfNeeded()
        } else {
            timerTask?.cancel()
            timerTask = nil
        }
    }

    private func startTimerIfNeeded() {
        guard timerTask == nil else {
            return
        }

        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else {
                    return
                }
                self.send(.timerTick)
            }
        }
    }

    private func scheduleLossCardReveal() {
        isLossCardVisible = false
        lossCardTask?.cancel()

        lossCardTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(1100))
            guard !Task.isCancelled, let self else {
                return
            }
            guard self.state.phase == .lost else {
                return
            }
            self.isLossCardVisible = true
        }
    }

    private func enqueueAction(_ action: GameAction) {
        pendingActions.append(action)
        processPendingActionsIfNeeded()
    }

    private func processPendingActionsIfNeeded() {
        guard actionProcessingTask == nil else {
            return
        }

        actionProcessingTask = Task { @MainActor [weak self] in
            await self?.processPendingActions()
        }
    }

    private func processPendingActions() async {
        defer {
            actionProcessingTask = nil
            if !pendingActions.isEmpty {
                processPendingActionsIfNeeded()
            }
        }

        while !pendingActions.isEmpty {
            let action = pendingActions.removeFirst()
            let transition: GameTransition

            if action.requiresBackgroundReduction {
                transition = await worker.reduce(state: state, action: action)
            } else {
                transition = GameReducer.reduce(
                    state: state,
                    action: action,
                    dependencies: dependencies
                )
            }

            if Task.isCancelled {
                return
            }

            applyTransition(transition)
        }
    }

    private func applyTransition(_ transition: GameTransition) {
        if transition.state == state && transition.events.isEmpty {
            return
        }

        let previousPhase = state.phase
        state = transition.state

        synchronizeTimer(previous: previousPhase, current: state.phase)

        effectRunner.run(transition.events) {
            scheduleLossCardReveal()
        }

        if previousPhase == .lost && state.phase != .lost {
            isLossCardVisible = false
            lossCardTask?.cancel()
        }
    }
}

private extension GameAction {
    var requiresBackgroundReduction: Bool {
        switch self {
        case .tapCell:
            true
        default:
            false
        }
    }
}
