import Foundation
import Observation

@MainActor @Observable
final class BookViewModel {
    private let libraryFeature: LibraryFeature
    private(set) var errorMessage: String?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    private(set) var isRefreshing = false

    init(libraryFeature: LibraryFeature = AppModel.shared.libraryFeature) {
        self.libraryFeature = libraryFeature
    }

    func book(for verbID: String) -> LearningBook? { libraryFeature.book(for: verbID) }

    @discardableResult
    func refresh(download: Bool = false) -> Task<Void, Never> {
        if let refreshTask { return refreshTask }
        isRefreshing = true
        let task = Task { @MainActor in
            defer { refreshTask = nil; isRefreshing = false }
            errorMessage = nil
            do {
                if download {
                    await libraryFeature.refreshBooks()
                    errorMessage = libraryFeature.refreshError
                } else {
                    try await libraryFeature.load()
                }
            } catch { errorMessage = error.localizedDescription }
        }
        refreshTask = task
        return task
    }
}
