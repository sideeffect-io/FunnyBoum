//
//  FunnyBoomApp.swift
//  FunnyBoom
//
//  Created by Thibault Wittemberg on 11/02/2026.
//

import SwiftUI
import TelemetryDeck

@main
struct FunnyBoomApp: App {
    private var analyticsClient: AnalyticsClient {
        let config = TelemetryDeck.Config(
            appID: "BCEFCA2F-9D8A-4831-9C52-B4F00B0BC22A",
            namespace: "io.sideeffect"
        )
        TelemetryDeck.initialize(config: config)

        let client = AnalyticsClient(
            trackBoardStarted: { payload in
                TelemetryDeck.signal(
                    "Board.started",
                    parameters: [
                        "difficulty": payload.difficulty.analyticsLabel,
                        "boardSize": payload.boardSizeLabel,
                    ]
                )
            }
        )
        
        return client
    }

    var body: some Scene {
        WindowGroup {
            ContentView(analyticsClient: analyticsClient)
        }
#if os(macOS)
        .defaultSize(width: 1_160, height: 820)
        .windowResizability(.contentMinSize)
#endif
    }
}
