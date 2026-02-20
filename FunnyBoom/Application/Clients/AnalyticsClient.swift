import Foundation

struct AnalyticsClient {
    var trackBoardStarted: @MainActor (BoardStartedAnalytics) -> Void
}

extension AnalyticsClient {
    static let noop = AnalyticsClient(
        trackBoardStarted: { _ in }
    )
}
