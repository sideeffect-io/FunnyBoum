import SwiftUI

struct StatsControlsView<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
    }
}

struct CompactMetricPill: View {
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

struct ControlTag: View {
    let title: String
    let subtitle: String
    let showsDisclosure: Bool
    let isExpanded: Bool

    init(
        title: String,
        subtitle: String,
        showsDisclosure: Bool = false,
        isExpanded: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showsDisclosure = showsDisclosure
        self.isExpanded = isExpanded
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .retroPixelFont(
                        size: 12,
                        weight: .black,
                        color: isExpanded ? RetroPalette.ink : RetroPalette.cobalt.opacity(0.9),
                        tracking: 0.35
                    )
                Text(subtitle)
                    .retroPixelFont(size: 14, weight: .bold, color: RetroPalette.ink, tracking: 0.4)
            }

            if showsDisclosure {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(isExpanded ? RetroPalette.ink.opacity(0.9) : RetroPalette.cobalt.opacity(0.85))
                    .offset(y: 0.5)
                    .accessibilityHidden(true)
            }
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .retroTabStyle(selected: isExpanded)
    }
}

struct RetroLogoBadge: View {
    let size: CGFloat
    var topCut: CGFloat = 0

    private var clampedTopCut: CGFloat {
        min(max(0, topCut), size * 0.45)
    }

    // Keep room for stroke/shadow overflow so only the top edge is clipped.
    private var topCutMaskOverflow: CGFloat {
        max(12, size * 0.16)
    }

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
        .mask {
            Rectangle()
                .frame(
                    width: size + (topCutMaskOverflow * 2),
                    height: size + (topCutMaskOverflow * 2) - clampedTopCut
                )
                .offset(y: (clampedTopCut / 2) + topCutMaskOverflow)
        }
        .shadow(color: .black.opacity(0.28), radius: 2.5, x: 0, y: 1)
    }
}

struct RetroMetricField: View {
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
