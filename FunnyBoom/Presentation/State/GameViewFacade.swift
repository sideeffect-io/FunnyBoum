import Foundation
import Observation

struct GameBoardViewState: Equatable {
    let board: GameBoard?
    let dimensions: BoardDimensions
    let canInteractWithBoard: Bool
    let funnyBoomOverlay: FunnyBoomOverlay?
    let revealedTiles: Set<BoardCoordinate>
    let flaggedTiles: Set<BoardCoordinate>
    let activePower: ActivePower?
    let tileScorePulses: [TileScorePulse]

    func scorePulse(at coordinate: BoardCoordinate) -> TileScorePulse? {
        tileScorePulses.first { $0.coordinate == coordinate }
    }

    func cellState(for coordinate: BoardCoordinate) -> CellViewState {
        CellViewState(
            isMine: board?.isMine(coordinate) ?? false,
            adjacentMines: board?.adjacentMineCount(at: coordinate) ?? 0,
            isRevealed: revealedTiles.contains(coordinate),
            isFlagged: flaggedTiles.contains(coordinate),
            canInteract: canInteractWithBoard && funnyBoomOverlay == nil,
            isXrayActive: {
                if case .xray = activePower {
                    return true
                }
                return false
            }()
        )
    }
}

@MainActor
@Observable
final class GameViewFacade {
    @ObservationIgnored
    private let store: GameStore

    var state: GameState {
        store.state
    }

    var isLossCardVisible: Bool {
        store.isLossCardVisible
    }

    init(store: GameStore) {
        self.store = store
    }

    var boardViewState: GameBoardViewState {
        GameBoardViewState(
            board: state.board,
            dimensions: state.dimensions,
            canInteractWithBoard: state.canInteractWithBoard,
            funnyBoomOverlay: state.funnyBoomOverlay,
            revealedTiles: state.revealedTiles,
            flaggedTiles: state.flaggedTiles,
            activePower: state.activePower,
            tileScorePulses: state.tileScorePulses
        )
    }

    func send(_ action: GameAction) {
        store.send(action)
    }

    func setDifficulty(_ difficulty: GameDifficulty) {
        store.send(.setDifficulty(difficulty))
    }

    func setBoardSize(_ boardSize: BoardSizePreset) {
        store.send(.setBoardSize(boardSize))
    }

    func tapCell(_ coordinate: BoardCoordinate) {
        store.send(.tapCell(coordinate))
    }

    func toggleFlag(_ coordinate: BoardCoordinate) {
        store.send(.toggleFlag(coordinate))
    }

    func tapFunnyBoomCell(_ coordinate: BoardCoordinate) {
        store.send(.tapFunnyBoomCell(coordinate))
    }

    func skipSpecialModeCountdown() {
        store.send(.skipSpecialModeCountdown)
    }

    @discardableResult
    func submitVictory(nickname: String) -> UUID? {
        store.submitVictory(nickname: nickname)
    }

    func clearVictoryPrompt() {
        store.clearVictoryPrompt()
    }

    func restartGame() {
        store.restartGame()
    }
}
