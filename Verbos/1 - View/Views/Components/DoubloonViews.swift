import SwiftUI

struct DoubloonIcon: View {
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [.yellow.opacity(0.95), .orange, .brown],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().strokeBorder(.brown.opacity(0.6), lineWidth: size * 0.04)
            Circle().inset(by: size * 0.11)
                .strokeBorder(.yellow.opacity(0.75), lineWidth: size * 0.03)
            Image(systemName: "book.closed.fill")
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(.brown.opacity(0.8))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct DoubloonBalance: View {
    let count: Int
    var earned = false
    var size: CGFloat = 28
    var compact = false

    private var label: String {
        "\(earned ? "+" : "")\(count) \(count == 1 ? "doubloon" : "doubloons")"
    }

    var body: some View {
        HStack(spacing: 8) {
            DoubloonIcon(size: size)
            Text(compact ? count.formatted() : label).monospacedDigit()
        }
        .foregroundStyle(.orange)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label)\(earned ? " earned" : " available")")
    }
}

struct SlideToUnlockView: View {
    let isEnabled: Bool
    let confirm: () -> Void
    @GestureState private var translation: CGFloat = 0
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .headline) private var handleSize: CGFloat = 62

    var body: some View {
        GeometryReader { geometry in
            let travel = max(0, geometry.size.width - handleSize - 12)
            let distance = min(travel, max(0, translation))
            ZStack(alignment: .leading) {
                Capsule().fill(themeManager.current.surface)
                Capsule().strokeBorder(.orange.opacity(0.5), lineWidth: 1)
                Label("Slide to unlock", systemImage: "chevron.forward")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.leading, handleSize * 0.6)
                    .foregroundStyle(themeManager.current.tint)
                    .opacity(isEnabled ? 1 - Double(distance / max(1, travel)) : 0.45)
                DoubloonIcon(size: handleSize)
                    .padding(6)
                    .offset(x: distance)
                    .gesture(DragGesture(minimumDistance: 8)
                        .updating($translation) { value, state, _ in state = value.translation.width }
                        .onEnded { value in
                            guard isEnabled, travel > 0, value.translation.width >= travel * 0.92 else { return }
                            confirm()
                        })
            }
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: translation)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Slide to unlock today's book for one doubloon")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { if isEnabled { confirm() } }
        }
        .frame(height: handleSize + 12)
    }
}
