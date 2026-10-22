import SwiftUI

struct BookView: View {
    let verbID: String
    @State private var viewModel = BookViewModel()
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let error = viewModel.errorMessage {
                        OperationErrorView(message: error) { viewModel.refresh(download: true) }
                    }
                    if let book = viewModel.book(for: verbID) {
                        Text(book.title).font(.largeTitle.bold())
                        Text(book.englishTitle).font(.title3).foregroundStyle(.secondary)
                        Text("By \(book.author)").font(.subheadline)
                        Text("This story teaches the present tense. Your practice also uses Cuentiva’s conjugation tables to explore the past and future.")
                            .font(.callout).foregroundStyle(.secondary)
                        ForEach(book.fullText) { sentence in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(sentence.spanish).font(.title3)
                                Text(sentence.english).foregroundStyle(.secondary)
                            }
                            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                            .background(themeManager.current.surface, in: RoundedRectangle(cornerRadius: 20))
                        }
                        Text(book.license).font(.footnote).foregroundStyle(.secondary)
                    }
                    Button("Refresh Cuentiva books", systemImage: "arrow.clockwise") {
                        viewModel.refresh(download: true)
                    }
                    .frame(minHeight: 48).disabled(viewModel.isRefreshing)
                    if viewModel.isRefreshing { ProgressView("Loading books…") }
                    Text("Books use Cuentiva’s shared catalogue. Conjugation tables ship with this app. No account is required.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(20).frame(maxWidth: 650).frame(maxWidth: .infinity)
            }
            .background(themeManager.current.background)
            .navigationTitle("Your verb book").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task { await viewModel.refresh().value }
        }
    }
}
