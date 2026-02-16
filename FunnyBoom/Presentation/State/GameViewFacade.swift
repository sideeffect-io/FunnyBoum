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
    let tileScorePulsesByCoordinate: [BoardCoordinate: TileScorePulse]

    init(
        board: GameBoard?,
        dimensions: BoardDimensions,
        canInteractWithBoard: Bool,
        funnyBoomOverlay: FunnyBoomOverlay?,
        revealedTiles: Set<BoardCoordinate>,
        flaggedTiles: Set<BoardCoordinate>,
        activePower: ActivePower?,
        tileScorePulsesByCoordinate: [BoardCoordinate: TileScorePulse]
    ) {
        self.board = board
        self.dimensions = dimensions
        self.canInteractWithBoard = canInteractWithBoard
        self.funnyBoomOverlay = funnyBoomOverlay
        self.revealedTiles = revealedTiles
        self.flaggedTiles = flaggedTiles
        self.activePower = activePower
        self.tileScorePulsesByCoordinate = tileScorePulsesByCoordinate
    }

    func scorePulse(at coordinate: BoardCoordinate) -> TileScorePulse? {
        tileScorePulsesByCoordinate[coordinate]
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
            tileScorePulsesByCoordinate: state.tileScorePulses
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

    func forceSpecialMode(_ mode: SpecialModeStyle) {
        store.send(.forceSpecialMode(mode))
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
