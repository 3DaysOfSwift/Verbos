import SwiftUI

// Decorative particles start behind the top centre of the Spanish question card.
struct MilestoneConfetti: View {
    @State private var startedAt = Date()

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let elapsed = timeline.date.timeIntervalSince(startedAt)
                    let colors: [Color] = [.yellow, .orange, .mint, .cyan, .pink]
                    for index in 0..<64 {
                        let delay = Double(index % 8) * 0.035
                        let time = elapsed - delay
                        guard time >= 0, time < 3.5 else { continue }
                        let angle = Double(index) * 2.39996
                        let horizontalSpeed = sin(angle) * (90 + Double(index % 5) * 30)
                        let upwardSpeed = 160 + Double(index % 7) * 23
                        let x = size.width / 2 + horizontalSpeed * time
                        let y = 192 - upwardSpeed * time + 125 * time * time
                        var particle = context
                        particle.opacity = max(0, min(1, (3.5 - time) / 0.8))
                        particle.translateBy(x: x, y: y)
                        particle.rotate(by: .radians(angle + time * 5))
                        particle.fill(Path(CGRect(x: -3, y: -5, width: 6, height: 10)),
                                      with: .color(colors[index % colors.count]))
                    }
                }
                .frame(width: geometry.size.width + 160, height: geometry.size.height + 360)
                .offset(x: -80, y: -180)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
