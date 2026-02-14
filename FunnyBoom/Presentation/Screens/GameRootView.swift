import SwiftUI

struct GameRootView: View {
    @State private var viewModel: GameViewFacade
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var activeOverlay: ActiveOverlay?
    @State private var highlightedScoreID: UUID?
    @State private var activeControlPopup: ControlBarPopup?
    @State private var popupAnchorFrames: [ControlBarPopup: CGRect] = [:]

    private static let controlPopupCoordinateSpace = "controlPopupCoordinateSpace"

    init() {
        let settings = GameRootView.makeInitialSettings()
        _viewModel = State(
            wrappedValue: GameViewFacade(
                store: GameStore(
                    state: GameState(settings: settings)
                )
            )
        )
    }

    var body: some View {
        let modePreparationNotice = viewModel.state.specialModeNotice?.isActivationCountdown == true
            ? viewModel.state.specialModeNotice
            : nil
        let isFocusOverlayPresented = viewModel.state.funnyBoomOverlay != nil || modePreparationNotice != nil
        let shouldShowControlPopup = isPadLayout && activeOverlay == nil && !isFocusOverlayPresented

        ZStack {
            Group {
                RetroBackgroundView()

                GeometryReader { proxy in
                    let regularMaxWidth = max(0, proxy.size.width - (isPadLayout ? 56 : 40))
                    let regularMaxHeight = max(0, proxy.size.height - (isPadLayout ? 20 : 36))
                    let regularContainerHeight = isPadLayout
                        ? min(max(760, proxy.size.height * 0.92), regularMaxHeight)
                        : min(max(660, proxy.size.height * 0.86), regularMaxHeight)
                    let regularContainerWidth = isPadLayout
                        ? min(max(980, regularContainerHeight * 1.28), regularMaxWidth)
                        : min(max(780, proxy.size.width * 0.88), regularMaxWidth)
                    let regularVerticalCenterOffset = isPadLayout
                        ? 0
                        : (proxy.safeAreaInsets.bottom - proxy.safeAreaInsets.top) / 2

                    Group {
                        if isPhoneLayout {
                            phoneLayout(in: proxy.size)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                        } else {
                            regularLayout
                                .padding(isPadLayout ? 10 : 14)
                        }
                    }
                    .frame(
                        width: isPhoneLayout ? nil : regularContainerWidth,
                        height: isPhoneLayout ? nil : regularContainerHeight,
                        alignment: isPhoneLayout ? .top : .center
                    )
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isPhoneLayout ? .top : .center)
                    .offset(y: isPhoneLayout ? 0 : regularVerticalCenterOffset)
                    .padding(isPhoneLayout ? 2 : 0)
                }

                if viewModel.state.phase == .lost {
                    ExplosionOverlayView(
                        trigger: viewModel.state.explosionSequence,
                        showActions: viewModel.isLossCardVisible,
                        onNewGame: {
                            viewModel.restartGame()
                        }
                    )
                    .transition(.opacity)
                }
            }
            .blur(radius: isFocusOverlayPresented ? (isPhoneLayout ? 7 : 8) : 0)
            .saturation(isFocusOverlayPresented ? 0.86 : 1)
            .allowsHitTesting(!isFocusOverlayPresented)

            if let funnyOverlay = viewModel.state.funnyBoomOverlay {
                FunnyBoomFocusOverlayView(
                    dimensions: viewModel.state.dimensions,
                    overlay: funnyOverlay,
                    isPhoneLayout: isPhoneLayout,
                    onTap: { coordinate in
                        viewModel.tapFunnyBoomCell(coordinate)
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
                .zIndex(11)
            }

            if let modePreparationNotice {
                SpecialModeCountdownFocusOverlayView(
                    notice: modePreparationNotice,
                    isPhoneLayout: isPhoneLayout,
                    onSkip: {
                        viewModel.skipSpecialModeCountdown()
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .zIndex(11)
            }

            if shouldShowControlPopup,
               let activeControlPopup,
               let popupFrame = popupAnchorFrames[activeControlPopup],
               !popupFrame.isEmpty {
                RetroControlPopupBackdrop(onDismiss: dismissControlPopup) {
                    controlPopupContent(for: activeControlPopup)
                        .frame(width: popupWidth(for: activeControlPopup))
                        .offset(x: popupFrame.minX, y: popupFrame.maxY + 8)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topLeading)))
                }
                .zIndex(10)
            }

            if let activeOverlay {
                RetroOverlayBackdrop(
                    onDismiss: dismissOverlay,
                    isPhoneLayout: isPhoneLayout
                ) {
                    overlayContent(for: activeOverlay)
                }
                .zIndex(12)
            }
        }
        .coordinateSpace(name: Self.controlPopupCoordinateSpace)
        .hidePlatformStatusBar(false)
        .animation(.spring(response: 0.30, dampingFraction: 0.88), value: activeOverlay)
        .animation(.spring(response: 0.24, dampingFraction: 0.90), value: activeControlPopup)
        .iOSPreferredColorScheme(.dark)
        .onPreferenceChange(ControlPopupFramePreferenceKey.self) { frames in
            popupAnchorFrames = frames
        }
        .onChange(of: viewModel.state.pendingVictory) { _, pendingVictory in
            guard let pendingVictory else {
                if case .victory = activeOverlay {
                    dismissOverlay()
                }
                return
            }
            presentOverlay(.victory(pendingVictory))
        }
        .onChange(of: activeOverlay) { _, overlay in
            if overlay != nil {
                dismissControlPopup()
            }
        }
        .onChange(of: shouldShowControlPopup) { _, shouldShow in
            if !shouldShow {
                dismissControlPopup()
            }
        }
#if os(macOS)
        .frame(minWidth: 1_020, minHeight: 730)
#endif
    }

    private var isPhoneLayout: Bool {
#if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone && horizontalSizeClass == .compact
#else
        false
#endif
    }

    private var isPadLayout: Bool {
#if os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad
#else
        false
#endif
    }

    private var regularLayout: some View {
        VStack(spacing: isPadLayout ? 8 : 10) {
            header
            controlsBar

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: isPadLayout ? 12 : 14) {
                    statsPanel
                        .frame(width: isPadLayout ? 220 : 250)
                    boardPanel
                }

                VStack(spacing: isPadLayout ? 12 : 14) {
                    statsPanel
                    boardPanel
                }
            }
        }
    }

    private var availableBoardSizes: [BoardSizePreset] {
        isPhoneLayout ? BoardSizePreset.phonePortraitPresets : BoardSizePreset.regularPresets
    }

    private static func makeInitialSettings() -> GameSettings {
#if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            return GameSettings(difficulty: .amateur, boardSize: .phone12x18)
        }
        return GameSettings(difficulty: .amateur, boardSize: .rectangular20x15)
#else
        return .default
#endif
    }

    private func presentOverlay(_ overlay: ActiveOverlay) {
        withAnimation(.spring(response: 0.30, dampingFraction: 0.88)) {
            activeOverlay = overlay
        }
    }

    private func dismissOverlay() {
        let closingOverlay = activeOverlay
        withAnimation(.spring(response: 0.30, dampingFraction: 0.90)) {
            activeOverlay = nil
        }

        if case .victory = closingOverlay {
            viewModel.clearVictoryPrompt()
        }
    }

    @ViewBuilder
    private func overlayContent(for overlay: ActiveOverlay) -> some View {
        switch overlay {
        case .menu:
            PhoneMenuSheetView(
                settings: viewModel.state.settings,
                boardSizes: availableBoardSizes,
                onShowRules: {
                    presentOverlay(.rules)
                },
                onSetDifficulty: { difficulty in
                    viewModel.setDifficulty(difficulty)
                },
                onSetBoardSize: { boardSize in
                    viewModel.setBoardSize(boardSize)
                },
                onShowScores: {
                    highlightedScoreID = nil
                    presentOverlay(.scores)
                },
                onClose: {
                    dismissOverlay()
                }
            )

        case .rules:
            RulesSheetView(onClose: dismissOverlay)

        case .scores:
            ScoresSheetView(
                scores: viewModel.state.scores,
                highlightedScoreID: highlightedScoreID,
                onClose: dismissOverlay
            )

        case let .victory(victory):
            VictorySheetView(
                victory: victory,
                onSubmit: { nickname in
                    highlightedScoreID = viewModel.submitVictory(nickname: nickname)
                    presentOverlay(.scores)
                },
                onNewGame: {
                    viewModel.restartGame()
                    dismissOverlay()
                },
                onDismiss: dismissOverlay
            )
        }
    }

    private func phoneLayout(in _: CGSize) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Funny Boum")
                        .retroPixelFont(size: 24, weight: .black, color: RetroPalette.ink, tracking: 0.7)
                    Text("\(viewModel.state.settings.difficulty.title) • \(viewModel.state.settings.boardSize.title)")
                        .retroPixelFont(size: 11, weight: .bold, color: RetroPalette.cobalt.opacity(0.9), tracking: 0.4)
                }

                RetroLogoBadge(size: 38)

                Spacer()

                Button {
                    presentOverlay(.menu)
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
            CompactMetricPill(
                title: String(localized: "hud.score", defaultValue: "Score"),
                value: "\(viewModel.state.points)"
            )
            CompactMetricPill(
                title: String(localized: "hud.time", defaultValue: "Time"),
                value: "\(viewModel.state.elapsedSeconds)s"
            )
            CompactMetricPill(
                title: String(localized: "hud.bombs", defaultValue: "Bombs"),
                value: "\(viewModel.state.remainingBombs)"
            )
            CompactMetricPill(
                title: String(localized: "hud.bonus", defaultValue: "Bonus"),
                value: "\(viewModel.state.bonusPoints)"
            )
        }
        .padding(8)
        .retroChromePanel(cornerRadius: 8)
    }

    private func phoneBoardPanel(in size: CGSize) -> some View {
        let boardViewState = viewModel.boardViewState
        let dimensions = boardViewState.dimensions
        let funnyOverlay = boardViewState.funnyBoomOverlay
        let overlayHeightAllowance: CGFloat = funnyOverlay == nil ? 0 : 60
        let metrics = fixedBoardMetrics(
            for: dimensions,
            in: size,
            verticalChrome: 96 + overlayHeightAllowance
        )

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 8) {
                    Text("Board")
                        .font(.system(.headline, design: .monospaced).weight(.bold))
                        .foregroundStyle(RetroPalette.cobalt)
                    resetBoardButton(compact: true)
                }
                Spacer()
                boardControlHint(compact: true)
            }

            ZStack {
                BoardGridView(dimensions: dimensions, cellSize: metrics.cellSize) { coordinate in
                    CellButtonView(
                        state: boardViewState.cellState(for: coordinate),
                        scorePulse: boardViewState.scorePulse(at: coordinate),
                        cellSize: metrics.cellSize,
                        onReveal: {
                            viewModel.tapCell(coordinate)
                        },
                        onFlag: {
                            viewModel.toggleFlag(coordinate)
                        }
                    )
                }

                if let funnyOverlay {
                    FunnyBoomOverlayBoardView(
                        dimensions: dimensions,
                        cellSize: metrics.cellSize,
                        overlay: funnyOverlay,
                        onTap: { coordinate in
                            viewModel.tapFunnyBoomCell(coordinate)
                        },
                        allowsScrolling: false,
                        compactStyle: true
                    )
                }
            }
            .frame(width: metrics.boardWidth, height: metrics.boardHeight + overlayHeightAllowance)
            .clipShape(.rect(cornerRadius: 10))
            .frame(maxWidth: .infinity)
            .retroBoardWell(cornerRadius: 12)

            HStack {
                Text("\(dimensions.columns)x\(dimensions.rows)")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(RetroPalette.ink.opacity(0.74))
                Spacer()
                activePowerStatusPill(compact: true)
            }
        }
        .padding(8)
        .retroChromePanel(cornerRadius: 8)
    }

    private var header: some View {
        let titleSize: CGFloat = isPadLayout ? 38 : 45
        let subtitleSize: CGFloat = isPadLayout ? 12 : 14
        let editionSize: CGFloat = isPadLayout ? 24 : 28
        let generationSize: CGFloat = isPadLayout ? 11 : 12
        let logoSize: CGFloat = isPadLayout ? 86 : 104
        let logoTopCut: CGFloat = isPadLayout ? logoSize * 0.07 : 0

        return HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Funny BOUM")
                    .retroPixelFont(size: titleSize, weight: .black, color: RetroPalette.ink, tracking: 0.6)

                Text("Version # 1.0   (c) B/W,1995.")
                    .retroPixelFont(size: subtitleSize, weight: .black, color: RetroPalette.ink.opacity(0.9), tracking: 0.5)
            }

            RetroLogoBadge(size: logoSize, topCut: logoTopCut)
                .padding(.top, -8)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 2) {
                Text("2026 Edition")
                    .retroPixelFont(size: editionSize, weight: .black, color: RetroPalette.ink, tracking: 0.7)
                Text("Retro-modern generation")
                    .retroPixelFont(size: generationSize, weight: .bold, color: RetroPalette.cobalt.opacity(0.9), tracking: 0.3)
            }
        }
        .padding(.horizontal, isPadLayout ? 14 : 16)
        .padding(.vertical, isPadLayout ? 8 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .retroChromePanel(cornerRadius: 6)
    }

    private var controlsBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: isPadLayout ? 6 : 8) {
                controlButton(title: String(localized: "menu.rules", defaultValue: "Rules")) {
                    presentOverlay(.rules)
                }

                if isPadLayout {
                    Button {
                        toggleControlPopup(.difficulty)
                    } label: {
                        ControlTag(
                            title: String(localized: "menu.difficulty", defaultValue: "Difficulty"),
                            subtitle: viewModel.state.settings.difficulty.title,
                            showsDisclosure: true,
                            isExpanded: activeControlPopup == .difficulty
                        )
                    }
                    .buttonStyle(.plain)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: ControlPopupFramePreferenceKey.self,
                                value: [.difficulty: proxy.frame(in: .named(Self.controlPopupCoordinateSpace))]
                            )
                        }
                    )
                } else {
                    Menu {
                        ForEach(GameDifficulty.allCases) { difficulty in
                            Button {
                                viewModel.setDifficulty(difficulty)
                            } label: {
                                if difficulty == viewModel.state.settings.difficulty {
                                    Label(difficulty.title, systemImage: "checkmark")
                                } else {
                                    Text(difficulty.title)
                                }
                            }
                        }
                    } label: {
                        ControlTag(
                            title: String(localized: "menu.difficulty", defaultValue: "Difficulty"),
                            subtitle: viewModel.state.settings.difficulty.title
                        )
                    }
                }

                if isPadLayout {
                    Button {
                        toggleControlPopup(.boardSize)
                    } label: {
                        ControlTag(
                            title: String(localized: "menu.board", defaultValue: "Board"),
                            subtitle: viewModel.state.settings.boardSize.title,
                            showsDisclosure: true,
                            isExpanded: activeControlPopup == .boardSize
                        )
                    }
                    .buttonStyle(.plain)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: ControlPopupFramePreferenceKey.self,
                                value: [.boardSize: proxy.frame(in: .named(Self.controlPopupCoordinateSpace))]
                            )
                        }
                    )
                } else {
                    Menu {
                        ForEach(availableBoardSizes) { boardSize in
                            Button {
                                viewModel.setBoardSize(boardSize)
                            } label: {
                                if boardSize == viewModel.state.settings.boardSize {
                                    Label(boardSize.title, systemImage: "checkmark")
                                } else {
                                    Text(boardSize.title)
                                }
                            }
                        }
                    } label: {
                        ControlTag(
                            title: String(localized: "menu.board", defaultValue: "Board"),
                            subtitle: viewModel.state.settings.boardSize.title
                        )
                    }
                }

                controlButton(title: String(localized: "menu.scores", defaultValue: "Scores")) {
                    highlightedScoreID = nil
                    presentOverlay(.scores)
                }
            }
            .padding(.vertical, isPadLayout ? 2 : 4)
        }
        .scrollIndicators(.hidden)
        .padding(.leading, isPadLayout ? 6 : 8)
        .padding(.trailing, 2)
        .padding(.vertical, isPadLayout ? 2 : 3)
        .retroChromePanel(cornerRadius: 6)
    }

    @ViewBuilder
    private func controlPopupContent(for popup: ControlBarPopup) -> some View {
        switch popup {
        case .difficulty:
            controlPopupPanel(title: String(localized: "menu.difficulty", defaultValue: "Difficulty")) {
                ForEach(GameDifficulty.allCases) { difficulty in
                    controlPopupOptionButton(
                        title: difficulty.title,
                        subtitle: String(
                            localized: "menu.mine_density",
                            defaultValue: "Mine density \(Int((difficulty.mineDensity * 100).rounded()))%"
                        ),
                        isSelected: viewModel.state.settings.difficulty == difficulty
                    ) {
                        viewModel.setDifficulty(difficulty)
                        dismissControlPopup()
                    }
                }
            }

        case .boardSize:
            controlPopupPanel(title: String(localized: "menu.board_size", defaultValue: "Board Size")) {
                ForEach(availableBoardSizes) { boardSize in
                    controlPopupOptionButton(
                        title: boardSize.title,
                        subtitle: "\(boardSize.dimensions.columns)x\(boardSize.dimensions.rows)",
                        isSelected: viewModel.state.settings.boardSize == boardSize
                    ) {
                        viewModel.setBoardSize(boardSize)
                        dismissControlPopup()
                    }
                }
            }
        }
    }

    private func popupWidth(for popup: ControlBarPopup) -> CGFloat {
        switch popup {
        case .difficulty:
            252
        case .boardSize:
            236
        }
    }

    private func toggleControlPopup(_ popup: ControlBarPopup) {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.90)) {
            activeControlPopup = activeControlPopup == popup ? nil : popup
        }
    }

    private func dismissControlPopup() {
        activeControlPopup = nil
    }

    private func controlPopupPanel<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .retroPixelFont(size: 12, weight: .black, color: RetroPalette.cobalt, tracking: 0.45)
                .padding(.horizontal, 6)

            VStack(spacing: 8) {
                content()
            }
        }
        .padding(8)
        .retroChromePanel(cornerRadius: 10)
        .shadow(color: .black.opacity(0.30), radius: 14, x: 0, y: 6)
    }

    private func controlPopupOptionButton(
        title: String,
        subtitle: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .retroPixelFont(
                            size: 13,
                            weight: .black,
                            color: isSelected ? RetroPalette.ink : RetroPalette.cobalt,
                            tracking: 0.35
                        )
                    Text(subtitle)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink.opacity(0.72))
                }

                Spacer(minLength: 6)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .retroTabStyle(selected: isSelected)
        }
        .buttonStyle(.plain)
    }

    private var statsPanel: some View {
        VStack(alignment: .leading, spacing: isPadLayout ? 8 : 10) {
            Text("Match")
                .font(.system(.title3, design: .serif).weight(.bold))
                .foregroundStyle(RetroPalette.cobalt)

            RetroMetricField(
                title: String(localized: "hud.score", defaultValue: "Score"),
                value: "\(viewModel.state.points)"
            )
            RetroMetricField(
                title: String(localized: "hud.time", defaultValue: "Time"),
                value: "\(viewModel.state.elapsedSeconds)s"
            )
            RetroMetricField(
                title: String(localized: "hud.bombs_left", defaultValue: "Bombs Left"),
                value: "\(viewModel.state.remainingBombs)"
            )
            RetroMetricField(
                title: String(localized: "hud.bonus", defaultValue: "Bonus"),
                value: "\(viewModel.state.bonusPoints)"
            )

            Text(statusText)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(RetroPalette.ink.opacity(0.82))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
        }
        .padding(isPadLayout ? 10 : 12)
        .retroChromePanel(cornerRadius: 6)
    }

    private var boardPanel: some View {
        let boardViewState = viewModel.boardViewState
        let dimensions = boardViewState.dimensions

        return VStack(alignment: .leading, spacing: isPadLayout ? 8 : 10) {
            HStack {
                HStack(spacing: 10) {
                    Text("Board")
                        .font(.system(.title3, design: .serif).weight(.bold))
                        .foregroundStyle(RetroPalette.cobalt)
                    resetBoardButton(compact: isPadLayout)
                }
                Spacer()
                boardControlHint(compact: isPadLayout)
            }

            GeometryReader { proxy in
                let funnyOverlay = boardViewState.funnyBoomOverlay
                let overlayHeightAllowance: CGFloat = funnyOverlay == nil ? 0 : 90
                let metrics = fillingBoardMetrics(
                    for: dimensions,
                    in: CGSize(
                        width: proxy.size.width,
                        height: max(0, proxy.size.height - overlayHeightAllowance)
                    )
                )

                ZStack {
                    BoardGridView(dimensions: dimensions, cellSize: metrics.cellSize) { coordinate in
                        CellButtonView(
                            state: boardViewState.cellState(for: coordinate),
                            scorePulse: boardViewState.scorePulse(at: coordinate),
                            cellSize: metrics.cellSize,
                            onReveal: {
                                viewModel.tapCell(coordinate)
                            },
                            onFlag: {
                                viewModel.toggleFlag(coordinate)
                            }
                        )
                    }

                    if let funnyOverlay {
                        FunnyBoomOverlayBoardView(
                            dimensions: dimensions,
                            cellSize: metrics.cellSize,
                            overlay: funnyOverlay,
                            onTap: { coordinate in
                                viewModel.tapFunnyBoomCell(coordinate)
                            },
                            allowsScrolling: false
                        )
                    }
                }
                .frame(width: metrics.boardWidth, height: metrics.boardHeight + overlayHeightAllowance)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .clipShape(.rect(cornerRadius: 10))
                .transaction { transaction in
                    transaction.animation = nil
                }
            }
            .retroBoardWell(cornerRadius: 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Text("\(dimensions.columns)x\(dimensions.rows)")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(RetroPalette.ink.opacity(0.78))
                Spacer()
                activePowerStatusPill(compact: false)
            }
        }
        .padding(isPadLayout ? 8 : 12)
        .retroChromePanel(cornerRadius: 6)
    }

    @ViewBuilder
    private func activePowerStatusPill(compact: Bool) -> some View {
        if let activePower = viewModel.state.activePower {
            activePowerStatusPillLabel(
                title: "\(activePower.label) \(activePower.secondsRemaining)s",
                compact: compact
            )
        } else {
            // Keep footer height stable when the countdown expires to avoid board reflow.
            activePowerStatusPillLabel(
                title: String(localized: "power.placeholder", defaultValue: "Superhero 88s"),
                compact: compact
            )
                .hidden()
                .accessibilityHidden(true)
        }
    }

    private func activePowerStatusPillLabel(title: String, compact: Bool) -> some View {
        Label(title, systemImage: "sparkles")
            .font(
                compact
                    ? .system(size: 11, weight: .bold, design: .monospaced)
                    : .system(.footnote, design: .monospaced).weight(.semibold)
            )
            .foregroundStyle(RetroPalette.cobalt)
            .padding(.horizontal, compact ? 8 : 10)
            .padding(.vertical, compact ? 5 : 6)
            .retroInsetField(cornerRadius: compact ? 5 : 6)
    }

    private var statusText: String {
        switch viewModel.state.phase {
        case .idle:
            String(
                localized: "status.idle",
                defaultValue: "Tap any square to start. First tap is always safe."
            )
        case .running:
            String(
                localized: "status.running",
                defaultValue: "Quick press reveals cells. Long press flags bombs."
            )
        case .won:
            String(
                localized: "status.won",
                defaultValue: "Board completed. Submit your nickname for the top 10."
            )
        case .lost:
            String(
                localized: "status.lost",
                defaultValue: "Boom. Start a new board when you are ready."
            )
        }
    }

    private func boardControlHint(compact: Bool) -> some View {
        Text("quick press: reveal, long press: flag")
            .font(.system(size: compact ? 10 : 12, weight: .bold, design: .monospaced))
            .foregroundStyle(RetroPalette.cobalt.opacity(0.9))
            .multilineTextAlignment(.trailing)
            .padding(.horizontal, compact ? 6 : 10)
            .padding(.vertical, compact ? 5 : 6)
            .retroInsetField(cornerRadius: compact ? 5 : 6)
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
            viewModel.restartGame()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: compact ? 10 : 11, weight: .bold))
                Text(
                    compact
                        ? String(localized: "action.new_short", defaultValue: "New")
                        : String(localized: "action.new_game", defaultValue: "New Game")
                )
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

    private func fixedBoardMetrics(
        for dimensions: BoardDimensions,
        in size: CGSize,
        verticalChrome: CGFloat = 62
    ) -> BoardMetrics {
        let horizontalSpacing = CGFloat(max(0, dimensions.columns - 1))
        let verticalSpacing = CGFloat(max(0, dimensions.rows - 1))
        let usableWidth = max(0, size.width - 12)
        let usableHeight = max(0, size.height - verticalChrome)

        let cellWidth = max(1, (usableWidth - horizontalSpacing) / CGFloat(dimensions.columns))
        let cellHeight = max(1, (usableHeight - verticalSpacing) / CGFloat(dimensions.rows))
        let boardWidth = (CGFloat(dimensions.columns) * cellWidth) + horizontalSpacing
        let boardHeight = (CGFloat(dimensions.rows) * cellHeight) + verticalSpacing

        return BoardMetrics(
            cellSize: CGSize(width: cellWidth, height: cellHeight),
            boardWidth: boardWidth,
            boardHeight: boardHeight
        )
    }

    private func fillingBoardMetrics(
        for dimensions: BoardDimensions,
        in size: CGSize
    ) -> BoardMetrics {
        let horizontalSpacing = CGFloat(max(0, dimensions.columns - 1))
        let verticalSpacing = CGFloat(max(0, dimensions.rows - 1))
        let availableBoardWidth = max(0, size.width)
        let availableBoardHeight = max(0, size.height)
        let cellWidth = max(1, (availableBoardWidth - horizontalSpacing) / CGFloat(dimensions.columns))
        let cellHeight = max(1, (availableBoardHeight - verticalSpacing) / CGFloat(dimensions.rows))
        let boardWidth = (CGFloat(dimensions.columns) * cellWidth) + horizontalSpacing
        let boardHeight = (CGFloat(dimensions.rows) * cellHeight) + verticalSpacing

        return BoardMetrics(
            cellSize: CGSize(width: cellWidth, height: cellHeight),
            boardWidth: boardWidth,
            boardHeight: boardHeight
        )
    }

}
