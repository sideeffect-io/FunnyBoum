import SwiftUI

extension View {
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
    func hidePlatformStatusBar(_ hidden: Bool) -> some View {
#if os(iOS)
        statusBar(hidden: hidden)
#else
        self
#endif
    }

    @ViewBuilder
    func iOSPreferredColorScheme(_ colorScheme: ColorScheme?) -> some View {
#if os(iOS)
        preferredColorScheme(colorScheme)
#else
        self
#endif
    }

}
