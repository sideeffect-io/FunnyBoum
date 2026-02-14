import Foundation

struct SoundClient {
    var play: @MainActor (GameSoundEffect) -> Void
}
