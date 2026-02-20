import SwiftUI

struct ContentView: View {
    private let dependencies: GameDependencies
    private let scoresClient: ScoresClient
    private let soundClient: SoundClient?
    private let analyticsClient: AnalyticsClient

    init(
        dependencies: GameDependencies = .live,
        scoresClient: ScoresClient = .live,
        soundClient: SoundClient? = nil,
        analyticsClient: AnalyticsClient = .noop
    ) {
        self.dependencies = dependencies
        self.scoresClient = scoresClient
        self.soundClient = soundClient
        self.analyticsClient = analyticsClient
    }

    var body: some View {
        GameRootView(
            dependencies: dependencies,
            scoresClient: scoresClient,
            soundClient: soundClient,
            analyticsClient: analyticsClient
        )
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
