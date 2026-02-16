import Foundation

extension GameReducer {
    static func tick(state: GameState, dependencies: GameDependencies) -> GameTransition {
        guard state.phase == .running else { return GameTransition(state: state) }

        var nextState = state
        var events: [GameDomainEvent] = []
        var shouldPlayCountdownBeep = false

        nextState.elapsedSeconds += 1

        if let activePower = nextState.activePower {
            switch activePower {
            case let .xray(secondsRemaining):
                if secondsRemaining <= 1 {
                    nextState.activePower = nil
                } else {
                    let updatedSeconds = secondsRemaining - 1
                    nextState.activePower = .xray(secondsRemaining: updatedSeconds)
                    shouldPlayCountdownBeep = shouldPlayCountdownBeep || isFinalThreeSecondCountdown(
                        previousSeconds: secondsRemaining,
                        currentSeconds: updatedSeconds
                    )
                }

            case let .superhero(secondsRemaining):
                if secondsRemaining <= 1 {
                    nextState.activePower = nil
                } else {
                    let updatedSeconds = secondsRemaining - 1
                    nextState.activePower = .superhero(secondsRemaining: updatedSeconds)
                    shouldPlayCountdownBeep = shouldPlayCountdownBeep || isFinalThreeSecondCountdown(
                        previousSeconds: secondsRemaining,
                        currentSeconds: updatedSeconds
                    )
                }
            }
        }

        if var overlay = nextState.funnyBoomOverlay {
            switch overlay.phase {
            case let .briefing(secondsRemaining):
                if secondsRemaining <= 1 {
                    overlay.phase = .active(secondsRemaining: ScoreRules.funnyBoomPlayDuration)
                } else {
                    overlay.phase = .briefing(secondsRemaining: secondsRemaining - 1)
                }
                nextState.funnyBoomOverlay = overlay

            case let .active(secondsRemaining):
                if secondsRemaining <= 1 {
                    nextState.funnyBoomOverlay = nil
                } else {
                    let updatedSeconds = secondsRemaining - 1
                    overlay.phase = .active(secondsRemaining: updatedSeconds)
                    nextState.funnyBoomOverlay = overlay
                    shouldPlayCountdownBeep = shouldPlayCountdownBeep || isFinalThreeSecondCountdown(
                        previousSeconds: secondsRemaining,
                        currentSeconds: updatedSeconds
                    )
                }
            }
        }

        if var specialModeNotice = nextState.specialModeNotice {
            specialModeNotice.secondsRemaining -= 1
            if specialModeNotice.secondsRemaining <= 0 {
                nextState = activatePreparedSpecialModeIfNeeded(
                    state: nextState,
                    style: specialModeNotice.style,
                    dependencies: dependencies
                )
            } else {
                nextState.specialModeNotice = specialModeNotice
            }
        }

        if !nextState.tileScorePulses.isEmpty {
            var refreshedPulses: [BoardCoordinate: TileScorePulse] = [:]
            refreshedPulses.reserveCapacity(nextState.tileScorePulses.count)

            for (coordinate, pulse) in nextState.tileScorePulses {
                var nextPulse = pulse
                nextPulse.secondsRemaining -= 1
                if nextPulse.secondsRemaining > 0 {
                    refreshedPulses[coordinate] = nextPulse
                }
            }

            nextState.tileScorePulses = refreshedPulses
        }

        if shouldPlayCountdownBeep {
            events.append(.playSound(.countdownBeep))
        }

        return GameTransition(state: nextState, events: events)
    }

    static func isFinalThreeSecondCountdown(previousSeconds: Int, currentSeconds: Int) -> Bool {
        currentSeconds < previousSeconds && currentSeconds <= 3 && currentSeconds > 0
    }
}
