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

    var analyticsLabel: String {
        switch self {
        case .debutant:
            "beginner"
        case .amateur:
            "amateur"
        case .expert:
            "expert"
        case .veteran:
            "veteran"
        case .migraine:
            "migraine"
        }
    }

    var title: String {
        switch self {
        case .debutant:
            String(localized: "difficulty.debutant", defaultValue: "Beginner")
        case .amateur:
            String(localized: "difficulty.amateur", defaultValue: "Amateur")
        case .expert:
            String(localized: "difficulty.expert", defaultValue: "Expert")
        case .veteran:
            String(localized: "difficulty.veteran", defaultValue: "Veteran")
        case .migraine:
            String(localized: "difficulty.migraine", defaultValue: "Migraine")
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
    // Keep legacy case identifiers stable for Codable compatibility with previously saved settings.
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
        case .large25x20: "22 x 16"
        case .monster35x23: "26 x 18"
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
        case .large25x20: BoardDimensions(rows: 16, columns: 22)
        case .monster35x23: BoardDimensions(rows: 18, columns: 26)
        case .phone10x14: BoardDimensions(rows: 14, columns: 10)
        case .phone12x18: BoardDimensions(rows: 18, columns: 12)
        case .phone14x22: BoardDimensions(rows: 22, columns: 14)
        }
    }

    static let regularPresets: [BoardSizePreset] = [
        .rectangular20x15,
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
