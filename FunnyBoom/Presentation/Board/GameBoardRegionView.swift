import SwiftUI

struct GameBoardRegionView<Cell: View>: View {
    let dimensions: BoardDimensions
    let cellSize: CGSize
    let cell: (BoardCoordinate) -> Cell

    var body: some View {
        BoardGridView(dimensions: dimensions, cellSize: cellSize, cell: cell)
    }
}

struct BoardGridView<Cell: View>: View {
    let dimensions: BoardDimensions
    let cellSize: CGSize
    let spacing: CGFloat
    let cell: (BoardCoordinate) -> Cell

    init(
        dimensions: BoardDimensions,
        cellSize: CGSize,
        spacing: CGFloat = 1,
        @ViewBuilder cell: @escaping (BoardCoordinate) -> Cell
    ) {
        self.dimensions = dimensions
        self.cellSize = cellSize
        self.spacing = spacing
        self.cell = cell
    }

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(0..<dimensions.rows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<dimensions.columns, id: \.self) { column in
                        let coordinate = BoardCoordinate(row: row, column: column)
                        cell(coordinate)
                            .frame(width: cellSize.width, height: cellSize.height)
                            .contentShape(Rectangle())
                    }
                }
            }
        }
    }
}

struct BoardMetrics {
    let cellSize: CGSize
    let boardWidth: CGFloat
    let boardHeight: CGFloat
}

struct FunnyBoomOverlayBoardView: View {
    let dimensions: BoardDimensions
    let cellSize: CGSize
    let overlay: FunnyBoomOverlay
    let onTap: (BoardCoordinate) -> Void
    let allowsScrolling: Bool
    let compactStyle: Bool

    init(
        dimensions: BoardDimensions,
        cellSize: CGSize,
        overlay: FunnyBoomOverlay,
        onTap: @escaping (BoardCoordinate) -> Void,
        allowsScrolling: Bool = true,
        compactStyle: Bool = false
    ) {
        self.dimensions = dimensions
        self.cellSize = cellSize
        self.overlay = overlay
        self.onTap = onTap
        self.allowsScrolling = allowsScrolling
        self.compactStyle = compactStyle
    }

    var body: some View {
        ZStack {
            RetroPalette.boardWellDark
                .clipShape(.rect(cornerRadius: 8))

            VStack(spacing: compactStyle ? 4 : 8) {
                HStack {
                    VStack(alignment: .leading, spacing: compactStyle ? 1 : 2) {
                        Text(
                            overlay.isBriefing
                                ? String(
                                    localized: "funny_boom.ready",
                                    defaultValue: "FUNNY BOOM READY"
                                )
                                : String(
                                    localized: "funny_boom.live",
                                    defaultValue: "FUNNY BOOM LIVE"
                                )
                        )
                            .retroPixelFont(
                                size: compactStyle ? 10 : 11,
                                weight: .black,
                                color: RetroPalette.cobalt,
                                tracking: 0.5
                            )
                        Text(
                            overlay.isBriefing
                                ? String(
                                    localized: "funny_boom.wait_instruction",
                                    defaultValue: "Wait, then tap clown heads for +10."
                                )
                                : String(
                                    localized: "funny_boom.live_instruction",
                                    defaultValue: "Tap clown heads now for +10."
                                )
                        )
                            .font(.system(size: compactStyle ? 10 : 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(RetroPalette.ink.opacity(0.82))
                    }
                    Spacer()
                    HStack(spacing: compactStyle ? 5 : 6) {
                        earnedPointsPill
                        countdownPill
                    }
                }
                .padding(.horizontal, compactStyle ? 8 : 10)
                .padding(.vertical, compactStyle ? 6 : 8)
                .retroInsetField(cornerRadius: 6)

                Group {
                    if allowsScrolling {
                        ScrollView([.horizontal, .vertical]) {
                            boardGrid()
                                .padding(6)
                        }
                        .scrollIndicators(.hidden)
                    } else {
                        boardGrid()
                            .padding(2)
                    }
                }
                .overlay {
                    if overlay.isBriefing {
                        Color.black.opacity(0.28)
                            .overlay {
                                VStack(spacing: compactStyle ? 5 : 7) {
                                    Text("Get Ready")
                                        .retroPixelFont(
                                            size: compactStyle ? 13 : 15,
                                            weight: .black,
                                            color: .white,
                                            tracking: 0.55
                                        )
                                    Text(
                                        String(
                                            localized: "funny_boom.starts_in",
                                            defaultValue: "Clown hunt starts in \(overlay.secondsRemaining)s"
                                        )
                                    )
                                        .font(.system(size: compactStyle ? 11 : 12, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.92))
                                }
                                .padding(.horizontal, compactStyle ? 12 : 16)
                                .padding(.vertical, compactStyle ? 8 : 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.black.opacity(0.72))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(RetroPalette.chromeEdgeLight.opacity(0.6), lineWidth: 1)
                                )
                            }
                            .allowsHitTesting(false)
                    }
                }
            }
            .padding(compactStyle ? 6 : 10)
        }
        .padding(compactStyle ? 2 : 6)
        .retroChromePanel(cornerRadius: 8)
        .transition(.opacity.combined(with: .scale))
    }

    @ViewBuilder
    private func boardGrid() -> some View {
        BoardGridView(dimensions: dimensions, cellSize: cellSize) { coordinate in
            let isRevealedClown = overlay.revealedClowns.contains(coordinate)
            let isRevealedMiss = overlay.revealedMisses.contains(coordinate)
            let isRevealed = isRevealedClown || isRevealedMiss

            Button {
                guard overlay.isInteractive else { return }
                onTap(coordinate)
            } label: {
                ZStack {
                    CellFaceView(
                        isRevealed: isRevealed,
                        isFlagged: false,
                        mineVisibleFromXray: false,
                        isMine: false,
                        adjacentMines: 0,
                        scorePulse: nil,
                        cellSize: cellSize
                    )

                    if isRevealedClown {
                        Text("🤡")
                            .font(.system(size: min(cellSize.width, cellSize.height) * 0.62))
                    }
                }
            }
            .disabled(!overlay.isInteractive)
            .buttonStyle(.plain)
        }
    }

    private var earnedPoints: Int {
        overlay.revealedClowns.count * ScoreRules.eventPoints
    }

    private var earnedPointsLabel: String {
        earnedPoints > 0 ? "+\(earnedPoints)" : "0"
    }

    private var earnedPointsColor: Color {
        earnedPoints > 0
            ? Color(red: 0.10, green: 0.46, blue: 0.14)
            : RetroPalette.cobalt
    }

    private var earnedPointsPill: some View {
        VStack(spacing: 1) {
            Text("Won")
                .font(.system(size: compactStyle ? 9 : 10, weight: .bold, design: .monospaced))
                .foregroundStyle(earnedPointsColor.opacity(0.9))
            Text(earnedPointsLabel)
                .retroPixelFont(
                    size: compactStyle ? 15 : 17,
                    weight: .black,
                    color: earnedPointsColor,
                    tracking: 0.55
                )
                .monospacedDigit()
        }
        .frame(minWidth: compactStyle ? 60 : 72)
        .padding(.horizontal, compactStyle ? 8 : 10)
        .padding(.vertical, compactStyle ? 5 : 6)
        .retroInsetField(cornerRadius: 6)
    }

    private var countdownPill: some View {
        VStack(spacing: 1) {
            Text(
                overlay.isBriefing
                    ? String(localized: "countdown.starts", defaultValue: "Starts")
                    : String(localized: "countdown.left", defaultValue: "Left")
            )
                .font(.system(size: compactStyle ? 9 : 10, weight: .bold, design: .monospaced))
                .foregroundStyle(RetroPalette.cobalt.opacity(0.9))
            Text("\(overlay.secondsRemaining)s")
                .retroPixelFont(
                    size: compactStyle ? 18 : 20,
                    weight: .black,
                    color: overlay.isBriefing ? .orange : RetroPalette.cobalt,
                    tracking: 0.6
                )
        }
        .frame(minWidth: compactStyle ? 54 : 64)
        .padding(.horizontal, compactStyle ? 8 : 10)
        .padding(.vertical, compactStyle ? 5 : 6)
        .retroInsetField(cornerRadius: 6)
    }
}

struct FunnyBoomFocusOverlayView: View {
    let dimensions: BoardDimensions
    let overlay: FunnyBoomOverlay
    let isPhoneLayout: Bool
    let onTap: (BoardCoordinate) -> Void

    var body: some View {
        GeometryReader { proxy in
            let panelHorizontalPadding = isPhoneLayout ? 10.0 : 28.0
            let panelVerticalPadding = isPhoneLayout ? 12.0 : 24.0
            let contentSize = CGSize(
                width: max(0, proxy.size.width - (panelHorizontalPadding * 2)),
                height: max(0, proxy.size.height - (panelVerticalPadding * 2))
            )
            let cellSize = focusedCellSize(for: dimensions, in: contentSize)

            ZStack {
                Color.black.opacity(0.20)
                    .background(.ultraThinMaterial)
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.18),
                                Color(red: 0.04, green: 0.06, blue: 0.20).opacity(0.38),
                                Color.black.opacity(0.26)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                FunnyBoomOverlayBoardView(
                    dimensions: dimensions,
                    cellSize: cellSize,
                    overlay: overlay,
                    onTap: onTap,
                    allowsScrolling: false,
                    compactStyle: isPhoneLayout
                )
                .frame(maxWidth: contentSize.width, maxHeight: contentSize.height)
                .padding(.horizontal, panelHorizontalPadding)
                .padding(.vertical, panelVerticalPadding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func focusedCellSize(
        for dimensions: BoardDimensions,
        in size: CGSize
    ) -> CGSize {
        let horizontalSpacing = CGFloat(max(0, dimensions.columns - 1))
        let verticalSpacing = CGFloat(max(0, dimensions.rows - 1))

        // Reserve room for header and chrome so the board can grow as much as possible.
        let availableWidth = max(0, size.width - (isPhoneLayout ? 42 : 66))
        let availableHeight = max(0, size.height - (isPhoneLayout ? 158 : 180))

        let sideFromWidth = (availableWidth - horizontalSpacing) / CGFloat(dimensions.columns)
        let sideFromHeight = (availableHeight - verticalSpacing) / CGFloat(dimensions.rows)
        let cellSide = max(isPhoneLayout ? 10 : 12, floor(min(sideFromWidth, sideFromHeight)))

        return CGSize(width: cellSide, height: cellSide)
    }
}
