import SwiftUI

struct ExplosionOverlayView: View {
    let trigger: Int
    let showActions: Bool
    let onNewGame: () -> Void

    @State private var startDate: Date = .now

    var body: some View {
        ZStack {
            TimelineView(.animation(minimumInterval: 1.0 / 45.0)) { timeline in
                let elapsed = max(0, timeline.date.timeIntervalSince(startDate))
                let progress = CGFloat(min(1, elapsed / 1.25))

                ZStack {
                    Color.black.opacity(Double(0.55 + (0.3 * progress)))

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    .white.opacity(Double(0.92 - progress)),
                                    .orange.opacity(Double(0.72 - (0.5 * progress))),
                                    .red.opacity(Double(0.44 - (0.2 * progress))),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 280 + (progress * 520)
                            )
                        )
                        .scaleEffect(0.15 + (progress * 2.8))
                        .blendMode(.plusLighter)

                    Circle()
                        .stroke(.white.opacity(Double(0.8 - progress)), lineWidth: 6)
                        .scaleEffect(0.08 + (progress * 3.4))
                        .blur(radius: 1)

                    ForEach(0..<68, id: \.self) { index in
                        let angle = Double(index) * 0.61803398875 * .pi * 2
                        let distance = (100 + CGFloat(index % 8) * 26) * progress
                        let life = max(0, 1 - progress)
                        let size = CGFloat((index % 4) + 2)

                        Circle()
                            .fill(index % 2 == 0 ? .orange : .yellow)
                            .frame(width: size, height: size)
                            .opacity(Double(life))
                            .offset(
                                x: cos(angle) * distance,
                                y: sin(angle) * distance
                            )
                            .blur(radius: life < 0.2 ? 0.6 : 0)
                    }
                }
                .ignoresSafeArea()
            }

            if showActions {
                VStack(spacing: 14) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 46, weight: .black))
                        .foregroundStyle(.orange)

                    Text("BOOM")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("The minefield detonated. Launch a fresh run.")
                        .font(.system(.body, design: .rounded).weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))

                    Button {
                        onNewGame()
                    } label: {
                        Label("New Game", systemImage: "arrow.clockwise")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .padding(.horizontal, 22)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.black.opacity(0.54))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(.white.opacity(0.26), lineWidth: 1)
                )
                .padding(26)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: trigger, initial: true) { _, _ in
            startDate = .now
        }
    }
}
