import Foundation

@MainActor
struct GameEffectRunner {
    let soundClient: SoundClient

    func run(
        _ events: [GameDomainEvent],
        onScheduleLossCardReveal: () -> Void
    ) {
        for event in events {
            switch event {
            case let .playSound(effect):
                soundClient.play(effect)
            case .scheduleLossCardReveal:
                onScheduleLossCardReveal()
            }
        }
    }
}
