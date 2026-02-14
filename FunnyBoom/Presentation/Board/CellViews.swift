import SwiftUI

struct CellViewState: Equatable {
    let isMine: Bool
    let adjacentMines: Int
    let isRevealed: Bool
    let isFlagged: Bool
    let canInteract: Bool
    let isXrayActive: Bool

    var mineVisibleFromXray: Bool {
        guard isXrayActive, !isRevealed, !isFlagged else { return false }
        return isMine
    }
}

struct CellButtonView: View {
    let state: CellViewState
    let scorePulse: TileScorePulse?
    let cellSize: CGSize
    let onReveal: () -> Void
    let onFlag: () -> Void
    @State private var flagPulseScale: CGFloat = 1

    var body: some View {
        CellFaceView(
            isRevealed: state.isRevealed,
            isFlagged: state.isFlagged,
            mineVisibleFromXray: state.mineVisibleFromXray,
            isMine: state.isMine,
            adjacentMines: state.adjacentMines,
            scorePulse: scorePulse,
            cellSize: cellSize
        )
        .scaleEffect(flagPulseScale)
        .contentShape(.rect)
        .allowsHitTesting(state.canInteract)
        .gesture(interactionGesture)
        .onChange(of: state.isFlagged) { _, isFlagged in
            guard isFlagged else {
                flagPulseScale = 1
                return
            }
            animateFlagPulse()
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Quick press reveals. Long press flags or unflags.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, onReveal)
        .accessibilityAction(
            named: Text(
                state.isFlagged
                    ? String(localized: "action.unflag", defaultValue: "Unflag")
                    : String(localized: "action.flag", defaultValue: "Flag")
            ),
            onFlag
        )
    }

    private var accessibilityLabel: String {
        if state.isFlagged {
            return String(localized: "cell.flagged", defaultValue: "Flagged tile")
        }
        if !state.isRevealed {
            return String(localized: "cell.hidden", defaultValue: "Hidden tile")
        }
        if state.isMine {
            return String(localized: "cell.bomb", defaultValue: "Bomb")
        }
        if state.adjacentMines == 0 {
            return String(localized: "cell.empty", defaultValue: "Empty tile")
        }
        return String(
            localized: "cell.neighbors",
            defaultValue: "Tile with \(state.adjacentMines) neighboring bombs"
        )
    }

    private var interactionGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.45)
            .exclusively(before: TapGesture())
            .onEnded { value in
                switch value {
                case .first(true):
                    onFlag()
                case .first(false):
                    break
                case .second:
                    onReveal()
                }
            }
    }

    private func animateFlagPulse() {
        flagPulseScale = 1
        withAnimation(.spring(response: 0.16, dampingFraction: 0.56)) {
            flagPulseScale = 1.18
        }
        withAnimation(.spring(response: 0.24, dampingFraction: 0.76).delay(0.10)) {
            flagPulseScale = 1
        }
    }
}

struct CellFaceView: View {
    let isRevealed: Bool
    let isFlagged: Bool
    let mineVisibleFromXray: Bool
    let isMine: Bool
    let adjacentMines: Int
    let scorePulse: TileScorePulse?
    let cellSize: CGSize

    private var minSide: CGFloat {
        min(cellSize.width, cellSize.height)
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(backgroundColor)

            if isFlagged {
                Image(systemName: "flag.fill")
                    .font(.system(size: minSide * 0.5, weight: .bold))
                    .foregroundStyle(.orange)
            } else if isRevealed {
                revealedContent
            } else if mineVisibleFromXray {
                Image(systemName: "burst.fill")
                    .font(.system(size: minSide * 0.45, weight: .bold))
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse, options: .repeating)
                    .opacity(0.92)
            }

            if let scorePulse {
                scorePulseIndicator(for: scorePulse)
            }
        }
        .frame(width: cellSize.width, height: cellSize.height)
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
                .font(.system(size: minSide * 0.45, weight: .bold))
                .foregroundStyle(.red)
        } else if adjacentMines > 0 {
            Text("\(adjacentMines)")
                .font(.system(size: minSide * 0.62, weight: .black, design: .rounded))
                .foregroundStyle(numberColor)
        }
    }

    private func scorePulseIndicator(for scorePulse: TileScorePulse) -> some View {
        let isBonus = scorePulse.pointsDelta >= 0
        let highlight = isBonus
            ? Color(red: 0.10, green: 0.46, blue: 0.14)
            : Color(red: 0.58, green: 0.12, blue: 0.12)

        return Text(scorePulse.label)
            .font(.system(size: max(8, minSide * 0.42), weight: .black, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: min(cellSize.width, minSide * 1.12))
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
