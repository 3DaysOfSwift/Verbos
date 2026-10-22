import SwiftUI

struct DoubloonBalanceToolbar: ToolbarContent {
    let count: Int

    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarTrailing) {
                balance
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                balance
            }
        }
    }

    private var balance: some View {
        DoubloonBalance(count: count, size: 24, compact: true)
            .font(.subheadline.weight(.semibold))
            .allowsHitTesting(false)
            .accessibilityAddTraits(.isStaticText)
    }
}
