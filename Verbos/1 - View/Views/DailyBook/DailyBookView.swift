import SwiftUI

struct DailyBookView: View {
    @State private var viewModel = DailyBookViewModel()
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let error = viewModel.errorMessage {
                        OperationErrorView(message: error) { viewModel.refresh() }
                    }
                    if let book = viewModel.unlockedBook {
                        Text("Read along with \(viewModel.verbID.capitalized).")
                            .font(.headline)
                        BookReader(book: book)
                    } else if let book = viewModel.availableBook {
                        DailyBookUnlockCard(book: book, doubloonBalance: viewModel.doubloonBalance,
                                            canUnlock: viewModel.canUnlockAvailableBook,
                                            unlock: viewModel.unlockAvailableBook)
                    } else if viewModel.hasLoaded {
                        ContentUnavailableView("Today's book is unavailable", systemImage: "book.closed")
                    } else if viewModel.errorMessage == nil {
                        ProgressView("Opening today's book…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    }
                }
                .padding(20)
                .frame(maxWidth: 650)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(themeManager.current.background)
            .navigationTitle("Daily book")
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.refresh().value }
            .background {
                DayBoundaryObserver { viewModel.refresh() }
            }
        }
    }
}

private struct DailyBookUnlockCard: View {
    let book: LearningBook
    let doubloonBalance: Int
    let canUnlock: Bool
    let unlock: () -> Task<Void, Never>

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            DailyBookCover(book: book)
                .frame(width: 190, height: 280)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(book.englishTitle)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Today's reading opens for one doubloon and stays available until midnight.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Text("Your balance")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                DoubloonBalance(count: doubloonBalance, size: 32)
            }
            SlideToUnlockView(isEnabled: canUnlock) { _ = unlock() }
            if !canUnlock {
                Text("Score ten correct answers to earn a doubloon for this book.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
