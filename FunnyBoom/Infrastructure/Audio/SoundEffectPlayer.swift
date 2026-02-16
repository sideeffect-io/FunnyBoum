import Foundation
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class SoundEffectPlayer {
    private actor Worker {
        private var explosionSound: Data?
        private var specialDiscoverySound: Data?
        private var victorySound: Data?
        private var countdownBeepSound: Data?

        func preload() {
            _ = explosionData()
            _ = specialDiscoveryData()
            _ = victoryData()
            _ = countdownBeepData()
        }

        func soundData(for effect: GameSoundEffect) -> Data? {
            switch effect {
            case .explosion:
                explosionData()
            case .specialSquareDiscovered:
                specialDiscoveryData()
            case .victory:
                victoryData()
            case .countdownBeep:
                countdownBeepData()
            case .flagPlaced:
                nil
            }
        }

        private func explosionData() -> Data {
            if let explosionSound {
                return explosionSound
            }
            let generated = RetroArcadeSynth.makeExplosionWAV()
            explosionSound = generated
            return generated
        }

        private func specialDiscoveryData() -> Data {
            if let specialDiscoverySound {
                return specialDiscoverySound
            }
            let generated = RetroArcadeSynth.makeDiscoveryWAV()
            specialDiscoverySound = generated
            return generated
        }

        private func victoryData() -> Data {
            if let victorySound {
                return victorySound
            }
            let generated = RetroArcadeSynth.makeVictoryWAV()
            victorySound = generated
            return generated
        }

        private func countdownBeepData() -> Data {
            if let countdownBeepSound {
                return countdownBeepSound
            }
            let generated = RetroArcadeSynth.makeCountdownBeepWAV()
            countdownBeepSound = generated
            return generated
        }
    }

    private let worker = Worker()
    private var preloadTask: Task<Void, Never>?
    private var activePlayers: [AVAudioPlayer] = []

    init() {
        configureAudioSession()

        preloadTask = Task(priority: .utility) { [worker] in
            await worker.preload()
        }
    }

    deinit {
        preloadTask?.cancel()
    }

    func play(_ effect: GameSoundEffect) {
        switch effect {
        case .flagPlaced:
#if canImport(UIKit)
            #if os(iOS)
            let style: UIImpactFeedbackGenerator.FeedbackStyle =
                UIDevice.current.userInterfaceIdiom == .phone ? .heavy : .light
            let intensity: CGFloat = UIDevice.current.userInterfaceIdiom == .phone ? 1.0 : 0.75
            #else
            let style: UIImpactFeedbackGenerator.FeedbackStyle = .light
            let intensity: CGFloat = 0.75
            #endif

            let feedback = UIImpactFeedbackGenerator(style: style)
            feedback.prepare()
            feedback.impactOccurred(intensity: intensity)
#endif
            return
        case .explosion, .specialSquareDiscovered, .victory, .countdownBeep:
            break
        }

        Task { [weak self, worker] in
            guard let self else { return }
            guard let data = await worker.soundData(for: effect) else { return }
            guard !Task.isCancelled else { return }

            await MainActor.run {
                self.playPreparedAudio(data, effect: effect)
            }
        }
    }

    private func playPreparedAudio(_ data: Data, effect: GameSoundEffect) {
        guard let player = try? AVAudioPlayer(data: data) else {
            return
        }

        cleanupInactivePlayers()
        player.volume = 0.86
        player.prepareToPlay()
        player.play()
        activePlayers.append(player)

#if canImport(UIKit)
        let feedbackType: UINotificationFeedbackGenerator.FeedbackType? = switch effect {
        case .explosion:
            .error
        case .specialSquareDiscovered, .victory:
            .success
        case .countdownBeep, .flagPlaced:
            nil
        }

        if let feedbackType {
            let feedback = UINotificationFeedbackGenerator()
            feedback.prepare()
            feedback.notificationOccurred(feedbackType)
        }
#endif
    }

    private func cleanupInactivePlayers() {
        activePlayers.removeAll { !$0.isPlaying }
    }

    private func configureAudioSession() {
#if canImport(UIKit)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true, options: [])
#endif
    }
}

extension SoundClient {
    @MainActor
    static func live() -> SoundClient {
        let player = SoundEffectPlayer()
        return SoundClient(
            play: { effect in
                player.play(effect)
            }
        )
    }
}
