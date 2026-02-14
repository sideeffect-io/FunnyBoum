//
//  FunnyBoomApp.swift
//  FunnyBoom
//
//  Created by Thibault Wittemberg on 11/02/2026.
//

import SwiftUI

@main
struct FunnyBoomApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
#if os(macOS)
        .defaultSize(width: 1_160, height: 820)
        .windowResizability(.contentMinSize)
#endif
    }
}
