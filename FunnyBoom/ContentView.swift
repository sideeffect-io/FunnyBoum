import SwiftUI

struct ContentView: View {
    @StateObject private var store = GameStore()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isPhoneMenuPresented = false

    private var pendingVictoryBinding: Binding<PendingVictory?> {
        Binding(
            get: { store.state.pendingVictory },
            set: { pendingVictory in
                if pendingVictory == nil {
                    store.clearVictoryPrompt()
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RetroBackgroundView()

                GeometryReader { proxy in
                    Group {
                        if isPhoneLayout {
                            phoneLayout(in: proxy.size)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                        } else {
                            regularLayout
                                .padding(14)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(
                        RoundedRectangle(cornerRadius: isPhoneLayout ? 20 : 8)
                            .fill(RetroPalette.chromeGradient)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: isPhoneLayout ? 20 : 8)
                            .stroke(RetroPalette.chromeEdgeDark, lineWidth: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: isPhoneLayout ? 19 : 7)
                            .stroke(RetroPalette.chromeEdgeLight.opacity(0.86), lineWidth: 1)
                            .padding(1)
                    )
                    .padding(isPhoneLayout ? 2 : 12)
                }

                if store.state.phase == .lost {
                    ExplosionOverlayView(
                        trigger: store.state.explosionSequence,
                        showActions: store.isLossCardVisible,
                        onNewGame: {
                            store.restartGame()
                        }
                    )
                    .transition(.opacity)
                }
            }
            .navigationTitle(isPhoneLayout ? "" : "Funny Boom")
            .platformInlineNavigationTitle()
            .hidePhoneNavigationBar(isPhoneLayout)
        }
        .sheet(isPresented: $store.isRulesPresented) {
            RulesSheetView()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $store.isScoresPresented) {
            ScoresSheetView(scores: store.state.scores)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isPhoneMenuPresented) {
            PhoneMenuSheetView(
                settings: store.state.settings,
                boardSizes: availableBoardSizes,
                soundEnabled: store.state.soundEnabled,
                onShowRules: {
                    store.isRulesPresented = true
                },
                onSetDifficulty: { difficulty in
                    store.send(.setDifficulty(difficulty))
                },
                onSetBoardSize: { boardSize in
                    store.send(.setBoardSize(boardSize))
                },
                onShowScores: {
                    store.isScoresPresented = true
                },
                onToggleSound: {
                    store.send(.toggleSound)
                },
                onNewGame: {
                    store.restartGame()
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(item: pendingVictoryBinding) { victory in
            VictorySheetView(
                victory: victory,
                onSubmit: { nickname in
                    store.submitVictory(nickname: nickname)
                },
                onNewGame: {
                    store.restartGame()
                },
                onDismiss: {
                    store.clearVictoryPrompt()
                }
            )
        }
        .preferredColorScheme(.light)
        .task(id: isPhoneLayout) {
            enforceBoardSizeForCurrentDevice()
        }
    }

    private var isPhoneLayout: Bool {
#if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone && horizontalSizeClass == .compact
#else
        false
#endif
    }

    private var regularLayout: some View {
        VStack(spacing: 10) {
            header
            controlsBar

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    statsPanel
                        .frame(width: 250)
                    boardPanel
                }

                VStack(spacing: 14) {
                    statsPanel
                    boardPanel
                }
            }
        }
    }

    private var availableBoardSizes: [BoardSizePreset] {
        isPhoneLayout ? BoardSizePreset.phonePortraitPresets : BoardSizePreset.regularPresets
    }

    private func enforceBoardSizeForCurrentDevice() {
        if isPhoneLayout {
            if !BoardSizePreset.phonePortraitPresets.contains(store.state.settings.boardSize) {
                store.send(.setBoardSize(.phone12x18))
            }
        } else {
            if BoardSizePreset.phonePortraitPresets.contains(store.state.settings.boardSize) {
                store.send(.setBoardSize(.classic20x20))
            }
        }
    }

    private func phoneLayout(in _: CGSize) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Funny Boom")
                        .retroPixelFont(size: 24, weight: .black, color: RetroPalette.ink, tracking: 0.7)
                    Text("\(store.state.settings.difficulty.title) • \(store.state.settings.boardSize.title)")
                        .retroPixelFont(size: 11, weight: .bold, color: RetroPalette.cobalt.opacity(0.9), tracking: 0.4)
                }

                RetroLogoBadge(size: 38)

                Spacer()

                Button {
                    isPhoneMenuPresented = true
                } label: {
                    Label("Menu", systemImage: "line.3.horizontal")
                        .retroPixelFont(size: 12, weight: .bold, color: RetroPalette.cobalt, tracking: 0.4)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .retroTabStyle()
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.top, 2)

            phoneCompactHUD

            GeometryReader { proxy in
                phoneBoardPanel(in: proxy.size)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var phoneCompactHUD: some View {
        HStack(spacing: 6) {
            CompactMetricPill(title: "Score", value: "\(store.state.points)")
            CompactMetricPill(title: "Time", value: "\(store.state.elapsedSeconds)s")
            CompactMetricPill(title: "Bombs", value: "\(store.state.remainingBombs)")
            CompactMetricPill(title: "Bonus", value: "\(store.state.bonusPoints)")
        }
        .padding(8)
        .retroChromePanel(cornerRadius: 8)
    }

    private func phoneBoardPanel(in size: CGSize) -> some View {
        let dimensions = store.state.dimensions
        let metrics = fixedBoardMetrics(for: dimensions, in: size, verticalChrome: 96)

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 8) {
                    Text("Board")
                        .font(.system(.headline, design: .monospaced).weight(.bold))
                        .foregroundStyle(RetroPalette.cobalt)
                    resetBoardButton(compact: true)
                }
                Spacer()
                boardModeToggle(compact: true)
            }

            ZStack {
                BoardGridView(dimensions: dimensions, cellSide: metrics.cellSide) { coordinate in
                    CellButtonView(
                        coordinate: coordinate,
                        state: store.state,
                        scorePulse: scorePulse(at: coordinate),
                        cellSide: metrics.cellSide,
                        onReveal: {
                            store.send(.tapCell(coordinate))
                        },
                        onFlag: {
                            store.send(.toggleFlag(coordinate))
                        }
                    )
                }

                if let funnyOverlay = store.state.funnyBoomOverlay {
                    FunnyBoomOverlayBoardView(
                        dimensions: dimensions,
                        cellSide: metrics.cellSide,
                        overlay: funnyOverlay,
                        onTap: { coordinate in
                            store.send(.tapFunnyBoomCell(coordinate))
                        },
                        allowsScrolling: false,
                        compactStyle: true
                    )
                }

                specialModeBoardPopup(compact: true)
            }
            .frame(width: metrics.boardWidth, height: metrics.boardHeight)
            .clipShape(.rect(cornerRadius: 10))
            .padding(6)
            .frame(maxWidth: .infinity)
            .retroBoardWell(cornerRadius: 12)

            HStack {
                Text("\(dimensions.columns)x\(dimensions.rows)")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(RetroPalette.ink.opacity(0.74))
                Spacer()
                if let activePower = store.state.activePower {
                    Label("\(activePower.label) \(activePower.secondsRemaining)s", systemImage: "sparkles")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(RetroPalette.cobalt)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .retroInsetField(cornerRadius: 5)
                }
            }
        }
        .padding(8)
        .retroChromePanel(cornerRadius: 8)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Funny   B O U M")
                    .retroPixelFont(size: 45, weight: .black, color: RetroPalette.ink, tracking: 0.9)

                Text("Version # 1.0   (c) B/W,1995.")
                    .retroPixelFont(size: 14, weight: .black, color: RetroPalette.ink.opacity(0.9), tracking: 0.5)
            }

            RetroLogoBadge(size: 104)
                .padding(.top, -8)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 2) {
                Text("2026 Edition")
                    .retroPixelFont(size: 28, weight: .black, color: RetroPalette.ink, tracking: 0.7)
                Text("Retro-modern generation")
                    .retroPixelFont(size: 12, weight: .bold, color: RetroPalette.cobalt.opacity(0.9), tracking: 0.3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .retroChromePanel(cornerRadius: 6)
    }

    private var controlsBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                controlButton(title: "Rules") {
                    store.isRulesPresented = true
                }

                Menu {
                    ForEach(GameDifficulty.allCases) { difficulty in
                        Button {
                            store.send(.setDifficulty(difficulty))
                        } label: {
                            if difficulty == store.state.settings.difficulty {
                                Label(difficulty.title, systemImage: "checkmark")
                            } else {
                                Text(difficulty.title)
                            }
                        }
                    }
                } label: {
                    ControlTag(
                        title: "Difficulty",
                        subtitle: store.state.settings.difficulty.title
                    )
                }

                Menu {
                    ForEach(availableBoardSizes) { boardSize in
                        Button {
                            store.send(.setBoardSize(boardSize))
                        } label: {
                            if boardSize == store.state.settings.boardSize {
                                Label(boardSize.title, systemImage: "checkmark")
                            } else {
                                Text(boardSize.title)
                            }
                        }
                    }
                } label: {
                    ControlTag(
                        title: "Board",
                        subtitle: store.state.settings.boardSize.title
                    )
                }

                controlButton(title: "Scores") {
                    store.isScoresPresented = true
                }

                controlButton(
                    title: store.state.soundEnabled ? "Sound On" : "Sound Off"
                ) {
                    store.send(.toggleSound)
                }

                controlButton(title: "New Game") {
                    store.restartGame()
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, 2)
        .padding(.vertical, 3)
        .retroChromePanel(cornerRadius: 6)
    }

    private var statsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Match")
                .font(.system(.title3, design: .serif).weight(.bold))
                .foregroundStyle(RetroPalette.cobalt)

            RetroMetricField(title: "Score", value: "\(store.state.points)")
            RetroMetricField(title: "Time", value: "\(store.state.elapsedSeconds)s")
            RetroMetricField(title: "Bombs Left", value: "\(store.state.remainingBombs)")
            RetroMetricField(title: "Bonus", value: "\(store.state.bonusPoints)")

            Text(statusText)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(RetroPalette.ink.opacity(0.82))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
        }
        .padding(12)
        .retroChromePanel(cornerRadius: 6)
    }

    private var boardPanel: some View {
        let dimensions = store.state.dimensions

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 10) {
                    Text("Board")
                        .font(.system(.title3, design: .serif).weight(.bold))
                        .foregroundStyle(RetroPalette.cobalt)
                    resetBoardButton(compact: false)
                }
                Spacer()
                boardModeToggle(compact: false)
            }

            GeometryReader { proxy in
                let cellSide = fittedCellSize(for: dimensions, in: proxy.size)

                ZStack {
                    ScrollView([.horizontal, .vertical]) {
                        BoardGridView(dimensions: dimensions, cellSide: cellSide) { coordinate in
                            CellButtonView(
                                coordinate: coordinate,
                                state: store.state,
                                scorePulse: scorePulse(at: coordinate),
                                cellSide: cellSide,
                                onReveal: {
                                    store.send(.tapCell(coordinate))
                                },
                                onFlag: {
                                    store.send(.toggleFlag(coordinate))
                                }
                            )
                        }
                        .padding(6)
                    }
                    .scrollIndicators(.hidden)

                    if let funnyOverlay = store.state.funnyBoomOverlay {
                        FunnyBoomOverlayBoardView(
                            dimensions: dimensions,
                            cellSide: cellSide,
                            overlay: funnyOverlay,
                            onTap: { coordinate in
                                store.send(.tapFunnyBoomCell(coordinate))
                            }
                        )
                    }

                    specialModeBoardPopup(compact: false)
                }
                .clipShape(.rect(cornerRadius: 10))
            }
            .padding(6)
            .retroBoardWell(cornerRadius: 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Text("\(dimensions.columns)x\(dimensions.rows)")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(RetroPalette.ink.opacity(0.78))
                Spacer()
                if let activePower = store.state.activePower {
                    Label("\(activePower.label) \(activePower.secondsRemaining)s", systemImage: "sparkles")
                        .font(.system(.footnote, design: .monospaced).weight(.semibold))
                        .foregroundStyle(RetroPalette.cobalt)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .retroInsetField(cornerRadius: 6)
                }
            }
        }
        .padding(12)
        .retroChromePanel(cornerRadius: 6)
    }

    private var statusText: String {
        switch store.state.phase {
        case .idle:
            "Tap any square to start. First tap is always safe."
        case .running:
            "Reveal mode opens cells. Flag mode marks bombs."
        case .won:
            "Board completed. Submit your nickname for the top 10."
        case .lost:
            "Boom. Start a new board when you are ready."
        }
    }

    private func boardModeToggle(compact: Bool) -> some View {
        HStack(spacing: 1) {
            modeButton(
                title: "Reveal",
                symbol: "hand.tap",
                isSelected: store.state.playerMode == .reveal,
                compact: compact
            ) {
                store.send(.setPlayerMode(.reveal))
            }

            modeButton(
                title: "Flag",
                symbol: "flag.fill",
                isSelected: store.state.playerMode == .flag,
                compact: compact
            ) {
                store.send(.setPlayerMode(.flag))
            }
        }
        .padding(2)
        .retroInsetField(cornerRadius: compact ? 7 : 6)
    }

    private func modeButton(
        title: String,
        symbol: String,
        isSelected: Bool,
        compact: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if !compact {
                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .bold))
                }
                Text(title)
                    .font(.system(size: compact ? 12 : 13, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(isSelected ? RetroPalette.ink : RetroPalette.cobalt)
            .padding(.horizontal, compact ? 10 : 12)
            .padding(.vertical, compact ? 5 : 6)
            .frame(minWidth: compact ? 68 : 84)
            .background(isSelected ? RetroPalette.fieldFill : .clear)
            .clipShape(.rect(cornerRadius: compact ? 6 : 5))
        }
        .buttonStyle(.plain)
    }

    private func controlButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .retroPixelFont(size: 14, weight: .black, color: RetroPalette.cobalt, tracking: 0.4)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .retroTabStyle()
        }
        .buttonStyle(.plain)
    }

    private func resetBoardButton(compact: Bool) -> some View {
        Button {
            store.restartGame()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: compact ? 10 : 11, weight: .bold))
                Text(compact ? "New" : "New Game")
                    .retroPixelFont(
                        size: compact ? 11 : 12,
                        weight: .black,
                        color: RetroPalette.cobalt,
                        tracking: 0.35
                    )
            }
            .padding(.horizontal, compact ? 8 : 9)
            .padding(.vertical, compact ? 5 : 6)
            .retroTabStyle()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New game")
        .accessibilityHint("Reset current board and start a new round")
    }

    private func fittedCellSize(for dimensions: BoardDimensions, in size: CGSize) -> CGFloat {
        let horizontalSpacing = CGFloat(max(0, dimensions.columns - 1))
        let verticalSpacing = CGFloat(max(0, dimensions.rows - 1))
        let contentInset: CGFloat = 12

        let usableWidth = max(0, size.width - contentInset)
        let usableHeight = max(0, size.height - contentInset)
        let fitWidth = (usableWidth - horizontalSpacing) / CGFloat(dimensions.columns)
        let fitHeight = (usableHeight - verticalSpacing) / CGFloat(dimensions.rows)
        let fitSide = floor(min(fitWidth, fitHeight))

        let preferredSide = preferredCellSize(for: dimensions)
        let minimumSide = minimumCellSize(for: dimensions)

        guard fitSide.isFinite, fitSide > 0 else {
            return minimumSide
        }

        return max(minimumSide, min(preferredSide, fitSide))
    }

    private func fixedBoardMetrics(
        for dimensions: BoardDimensions,
        in size: CGSize,
        verticalChrome: CGFloat = 62
    ) -> BoardMetrics {
        let horizontalSpacing = CGFloat(max(0, dimensions.columns - 1))
        let verticalSpacing = CGFloat(max(0, dimensions.rows - 1))
        let usableWidth = max(0, size.width - 12)
        let usableHeight = max(0, size.height - verticalChrome)

        let sideFromWidth = (usableWidth - horizontalSpacing) / CGFloat(dimensions.columns)
        let sideFromHeight = (usableHeight - verticalSpacing) / CGFloat(dimensions.rows)
        let cellSide = max(4, floor(min(sideFromWidth, sideFromHeight)))

        let boardWidth = (CGFloat(dimensions.columns) * cellSide) + horizontalSpacing
        let boardHeight = (CGFloat(dimensions.rows) * cellSide) + verticalSpacing

        return BoardMetrics(cellSide: cellSide, boardWidth: boardWidth, boardHeight: boardHeight)
    }

    private func preferredCellSize(for dimensions: BoardDimensions) -> CGFloat {
        if dimensions.columns >= 34 {
            return 18
        }
        if dimensions.columns >= 25 {
            return 21
        }
        if dimensions.columns >= 20 {
            return 24
        }
        return 28
    }

    private func minimumCellSize(for dimensions: BoardDimensions) -> CGFloat {
        if dimensions.columns >= 34 {
            return 14
        }
        if dimensions.columns >= 25 {
            return 16
        }
        return 18
    }

    private func scorePulse(at coordinate: BoardCoordinate) -> TileScorePulse? {
        store.state.tileScorePulses.first { $0.coordinate == coordinate }
    }

    @ViewBuilder
    private func specialModeBoardPopup(compact: Bool) -> some View {
        if let specialModeNotice = store.state.specialModeNotice {
            SpecialModeBoardPopupView(
                notice: specialModeNotice,
                compact: compact
            )
            .frame(maxWidth: compact ? 300 : 420)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, compact ? 14 : 24)
            .allowsHitTesting(false)
            .transition(.scale(scale: 0.92).combined(with: .opacity))
            .zIndex(4)
        }
    }
}

private struct BoardGridView<Cell: View>: View {
    let dimensions: BoardDimensions
    let cellSide: CGFloat
    let spacing: CGFloat
    let cell: (BoardCoordinate) -> Cell

    init(
        dimensions: BoardDimensions,
        cellSide: CGFloat,
        spacing: CGFloat = 1,
        @ViewBuilder cell: @escaping (BoardCoordinate) -> Cell
    ) {
        self.dimensions = dimensions
        self.cellSide = cellSide
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
                            .frame(width: cellSide, height: cellSide)
                            .contentShape(Rectangle())
                    }
                }
            }
        }
    }
}

private struct BoardMetrics {
    let cellSide: CGFloat
    let boardWidth: CGFloat
    let boardHeight: CGFloat
}

private struct CompactMetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(RetroPalette.cobalt)
            Text(value)
                .font(.system(size: 17, weight: .black, design: .monospaced))
                .foregroundStyle(RetroPalette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .retroInsetField(cornerRadius: 5)
    }
}

private struct ControlTag: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .retroPixelFont(size: 10, weight: .black, color: RetroPalette.cobalt.opacity(0.9), tracking: 0.4)
            Text(subtitle)
                .retroPixelFont(size: 14, weight: .bold, color: RetroPalette.ink, tracking: 0.4)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .retroTabStyle()
    }
}

private struct RetroLogoBadge: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(RetroPalette.logoBaseFill)

            Canvas { context, canvasSize in
                let center = CGPoint(
                    x: canvasSize.width * 0.82,
                    y: canvasSize.height * 0.17
                )
                let step = max(1.1, canvasSize.width * 0.048)
                let lineWidth = max(0.85, canvasSize.width * 0.014)
                let maxRadius = hypot(canvasSize.width, canvasSize.height) * 1.15

                var ringIndex = 0
                for radius in stride(from: canvasSize.width * 0.03, through: maxRadius, by: step) {
                    var ring = Path()
                    ring.addEllipse(
                        in: CGRect(
                            x: center.x - radius,
                            y: center.y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )
                    )
                    context.stroke(
                        ring,
                        with: .color(ringIndex.isMultiple(of: 2) ? RetroPalette.logoArcLight : RetroPalette.logoArcDark),
                        lineWidth: lineWidth
                    )
                    ringIndex += 1
                }
            }
            .clipShape(Circle())

            Text("B")
                .font(.system(size: size * 0.36, weight: .regular, design: .serif))
                .foregroundStyle(Color.white.opacity(0.98))
                .offset(x: -size * 0.19, y: -size * 0.17)

            Text("W")
                .font(.system(size: size * 0.36, weight: .regular, design: .serif))
                .foregroundStyle(Color.white.opacity(0.98))
                .offset(x: size * 0.17, y: size * 0.18)

            Circle()
                .fill(Color.white.opacity(0.95))
                .frame(width: size * 0.10, height: size * 0.10)
                .offset(x: -size * 0.24, y: size * 0.21)

            Circle()
                .stroke(RetroPalette.chromeEdgeDark, lineWidth: max(2.2, size * 0.09))

            Circle()
                .stroke(Color.white.opacity(0.85), lineWidth: max(1, size * 0.02))
                .padding(max(2, size * 0.05))
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.28), radius: 2.5, x: 0, y: 1)
    }
}

private struct RetroMetricField: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(RetroPalette.cobalt)
            Text(value)
                .font(.system(size: 30, weight: .black, design: .monospaced))
                .foregroundStyle(RetroPalette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .retroInsetField(cornerRadius: 4)
    }
}

private struct SpecialModeBoardPopupView: View {
    let notice: SpecialModeNotice
    let compact: Bool

    private var accent: Color {
        switch notice.style {
        case .xray:
            return .cyan
        case .superhero:
            return .orange
        case .funnyBoom:
            return .pink
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 7) {
            HStack(spacing: compact ? 8 : 10) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.22))
                    Circle()
                        .stroke(accent.opacity(0.7), lineWidth: 1.3)
                    Image(systemName: notice.symbol)
                        .font(.system(size: compact ? 14 : 16, weight: .black))
                        .foregroundStyle(accent)
                        .symbolEffect(.pulse, options: .speed(0.8), value: notice.secondsRemaining)
                }
                .frame(width: compact ? 30 : 36, height: compact ? 30 : 36)

                VStack(alignment: .leading, spacing: 1) {
                    Text("SPECIAL MODE")
                        .retroPixelFont(
                            size: compact ? 9 : 10,
                            weight: .black,
                            color: accent.opacity(0.95),
                            tracking: 0.5
                        )
                    Text(notice.title)
                        .retroPixelFont(
                            size: compact ? 13 : 15,
                            weight: .black,
                            color: RetroPalette.cobalt,
                            tracking: 0.55
                        )
                    Text(notice.subtitle)
                        .retroPixelFont(
                            size: compact ? 10 : 11,
                            weight: .bold,
                            color: RetroPalette.ink.opacity(0.78),
                            tracking: 0.25
                        )
                }

                Spacer(minLength: 6)

                Text("\(notice.secondsRemaining)s")
                    .retroPixelFont(
                        size: compact ? 18 : 20,
                        weight: .black,
                        color: accent,
                        tracking: 0.6
                    )
                    .frame(minWidth: compact ? 22 : 28, alignment: .trailing)
            }

            ProgressView(value: notice.progress)
                .progressViewStyle(.linear)
                .tint(accent)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, compact ? 10 : 13)
        .padding(.vertical, compact ? 8 : 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(RetroPalette.chromeGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(accent.opacity(0.72), lineWidth: 1.4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(RetroPalette.chromeEdgeLight.opacity(0.75), lineWidth: 1)
                .padding(1)
        )
        .shadow(color: accent.opacity(0.25), radius: 8, x: 0, y: 3)
    }
}

private struct CellButtonView: View {
    let coordinate: BoardCoordinate
    let state: GameState
    let scorePulse: TileScorePulse?
    let cellSide: CGFloat
    let onReveal: () -> Void
    let onFlag: () -> Void

    var body: some View {
        Button(action: onReveal) {
            CellFaceView(
                isRevealed: isRevealed,
                isFlagged: isFlagged,
                mineVisibleFromXray: mineVisibleFromXray,
                isMine: isMine,
                adjacentMines: adjacentMines,
                scorePulse: scorePulse,
                cellSide: cellSide
            )
        }
        .buttonStyle(.plain)
        .disabled(!state.canInteractWithBoard || state.funnyBoomOverlay != nil)
        .contextMenu {
            Button(isFlagged ? "Unflag" : "Flag") {
                onFlag()
            }
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double tap to reveal, or use the context menu to flag")
    }

    private var isMine: Bool {
        state.board?.isMine(coordinate) ?? false
    }

    private var adjacentMines: Int {
        state.board?.adjacentMineCount(at: coordinate) ?? 0
    }

    private var isRevealed: Bool {
        state.revealedTiles.contains(coordinate)
    }

    private var isFlagged: Bool {
        state.flaggedTiles.contains(coordinate)
    }

    private var mineVisibleFromXray: Bool {
        guard state.isXrayActive, !isRevealed, !isFlagged else { return false }
        return isMine
    }

    private var accessibilityLabel: String {
        if isFlagged {
            return "Flagged tile"
        }
        if !isRevealed {
            return "Hidden tile"
        }
        if isMine {
            return "Bomb"
        }
        if adjacentMines == 0 {
            return "Empty tile"
        }
        return "Tile with \(adjacentMines) neighboring bombs"
    }
}

private struct CellFaceView: View {
    let isRevealed: Bool
    let isFlagged: Bool
    let mineVisibleFromXray: Bool
    let isMine: Bool
    let adjacentMines: Int
    let scorePulse: TileScorePulse?
    let cellSide: CGFloat

    var body: some View {
        ZStack {
            Rectangle()
                .fill(backgroundColor)

            if isFlagged {
                Image(systemName: "flag.fill")
                    .font(.system(size: cellSide * 0.5, weight: .bold))
                    .foregroundStyle(.orange)
            } else if isRevealed {
                revealedContent
            } else if mineVisibleFromXray {
                Image(systemName: "burst.fill")
                    .font(.system(size: cellSide * 0.45, weight: .bold))
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse, options: .repeating)
                    .opacity(0.92)
            }

            if let scorePulse {
                scorePulseIndicator(for: scorePulse)
            }
        }
        .frame(width: cellSide, height: cellSide)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(topEdgeColor)
                .frame(height: 0.8)
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(topEdgeColor)
                .frame(width: 0.8)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(bottomEdgeColor)
                .frame(height: 0.8)
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(bottomEdgeColor)
                .frame(width: 0.8)
        }
        .overlay(
            Rectangle()
                .stroke(borderColor, lineWidth: 0.8)
        )
    }

    @ViewBuilder
    private var revealedContent: some View {
        if isMine {
            Image(systemName: "flame.fill")
                .font(.system(size: cellSide * 0.45, weight: .bold))
                .foregroundStyle(.red)
        } else if adjacentMines > 0 {
            Text("\(adjacentMines)")
                .font(.system(size: cellSide * 0.62, weight: .black, design: .rounded))
                .foregroundStyle(numberColor)
        }
    }

    private func scorePulseIndicator(for scorePulse: TileScorePulse) -> some View {
        let isBonus = scorePulse.pointsDelta >= 0
        let highlight = isBonus ? Color.green : Color.red

        return Text(scorePulse.label)
            .font(.system(size: max(8, cellSide * 0.42), weight: .black, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: cellSide * 0.86)
            .foregroundStyle(highlight)
            .shadow(color: .black.opacity(0.28), radius: 1, x: 0, y: 1)
            .scaleEffect(scorePulse.secondsRemaining == ScoreRules.tileScorePulseDuration ? 1.08 : 1)
            .opacity(scorePulse.secondsRemaining == 1 ? 0.58 : 0.98)
            .allowsHitTesting(false)
            .transition(.scale.combined(with: .opacity))
    }

    private var backgroundColor: Color {
        if isRevealed {
            return RetroPalette.revealedTile
        }
        return RetroPalette.hiddenTile
    }

    private var borderColor: Color {
        RetroPalette.hiddenTileEdge
    }

    private var topEdgeColor: Color {
        isRevealed ? RetroPalette.revealedTileEdgeLight : RetroPalette.hiddenTileEdgeLight
    }

    private var bottomEdgeColor: Color {
        isRevealed ? RetroPalette.revealedTileEdgeDark : RetroPalette.hiddenTileEdgeDark
    }

    private var numberColor: Color {
        switch adjacentMines {
        case 1: Color(red: 0.10, green: 0.20, blue: 0.78)
        case 2: Color(red: 0.06, green: 0.50, blue: 0.17)
        case 3: Color(red: 0.76, green: 0.08, blue: 0.08)
        case 4: Color(red: 0.14, green: 0.16, blue: 0.50)
        case 5: Color(red: 0.48, green: 0.10, blue: 0.09)
        case 6: Color(red: 0.06, green: 0.45, blue: 0.50)
        case 7: .black
        default: Color(red: 0.36, green: 0.36, blue: 0.39)
    }
}
}

private struct FunnyBoomOverlayBoardView: View {
    let dimensions: BoardDimensions
    let cellSide: CGFloat
    let overlay: FunnyBoomOverlay
    let onTap: (BoardCoordinate) -> Void
    let allowsScrolling: Bool
    let compactStyle: Bool

    init(
        dimensions: BoardDimensions,
        cellSide: CGFloat,
        overlay: FunnyBoomOverlay,
        onTap: @escaping (BoardCoordinate) -> Void,
        allowsScrolling: Bool = true,
        compactStyle: Bool = false
    ) {
        self.dimensions = dimensions
        self.cellSide = cellSide
        self.overlay = overlay
        self.onTap = onTap
        self.allowsScrolling = allowsScrolling
        self.compactStyle = compactStyle
    }

    var body: some View {
        ZStack {
            RetroPalette.boardWellDark.opacity(0.86)
                .clipShape(.rect(cornerRadius: 8))

            VStack(spacing: compactStyle ? 4 : 8) {
                HStack {
                    Label(compactStyle ? "Funny Boom \(overlay.secondsRemaining)s" : "Funny Boom: \(overlay.secondsRemaining)s", systemImage: "theatermasks.fill")
                        .font(.system(compactStyle ? .caption : .callout, design: .monospaced).weight(.bold))
                        .foregroundStyle(RetroPalette.cobalt)
                        .padding(.horizontal, compactStyle ? 8 : 10)
                        .padding(.vertical, compactStyle ? 5 : 7)
                        .retroInsetField(cornerRadius: 6)
                    Spacer()
                }
                .padding(.horizontal, compactStyle ? 2 : 0)

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
            }
            .padding(compactStyle ? 6 : 10)
        }
        .padding(compactStyle ? 2 : 6)
        .retroChromePanel(cornerRadius: 8)
        .transition(.opacity.combined(with: .scale))
    }

    @ViewBuilder
    private func boardGrid() -> some View {
        BoardGridView(dimensions: dimensions, cellSide: cellSide) { coordinate in
            Button {
                onTap(coordinate)
            } label: {
                ZStack {
                    Rectangle()
                        .fill(RetroPalette.hiddenTile)

                    if overlay.revealedClowns.contains(coordinate) {
                        Text("🤡")
                            .font(.system(size: cellSide * 0.62))
                    }
                }
                .frame(width: cellSide, height: cellSide)
                .overlay(
                    Rectangle()
                        .stroke(RetroPalette.hiddenTileEdge, lineWidth: 0.8)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

private struct RetroBackgroundView: View {
    var body: some View {
        GeometryReader { proxy in
            let topChromeHeight = min(max(72, proxy.size.height * 0.12), 128)

            ZStack(alignment: .top) {
                RetroPalette.windowBackground

                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: topChromeHeight)

                    ZStack {
                        RetroPalette.boardAreaGradient

                        Canvas { context, size in
                            let pixel = max(2.8, min(4.2, size.width / 130)) / 4.0
                            let glowRadius = max(0.14, pixel * 0.72)
                            let fGlyph = RetroBackgroundView.glyphPath(from: RetroBackgroundView.fBitmap, pixel: pixel)
                            let bGlyph = RetroBackgroundView.glyphPath(from: RetroBackgroundView.bBitmap, pixel: pixel)
                            let bOffset = CGPoint(x: pixel * 4.0, y: pixel * 3.0)
                            let stepX = pixel * 16.5
                            let stepY = pixel * 13.5

                            var rowIndex = 0
                            for y in stride(from: -stepY, through: size.height + stepY, by: stepY) {
                                var columnIndex = 0
                                let rowOffset = rowIndex.isMultiple(of: 2) ? pixel * 1.2 : pixel * 3.7

                                for x in stride(from: -stepX, through: size.width + stepX, by: stepX) {
                                    let motifOrigin = CGPoint(
                                        x: x + rowOffset + CGFloat((rowIndex + columnIndex) % 2) * (pixel * 0.55),
                                        y: y + pixel * 0.9
                                    )
                                    drawGlyph(
                                        fGlyph,
                                        at: motifOrigin,
                                        in: &context,
                                        glowRadius: glowRadius
                                    )

                                    let bOrigin = CGPoint(
                                        x: motifOrigin.x + bOffset.x + (columnIndex.isMultiple(of: 2) ? pixel * 0.28 : -pixel * 0.18),
                                        y: motifOrigin.y + bOffset.y + (rowIndex.isMultiple(of: 2) ? pixel * 0.42 : -pixel * 0.12)
                                    )
                                    drawGlyph(
                                        bGlyph,
                                        at: bOrigin,
                                        in: &context,
                                        glowRadius: glowRadius
                                    )
                                    columnIndex += 1
                                }
                                rowIndex += 1
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .ignoresSafeArea()
    }

    private static let fBitmap: [String] = [
        "111111",
        "110000",
        "110000",
        "111110",
        "110000",
        "110000",
        "110000",
        "110000"
    ]

    private static let bBitmap: [String] = [
        "111110",
        "110011",
        "110011",
        "111110",
        "110011",
        "110011",
        "110011",
        "111110"
    ]

    private static func glyphPath(from bitmap: [String], pixel: CGFloat) -> Path {
        var path = Path()
        for (row, line) in bitmap.enumerated() {
            for (column, character) in line.enumerated() where character == "1" {
                path.addRect(
                    CGRect(
                        x: CGFloat(column) * pixel,
                        y: CGFloat(row) * pixel,
                        width: pixel,
                        height: pixel
                    )
                )
            }
        }
        return path
    }

    private func drawGlyph(
        _ glyph: Path,
        at origin: CGPoint,
        in context: inout GraphicsContext,
        glowRadius: CGFloat
    ) {
        let translated = glyph.applying(CGAffineTransform(translationX: origin.x, y: origin.y))

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: glowRadius))
            layer.fill(translated, with: .color(RetroPalette.boardPatternGlow))
        }

        context.fill(translated, with: .color(RetroPalette.boardPattern))
    }
}

private struct PhoneMenuSheetView: View {
    let settings: GameSettings
    let boardSizes: [BoardSizePreset]
    let soundEnabled: Bool
    let onShowRules: () -> Void
    let onSetDifficulty: (GameDifficulty) -> Void
    let onSetBoardSize: (BoardSizePreset) -> Void
    let onShowScores: () -> Void
    let onToggleSound: () -> Void
    let onNewGame: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Game") {
                    Button("Rules") {
                        dismiss()
                        onShowRules()
                    }

                    Button("Scores") {
                        dismiss()
                        onShowScores()
                    }

                    Button("New Game") {
                        dismiss()
                        onNewGame()
                    }

                    Button(soundEnabled ? "Sound: On" : "Sound: Off") {
                        onToggleSound()
                    }
                }

                Section("Difficulty") {
                    ForEach(GameDifficulty.allCases) { difficulty in
                        Button {
                            onSetDifficulty(difficulty)
                        } label: {
                            if settings.difficulty == difficulty {
                                Label(difficulty.title, systemImage: "checkmark")
                            } else {
                                Text(difficulty.title)
                            }
                        }
                    }
                }

                Section("Board Size") {
                    ForEach(boardSizes) { boardSize in
                        Button {
                            onSetBoardSize(boardSize)
                        } label: {
                            if settings.boardSize == boardSize {
                                Label(boardSize.title, systemImage: "checkmark")
                            } else {
                                Text(boardSize.title)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Game Menu")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct RulesSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Classic rules") {
                    Text("Reveal any safe tile. A revealed number tells how many bombs touch that tile in the 8 surrounding positions.")
                    Text("Tap a bomb and you lose. Reveal every non-bomb tile to win.")
                    Text("When a revealed tile is empty, neighboring empty areas expand automatically.")
                }

                Section("Special squares") {
                    Text("Some empty tiles can trigger +10 points, -10 points, X-Ray vision, Superhero mode, or Funny Boom mode.")
                    Text("X-Ray reveals hidden bombs with a pulse for a short time.")
                    Text("Superhero mode lets you reveal bombs without losing while it is active.")
                    Text("Funny Boom shows a temporary clown board for 5 seconds. Each clown gives +10 points.")
                }

                Section("Controls") {
                    Text("Use Reveal mode to open tiles. Use Flag mode to mark bomb candidates.")
                    Text("On iPad and macOS you can also use the context menu on a tile to flag or unflag.")
                }
            }
            .navigationTitle("Rules")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct ScoresSheetView: View {
    let scores: [ScoreEntry]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if scores.isEmpty {
                    ContentUnavailableView(
                        "No Scores Yet",
                        systemImage: "trophy",
                        description: Text("Win a board and submit your nickname to build the top 10.")
                    )
                } else {
                    List {
                        ForEach(Array(scores.enumerated()), id: \.element.id) { index, score in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("#\(index + 1)")
                                        .font(.system(.headline, design: .rounded).weight(.bold))
                                        .foregroundStyle(.cyan)
                                    Text(score.nickname)
                                        .font(.system(.headline, design: .rounded).weight(.bold))
                                    Spacer()
                                    Text("\(score.totalScore)")
                                        .font(.system(.title3, design: .monospaced).weight(.black))
                                }

                                Text("Points: \(score.points) • Time: \(score.elapsedSeconds)s")
                                    .font(.system(.subheadline, design: .monospaced))
                                    .foregroundStyle(.secondary)

                                Text("\(score.difficulty.title) • \(score.boardSize.title)")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
            }
            .navigationTitle("Top 10")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct VictorySheetView: View {
    let victory: PendingVictory
    let onSubmit: (String) -> Void
    let onNewGame: () -> Void
    let onDismiss: () -> Void

    @State private var nickname: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Board Cleared")
                    .font(.system(.largeTitle, design: .rounded).weight(.black))

                Text("Score \(victory.totalScore) • Points \(victory.points) • Time \(victory.elapsedSeconds)s")
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField("Nickname", text: $nickname)
                    .nicknameCapitalization()
                    .textFieldStyle(.roundedBorder)

                Button {
                    onSubmit(nickname)
                    dismiss()
                } label: {
                    Label("Save to Top 10", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button {
                    onNewGame()
                    dismiss()
                } label: {
                    Label("New Game Now", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button("Later") {
                    onDismiss()
                    dismiss()
                }
                .frame(maxWidth: .infinity)
            }
            .padding(20)
            .navigationTitle("Victory")
            .platformInlineNavigationTitle()
        }
    }
}

private enum RetroPalette {
    static let windowBackground = LinearGradient(
        colors: [
            Color(red: 0.70, green: 0.71, blue: 0.74),
            Color(red: 0.63, green: 0.64, blue: 0.67)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let chromeGradient = LinearGradient(
        colors: [
            Color(red: 0.84, green: 0.84, blue: 0.86),
            Color(red: 0.72, green: 0.72, blue: 0.74),
            Color(red: 0.62, green: 0.63, blue: 0.66)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let boardAreaGradient = LinearGradient(
        colors: [
            Color(red: 0.02, green: 0.03, blue: 0.23),
            Color(red: 0.03, green: 0.04, blue: 0.29),
            Color(red: 0.01, green: 0.03, blue: 0.21)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let boardPatternGlow = Color(red: 0.28, green: 0.35, blue: 1.0).opacity(0.72)
    static let boardPattern = Color(red: 0.42, green: 0.47, blue: 1.0).opacity(0.9)
    static let logoBaseFill = LinearGradient(
        colors: [
            Color(red: 0.15, green: 0.32, blue: 0.82),
            Color(red: 0.07, green: 0.17, blue: 0.61)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let logoArcLight = Color(red: 0.39, green: 0.61, blue: 1.0).opacity(0.92)
    static let logoArcDark = Color(red: 0.16, green: 0.31, blue: 0.86).opacity(0.86)
    static let boardWell = Color(red: 0.87, green: 0.88, blue: 0.90)
    static let boardWellDark = Color(red: 0.58, green: 0.60, blue: 0.64)

    static let fieldFill = Color(red: 0.80, green: 0.81, blue: 0.84)
    static let insetFill = Color(red: 0.75, green: 0.76, blue: 0.79)

    static let hiddenTile = Color(red: 0.37, green: 0.40, blue: 0.50)
    static let hiddenTileEdge = Color(red: 0.20, green: 0.22, blue: 0.30)
    static let hiddenTileEdgeLight = Color(red: 0.57, green: 0.60, blue: 0.70)
    static let hiddenTileEdgeDark = Color(red: 0.16, green: 0.17, blue: 0.24)

    static let revealedTile = Color(red: 0.79, green: 0.80, blue: 0.83)
    static let revealedTileEdgeLight = Color(red: 0.91, green: 0.92, blue: 0.95)
    static let revealedTileEdgeDark = Color(red: 0.58, green: 0.59, blue: 0.63)

    static let chromeEdgeLight = Color.white
    static let chromeEdgeDark = Color(red: 0.23, green: 0.23, blue: 0.26)
    static let cobalt = Color(red: 0.06, green: 0.16, blue: 0.72)
    static let ink = Color.black.opacity(0.88)
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

private extension View {
    func retroPixelFont(
        size: CGFloat,
        weight: Font.Weight = .bold,
        color: Color = RetroPalette.ink,
        tracking: CGFloat = 0.4
    ) -> some View {
        font(.system(size: size, weight: weight, design: .monospaced))
            .foregroundStyle(color)
            .tracking(tracking)
            .shadow(color: color.opacity(0.22), radius: 0, x: 0.6, y: 0.6)
    }

    func retroChromePanel(cornerRadius: CGFloat) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(RetroPalette.chromeGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(RetroPalette.chromeEdgeDark, lineWidth: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius - 1)
                .stroke(RetroPalette.chromeEdgeLight.opacity(0.85), lineWidth: 1)
                .padding(1)
        )
    }

    func retroInsetField(cornerRadius: CGFloat) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(RetroPalette.insetFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(RetroPalette.chromeEdgeDark.opacity(0.75), lineWidth: 1.2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(RetroPalette.chromeEdgeLight.opacity(0.70), lineWidth: 1)
                .padding(1)
        )
    }

    func retroBoardWell(cornerRadius: CGFloat) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(RetroPalette.boardWell)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(RetroPalette.chromeEdgeDark, lineWidth: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius - 1)
                .stroke(RetroPalette.chromeEdgeLight.opacity(0.9), lineWidth: 1)
                .padding(1)
        )
    }

    func retroTabStyle(selected: Bool = false) -> some View {
        foregroundStyle(selected ? RetroPalette.ink : RetroPalette.cobalt)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        selected
                            ? AnyShapeStyle(RetroPalette.fieldFill)
                            : AnyShapeStyle(RetroPalette.chromeGradient)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(RetroPalette.chromeEdgeDark.opacity(0.8), lineWidth: 1.2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(RetroPalette.chromeEdgeLight.opacity(0.75), lineWidth: 1)
                    .padding(1)
            )
    }

    @ViewBuilder
    func nicknameCapitalization() -> some View {
#if os(iOS) || os(visionOS)
        textInputAutocapitalization(.words)
#else
        self
#endif
    }

    @ViewBuilder
    func platformInlineNavigationTitle() -> some View {
#if os(iOS) || os(visionOS)
        navigationBarTitleDisplayMode(.inline)
#else
        self
#endif
    }

    @ViewBuilder
    func hidePhoneNavigationBar(_ hidden: Bool) -> some View {
#if os(iOS)
        if hidden {
            toolbar(.hidden, for: .navigationBar)
        } else {
            self
        }
#else
        self
#endif
    }
}
