import SwiftUI

struct OverlayHostView<Content: View>: View {
    let onDismiss: () -> Void
    let isPhoneLayout: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        RetroOverlayBackdrop(onDismiss: onDismiss, isPhoneLayout: isPhoneLayout, content: content)
    }
}

enum ActiveOverlay: Equatable {
    case menu
    case rules
    case scores
    case about
    case victory(PendingVictory)
}

enum ControlBarPopup: Hashable {
    case difficulty
    case boardSize
}

struct ControlPopupFramePreferenceKey: PreferenceKey {
    static let defaultValue: [ControlBarPopup: CGRect] = [:]

    static func reduce(value: inout [ControlBarPopup: CGRect], nextValue: () -> [ControlBarPopup: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct SpecialModeCountdownFocusOverlayView: View {
    let notice: SpecialModeNotice
    let isPhoneLayout: Bool
    let onSkip: () -> Void

    private var accent: Color {
        switch notice.style {
        case .xray:
            return Color(red: 0.02, green: 0.36, blue: 0.57)
        case .superhero:
            return Color(red: 0.53, green: 0.25, blue: 0.04)
        case .funnyBoom:
            return Color(red: 0.63, green: 0.17, blue: 0.30)
        }
    }

    private var titleColor: Color {
        RetroPalette.ink
    }

    private var subtitleColor: Color {
        RetroPalette.ink.opacity(0.84)
    }

    private var countdownDiameter: CGFloat {
        isPhoneLayout ? 62 : 72
    }

    private var takeMeThereLabel: String {
        String(
            localized: "action.take_me_there",
            defaultValue: "TAKE ME THERE"
        )
    }

    var body: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: isPhoneLayout ? 14 : 16) {
                HStack(spacing: isPhoneLayout ? 10 : 12) {
                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.2))
                        Circle()
                            .stroke(accent.opacity(0.7), lineWidth: 1.5)
                        Image(systemName: notice.symbol)
                            .font(.system(size: isPhoneLayout ? 20 : 24, weight: .black))
                            .foregroundStyle(accent)
                            .symbolEffect(.pulse, options: .speed(0.75), value: notice.secondsRemaining)
                    }
                    .frame(width: isPhoneLayout ? 46 : 54, height: isPhoneLayout ? 46 : 54)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("SPECIAL MODE INCOMING")
                            .retroPixelFont(
                                size: isPhoneLayout ? 10 : 11,
                                weight: .black,
                                color: accent.opacity(0.95),
                                tracking: 0.52
                            )
                        Text(notice.title)
                            .retroPixelFont(
                                size: isPhoneLayout ? 15 : 17,
                                weight: .black,
                                color: titleColor,
                                tracking: 0.58
                            )
                        Text(notice.subtitle)
                            .font(.system(size: isPhoneLayout ? 11 : 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(subtitleColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, isPhoneLayout ? 14 : 16)
                .padding(.vertical, isPhoneLayout ? 12 : 14)
                .retroInsetField(cornerRadius: 8)

                ZStack {
                    Circle()
                        .stroke(accent.opacity(0.35), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: notice.progress)
                        .stroke(accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(notice.secondsRemaining)s")
                        .retroPixelFont(
                            size: isPhoneLayout ? 29 : 34,
                            weight: .black,
                            color: accent,
                            tracking: 0.62
                        )
                }
                .frame(width: countdownDiameter, height: countdownDiameter)

                Button(action: onSkip) {
                    Label(takeMeThereLabel, systemImage: "forward.end.fill")
                        .retroPixelFont(
                            size: isPhoneLayout ? 11 : 12,
                            weight: .black,
                            color: RetroPalette.ink,
                            tracking: 0.45
                        )
                        .padding(.horizontal, isPhoneLayout ? 12 : 14)
                        .padding(.vertical, isPhoneLayout ? 7 : 8)
                        .retroTabStyle()
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(accent.opacity(0.72), lineWidth: 1.1)
                        )
                        .shadow(color: accent.opacity(0.24), radius: 8, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityHint(
                    String(
                        localized: "action.take_me_there.hint",
                        defaultValue: "Skip the countdown and activate this special mode now."
                    )
                )
            }
            .padding(isPhoneLayout ? 16 : 18)
            .frame(maxWidth: isPhoneLayout ? 360 : 440)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(RetroPalette.chromeGradient.opacity(0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(accent.opacity(0.78), lineWidth: 1.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11)
                    .stroke(RetroPalette.chromeEdgeLight.opacity(0.72), lineWidth: 1)
                    .padding(1)
            )
            .shadow(color: .black.opacity(0.4), radius: 14, x: 0, y: 4)
            .padding(.horizontal, isPhoneLayout ? 18 : 24)
        }
    }
}

struct RetroBackgroundView: View {
    var body: some View {
        GeometryReader { _ in
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

struct RetroOverlayBackdrop<Content: View>: View {
    let onDismiss: () -> Void
    let isPhoneLayout: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            Color.black
                .opacity(0.68)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.12, blue: 0.30).opacity(0.65),
                            Color.black.opacity(0.76)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            content()
                .frame(maxWidth: isPhoneLayout ? .infinity : 840)
                .padding(.horizontal, isPhoneLayout ? 8 : 22)
                .padding(.vertical, isPhoneLayout ? 12 : 26)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

struct RetroControlPopupBackdrop<Content: View>: View {
    let onDismiss: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            content()
        }
    }
}

struct RetroOverlayPanel<Content: View>: View {
    let title: String
    let subtitle: String
    let onClose: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .retroPixelFont(size: 24, weight: .black, color: RetroPalette.ink, tracking: 0.6)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(RetroPalette.cobalt.opacity(0.9))
                }

                Spacer(minLength: 8)

                Button {
                    onClose()
                } label: {
                    Label("Close", systemImage: "xmark")
                        .retroPixelFont(size: 12, weight: .black, color: RetroPalette.cobalt, tracking: 0.35)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .retroTabStyle()
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(RetroPalette.chromeGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(RetroPalette.chromeEdgeDark, lineWidth: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(RetroPalette.chromeEdgeLight.opacity(0.82), lineWidth: 1)
                .padding(1)
        )
        .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 10)
    }
}

struct PhoneMenuSheetView: View {
    let settings: GameSettings
    let boardSizes: [BoardSizePreset]
    let onShowRules: () -> Void
    let onSetDifficulty: (GameDifficulty) -> Void
    let onSetBoardSize: (BoardSizePreset) -> Void
    let onShowScores: () -> Void
    let onShowAbout: () -> Void
    let onForceSpecialMode: (SpecialModeStyle) -> Void
    let onClose: () -> Void

    var body: some View {
        RetroOverlayPanel(
            title: String(localized: "sheet.menu.title", defaultValue: "Game Menu"),
            subtitle: String(
                localized: "sheet.menu.subtitle",
                defaultValue: "Retro controls and run setup"
            ),
            onClose: onClose
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    overlaySection(title: String(localized: "menu.section.game", defaultValue: "Game")) {
                        overlayActionButton(
                            title: String(localized: "menu.rules", defaultValue: "Rules"),
                            subtitle: String(
                                localized: "menu.rules.subtitle",
                                defaultValue: "View mechanics and special-square behavior"
                            ),
                            isSelected: false,
                            action: onShowRules
                        )

                        overlayActionButton(
                            title: String(localized: "menu.scores", defaultValue: "Scores"),
                            subtitle: String(
                                localized: "menu.scores.subtitle",
                                defaultValue: "Open top 10 leaderboard"
                            ),
                            isSelected: false,
                            action: onShowScores
                        )

                        overlayActionButton(
                            title: String(localized: "menu.about", defaultValue: "About"),
                            subtitle: String(
                                localized: "menu.about.subtitle",
                                defaultValue: "Story behind Funny Boum"
                            ),
                            isSelected: false,
                            action: onShowAbout
                        )
                    }

                    overlaySection(title: String(localized: "menu.difficulty", defaultValue: "Difficulty")) {
                        ForEach(GameDifficulty.allCases) { difficulty in
                            overlayActionButton(
                                title: difficulty.title,
                                subtitle: String(
                                    localized: "menu.mine_density",
                                    defaultValue: "Mine density \(Int((difficulty.mineDensity * 100).rounded()))%"
                                ),
                                isSelected: settings.difficulty == difficulty,
                                showsChevronWhenUnselected: false,
                                action: {
                                    onSetDifficulty(difficulty)
                                }
                            )
                        }
                    }

                    overlaySection(title: String(localized: "menu.board_size", defaultValue: "Board Size")) {
                        ForEach(boardSizes) { boardSize in
                            overlayActionButton(
                                title: boardSize.title,
                                subtitle: "\(boardSize.dimensions.columns)x\(boardSize.dimensions.rows)",
                                isSelected: settings.boardSize == boardSize,
                                showsChevronWhenUnselected: false,
                                action: {
                                    onSetBoardSize(boardSize)
                                }
                            )
                        }
                    }

#if DEBUG
                    overlaySection(title: String(localized: "menu.debug.title", defaultValue: "Debug")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(
                                String(
                                    localized: "menu.debug.subtitle",
                                    defaultValue: "Force special modes instantly"
                                )
                            )
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(RetroPalette.ink.opacity(0.72))
                            .padding(.horizontal, 2)

                            HStack(spacing: 6) {
                                debugModeButton(
                                    title: "X-RAY",
                                    symbol: "eye.fill",
                                    accent: Color(red: 0.05, green: 0.57, blue: 0.88),
                                    mode: .xray
                                )
                                debugModeButton(
                                    title: "SUPER",
                                    symbol: "bolt.fill",
                                    accent: Color(red: 0.95, green: 0.53, blue: 0.08),
                                    mode: .superhero
                                )
                                debugModeButton(
                                    title: "BOOM",
                                    symbol: "theatermasks.fill",
                                    accent: Color(red: 0.92, green: 0.29, blue: 0.48),
                                    mode: .funnyBoom
                                )
                            }
                        }
                    }
#endif
                }
            }
            .frame(maxHeight: 470)
        }
    }

    private func overlaySection<SectionContent: View>(
        title: String,
        @ViewBuilder content: () -> SectionContent
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .retroPixelFont(size: 12, weight: .black, color: RetroPalette.cobalt, tracking: 0.45)
                .padding(.horizontal, 8)

            VStack(spacing: 8) {
                content()
            }
        }
        .padding(8)
        .retroBoardWell(cornerRadius: 10)
    }

    private func overlayActionButton(
        title: String,
        subtitle: String,
        isSelected: Bool,
        showsChevronWhenUnselected: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .retroPixelFont(
                            size: 14,
                            weight: .black,
                            color: isSelected ? RetroPalette.ink : RetroPalette.cobalt,
                            tracking: 0.4
                        )
                    Text(subtitle)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink.opacity(0.72))
                }
                Spacer(minLength: 6)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if showsChevronWhenUnselected {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(RetroPalette.cobalt.opacity(0.7))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .retroTabStyle(selected: isSelected)
        }
        .buttonStyle(.plain)
    }

#if DEBUG
    private func debugModeButton(
        title: String,
        symbol: String,
        accent: Color,
        mode: SpecialModeStyle
    ) -> some View {
        Button {
            onForceSpecialMode(mode)
            onClose()
        } label: {
            Label(title, systemImage: symbol)
                .retroPixelFont(size: 9, weight: .black, color: RetroPalette.ink, tracking: 0.38)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.30), RetroPalette.fieldFill.opacity(0.88)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(RetroPalette.chromeEdgeDark.opacity(0.75), lineWidth: 1.1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(accent.opacity(0.72), lineWidth: 1.0)
                        .padding(1)
                )
                .shadow(color: accent.opacity(0.24), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityHint(
            String(
                localized: "menu.debug.force_mode.hint",
                defaultValue: "Debug: force this special mode immediately."
            )
        )
    }
#endif
}

struct AboutSheetView: View {
    let onClose: () -> Void

    var body: some View {
        RetroOverlayPanel(
            title: String(localized: "sheet.about.title", defaultValue: "About"),
            subtitle: String(
                localized: "sheet.about.subtitle",
                defaultValue: "From Turbo Pascal to iOS"
            ),
            onClose: onClose
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text(
                    String(
                        localized: "about.story",
                        defaultValue: "This game was originally developed in the mid-1990s in Turbo Pascal by Anthony Besq and Rénald Wittemberg. It took many weeks of work. It was ported to iOS in 2 days with Codex! What a time to be alive!"
                    )
                )
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(RetroPalette.ink.opacity(0.78))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(8)
            .retroBoardWell(cornerRadius: 10)
        }
        .frame(maxWidth: 560)
    }
}

struct RulesSheetView: View {
    let onClose: () -> Void

    var body: some View {
        RetroOverlayPanel(
            title: String(localized: "sheet.rules.title", defaultValue: "Rules"),
            subtitle: String(
                localized: "sheet.rules.subtitle",
                defaultValue: "Quick briefing before the blast"
            ),
            onClose: onClose
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    rulesSection(
                        title: String(localized: "rules.classic.title", defaultValue: "Classic"),
                        items: [
                            String(
                                localized: "rules.classic.1",
                                defaultValue: "Reveal any safe tile. A revealed number tells how many bombs touch that tile in the 8 surrounding positions."
                            ),
                            String(
                                localized: "rules.classic.2",
                                defaultValue: "Tap a bomb and you lose. Reveal every non-bomb tile to win."
                            ),
                            String(
                                localized: "rules.classic.3",
                                defaultValue: "When a revealed tile is empty, neighboring empty areas expand automatically."
                            )
                        ]
                    )

                    rulesSection(
                        title: String(localized: "rules.special.title", defaultValue: "Special Squares"),
                        items: [
                            String(
                                localized: "rules.special.1",
                                defaultValue: "When you reveal an empty tile for the first time, a special effect can trigger: +10 points, -10 points, X-Ray, Superhero, or Funny Boum."
                            ),
                            String(
                                localized: "rules.special.2",
                                defaultValue: "X-Ray (8s) temporarily shows hidden bombs on the board. They are still lethal if you reveal them."
                            ),
                            String(
                                localized: "rules.special.3",
                                defaultValue: "Superhero (8s) protects you: revealing a bomb will not lose the run, and that bomb is neutralized."
                            ),
                            String(
                                localized: "rules.special.4",
                                defaultValue: "Funny Boum starts after a 5s countdown, then runs an 8s clown hunt. Tap a clown for +10 points; other tiles give no points."
                            )
                        ]
                    )

                    rulesSection(
                        title: String(localized: "rules.controls.title", defaultValue: "Controls"),
                        items: [
                            String(
                                localized: "rules.controls.1",
                                defaultValue: "Quick press reveals a tile."
                            ),
                            String(
                                localized: "rules.controls.2",
                                defaultValue: "Long press flags or unflags a tile."
                            )
                        ]
                    )
                }
            }
            .frame(maxHeight: 470)
        }
    }

    private func rulesSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .retroPixelFont(size: 12, weight: .black, color: RetroPalette.cobalt, tracking: 0.45)
                .padding(.horizontal, 8)

            VStack(alignment: .leading, spacing: 7) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink.opacity(0.78))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(10)
            .retroInsetField(cornerRadius: 8)
        }
        .padding(8)
        .retroBoardWell(cornerRadius: 10)
    }
}

struct ScoresSheetView: View {
    let scores: [ScoreEntry]
    let highlightedScoreID: UUID?
    let onClose: () -> Void

    var body: some View {
        RetroOverlayPanel(
            title: String(localized: "sheet.scores.title", defaultValue: "Top 10"),
            subtitle: String(
                localized: "sheet.scores.subtitle",
                defaultValue: "Fastest and sharpest bomb hunters"
            ),
            onClose: onClose
        ) {
            if scores.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "trophy")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(RetroPalette.cobalt)
                    Text("No scores yet. Clear a board to enter the ranking.")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink.opacity(0.75))
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .retroBoardWell(cornerRadius: 12)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(scores.enumerated()), id: \.element.id) { index, score in
                            let isHighlighted = score.id == highlightedScoreID

                            HStack(alignment: .top, spacing: 10) {
                                Text("#\(index + 1)")
                                    .font(.system(size: 13, weight: .black, design: .monospaced))
                                    .foregroundStyle(isHighlighted ? RetroPalette.cobalt : RetroPalette.rankDarkRed)
                                    .frame(width: 32, alignment: .leading)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(score.nickname)
                                            .font(.system(.headline, design: .rounded).weight(.bold))

                                        if isHighlighted {
                                            Text("NEW")
                                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                                .foregroundStyle(RetroPalette.cobalt)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(
                                                    Capsule()
                                                        .fill(RetroPalette.fieldFill)
                                                )
                                        }

                                        Spacer(minLength: 8)
                                        Text("\(score.totalScore)")
                                            .font(.system(.headline, design: .monospaced).weight(.black))
                                    }

                                    Text(
                                        String(
                                            localized: "scores.points_time",
                                            defaultValue: "Points \(score.points) • Time \(score.elapsedSeconds)s"
                                        )
                                    )
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(RetroPalette.ink.opacity(0.76))

                                    Text("\(score.difficulty.title) • \(score.boardSize.title)")
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(RetroPalette.cobalt.opacity(0.82))
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        isHighlighted
                                            ? RetroPalette.fieldFill.opacity(0.42)
                                            : Color.clear
                                    )
                            )
                            .retroInsetField(cornerRadius: 8)
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        isHighlighted
                                            ? RetroPalette.cobalt.opacity(0.85)
                                            : Color.clear,
                                        lineWidth: 2
                                    )
                            }
                            .shadow(
                                color: isHighlighted ? RetroPalette.cobalt.opacity(0.25) : .clear,
                                radius: 4,
                                x: 0,
                                y: 1
                            )
                        }
                    }
                }
                .frame(maxHeight: 470)
            }
        }
    }
}

struct VictorySheetView: View {
    let victory: PendingVictory
    let onSubmit: (String) -> Void
    let onNewGame: () -> Void
    let onDismiss: () -> Void

    @State private var nickname: String = ""
    @FocusState private var isNicknameFieldFocused: Bool

    private var trimmedNickname: String {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        RetroOverlayPanel(
            title: String(localized: "sheet.victory.title", defaultValue: "Board Cleared"),
            subtitle: String(
                localized: "sheet.victory.subtitle",
                defaultValue: "Submit your run to the leaderboard"
            ),
            onClose: onDismiss
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text(
                    String(
                        localized: "victory.score_points_time",
                        defaultValue: "Score \(victory.totalScore) • Points \(victory.points) • Time \(victory.elapsedSeconds)s"
                    )
                )
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(RetroPalette.ink.opacity(0.78))

                TextField(
                    "Nickname",
                    text: $nickname,
                    prompt: Text("Nickname")
                        .foregroundStyle(RetroPalette.placeholderInk)
                )
                    .focused($isNicknameFieldFocused)
                    .nicknameCapitalization()
                    .textFieldStyle(.plain)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(RetroPalette.cobalt)
                    .tint(RetroPalette.cobalt)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .retroInsetField(cornerRadius: 8)

                victoryActionButton(
                    title: String(localized: "action.save_top_10", defaultValue: "Save to Top 10"),
                    systemImage: "checkmark.circle.fill",
                    isPrimary: true,
                    action: {
                        onSubmit(trimmedNickname)
                    }
                )
                .disabled(trimmedNickname.isEmpty)
                .opacity(trimmedNickname.isEmpty ? 0.58 : 1)

                victoryActionButton(
                    title: String(localized: "action.new_game_now", defaultValue: "New Game Now"),
                    systemImage: "arrow.clockwise",
                    isPrimary: false,
                    action: onNewGame
                )
            }
            .padding(8)
            .retroBoardWell(cornerRadius: 10)
        }
        .frame(maxWidth: 540)
        .onAppear {
            Task { @MainActor in
                await Task.yield()
                isNicknameFieldFocused = true
            }
        }
        .onDisappear {
            isNicknameFieldFocused = false
        }
    }

    private func victoryActionButton(
        title: String,
        systemImage: String,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .retroPixelFont(
                    size: 15,
                    weight: .black,
                    color: isPrimary ? RetroPalette.ink : RetroPalette.cobalt,
                    tracking: 0.4
                )
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .retroTabStyle(selected: isPrimary)
        }
        .buttonStyle(.plain)
    }
}
