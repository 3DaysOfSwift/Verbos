import Foundation
import Observation

@MainActor @Observable
final class DailyBookViewModel {
    private let todayFeature: TodayFeature
    private let libraryFeature: LibraryFeature
    private(set) var errorMessage: String?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?

    init(todayFeature: TodayFeature = AppModel.shared.todayFeature,
         libraryFeature: LibraryFeature = AppModel.shared.libraryFeature) {
        self.todayFeature = todayFeature
        self.libraryFeature = libraryFeature
    }

    var verbID: String { todayFeature.currentSession?.verbID ?? todayFeature.selectedVerbID }
    var book: LearningBook? { libraryFeature.book(for: verbID) }
    var hasLoaded: Bool { !libraryFeature.books.isEmpty }

    @discardableResult
    func refresh() -> Task<Void, Never> {
        if let refreshTask { return refreshTask }
        let task = Task { @MainActor in
            defer { refreshTask = nil }
            errorMessage = nil
            do {
                try await libraryFeature.load()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        refreshTask = task
        return task
    }
}
