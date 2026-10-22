import SwiftUI

// Presentation-only artwork. The owning day supplies the accessible completion status.
struct DailyCompletionStamp: View {
    var body: some View {
        Image("DailyCompletionStamp")
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            // Fill the circular mask past the generated asset's transparent safety margin.
            .scaleEffect(1.09)
            .clipShape(Circle())
            .accessibilityHidden(true)
    }
}
