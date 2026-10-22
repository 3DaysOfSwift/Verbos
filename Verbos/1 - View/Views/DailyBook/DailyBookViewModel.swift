import Foundation
import Observation

@MainActor @Observable
final class DailyBookViewModel {
    private let todayFeature: TodayFeature
    private let libraryFeature: LibraryFeature
    private let doubloonFeature: DoubloonFeature
    private(set) var errorMessage: String?
    private(set) var displayDate = Date()
    @ObservationIgnored private var refreshTask: Task<Void, Never>?

    init(todayFeature: TodayFeature = AppModel.shared.todayFeature,
         libraryFeature: LibraryFeature = AppModel.shared.libraryFeature,
         doubloonFeature: DoubloonFeature = AppModel.shared.doubloonFeature) {
        self.todayFeature = todayFeature
        self.libraryFeature = libraryFeature
        self.doubloonFeature = doubloonFeature
    }

    var verbID: String { todayFeature.currentSession?.verbID ?? todayFeature.selectedVerbID }
    var availableBook: LearningBook? { libraryFeature.book(for: verbID) }
    var unlockedBook: LearningBook? {
        guard let bookID = doubloonFeature.unlockedBookID(for: displayDate) else { return nil }
        return libraryFeature.books.first { $0.id == bookID }
    }
    var doubloonBalance: Int { doubloonFeature.balance }
    var canUnlockAvailableBook: Bool { availableBook != nil && doubloonBalance > 0 }
    var hasLoaded: Bool { !libraryFeature.books.isEmpty }

    @discardableResult
    func refresh() -> Task<Void, Never> {
        if let refreshTask { return refreshTask }
        let task = Task { @MainActor in
            defer { refreshTask = nil }
            errorMessage = nil
            displayDate = Date()
            do {
                try await libraryFeature.load()
                try await doubloonFeature.load()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        refreshTask = task
        return task
    }

    @discardableResult
    func unlockAvailableBook() -> Task<Void, Never> {
        let task = Task { @MainActor in
            guard let availableBook else { return }
            errorMessage = nil
            do {
                try await doubloonFeature.unlockDailyBook(id: availableBook.id, on: displayDate)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        return task
    }
}
