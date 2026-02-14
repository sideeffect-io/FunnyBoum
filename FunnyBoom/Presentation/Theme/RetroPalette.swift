import SwiftUI

enum RetroPalette {
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
    static let placeholderInk = Color(red: 0.33, green: 0.34, blue: 0.37)
    static let rankDarkRed = Color(red: 0.45, green: 0.07, blue: 0.09)
    static let ink = Color.black.opacity(0.88)
}
