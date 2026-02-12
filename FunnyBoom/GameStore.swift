import Foundation
import Combine

struct ScoresClient: Sendable {
    var loadTopScores: @Sendable () async -> [ScoreEntry]
    var saveScore: @Sendable (ScoreEntry) async -> [ScoreEntry]
}

actor ScorePersistence {
    private let userDefaults: UserDefaults
    private let key = "funnyboom.top-scores.v1"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadScores() -> [ScoreEntry] {
        guard let data = userDefaults.data(forKey: key) else {
            return []
        }

        do {
            let decoded = try JSONDecoder().decode([ScoreEntry].self, from: data)
            return ScoreEntry.topTen(from: decoded)
        } catch {
            return []
        }
    }

    func save(score: ScoreEntry) -> [ScoreEntry] {
        var allScores = loadScores()
        allScores.append(score)
        let topScores = ScoreEntry.topTen(from: allScores)

        do {
            let encoded = try JSONEncoder().encode(topScores)
            userDefaults.set(encoded, forKey: key)
        } catch {
            return topScores
        }

        return topScores
    }
}

extension ScoresClient {
    static let live: ScoresClient = {
        let persistence = ScorePersistence()
        return ScoresClient(
            loadTopScores: {
                await persistence.loadScores()
            },
            saveScore: { score in
                await persistence.save(score: score)
            }
        )
    }()
}

@MainActor
final class GameStore: ObservableObject {
    @Published private(set) var state: GameState
    @Published var isRulesPresented: Bool
    @Published var isScoresPresented: Bool
    @Published var isLossCardVisible: Bool

    private let environment: GameEnvironment
    private let scoresClient: ScoresClient

    private var timerTask: Task<Void, Never>?
    private var lossCardTask: Task<Void, Never>?

    init(
        state: GameState = GameState(),
        environment: GameEnvironment = .live,
        scoresClient: ScoresClient = .live
    ) {
        self.state = state
        self.environment = environment
        self.scoresClient = scoresClient
        isRulesPresented = false
        isScoresPresented = false
        isLossCardVisible = false

        Task {
            await loadScores()
        }
    }

    deinit {
        timerTask?.cancel()
        lossCardTask?.cancel()
    }

    func send(_ action: GameAction) {
        let previousState = state
        state = GameReducer.reduce(state: state, action: action, environment: environment)

        synchronizeTimer(previous: previousState.phase, current: state.phase)

        if previousState.explosionSequence != state.explosionSequence {
            scheduleLossCardReveal()
        }

        if previousState.phase == .lost && state.phase != .lost {
            isLossCardVisible = false
            lossCardTask?.cancel()
        }
    }

    func submitVictory(nickname: String) {
        guard let pendingVictory = state.pendingVictory else {
            return
        }

        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNickname.isEmpty else {
            return
        }

        let entry = ScoreEntry(
            id: UUID(),
            nickname: trimmedNickname,
            points: pendingVictory.points,
            elapsedSeconds: pendingVictory.elapsedSeconds,
            totalScore: pendingVictory.totalScore,
            boardSize: state.settings.boardSize,
            difficulty: state.settings.difficulty,
            playedAt: environment.now()
        )

        send(.dismissVictoryPrompt)

        Task {
            let topScores = await scoresClient.saveScore(entry)
            await MainActor.run {
                self.send(.scoresLoaded(topScores))
                self.isScoresPresented = true
            }
        }
    }

    func clearVictoryPrompt() {
        send(.dismissVictoryPrompt)
    }

    func restartGame() {
        send(.startNewRound)
    }

    private func loadScores() async {
        let topScores = await scoresClient.loadTopScores()
        await MainActor.run {
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

        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else {
                    return
                }
                await MainActor.run {
                    self?.send(.timerTick)
                }
            }
        }
    }

    private func scheduleLossCardReveal() {
        isLossCardVisible = false
        lossCardTask?.cancel()

        lossCardTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1100))
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                guard let self, self.state.phase == .lost else {
                    return
                }
                self.isLossCardVisible = true
            }
        }
    }
}
