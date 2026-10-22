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
                    if let book = viewModel.book {
                        Text("Read along with \(viewModel.verbID.capitalized).")
                            .font(.headline)
                        BookReader(book: book)
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
        }
    }
}
