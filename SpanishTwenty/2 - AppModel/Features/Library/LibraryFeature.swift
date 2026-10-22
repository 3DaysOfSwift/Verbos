import Foundation
import Observation

@MainActor @Observable
final class LibraryFeature {
    private(set) var books: [LearningBook] = []
    private(set) var verbs: [LearningVerb] = []
    private(set) var refreshError: String?
    private let repository: any LearningContentRepository
    @ObservationIgnored private var loadTask: Task<Void, Error>?
    @ObservationIgnored private var updateTask: Task<Void, Never>?

    init(repository: any LearningContentRepository) { self.repository = repository }

    var supportedBooks: [LearningBook] {
        books.filter { book in
            guard let verbID = book.verbFocus?.infinitive,
                  ["ser", "estar", "querer"].contains(verbID) else { return false }
            return verbs.contains { $0.id == verbID }
        }
    }

    func load() async throws {
        if !books.isEmpty { return }
        if let loadTask { return try await loadTask.value }
        let task = Task { @MainActor in
            defer { loadTask = nil }
            let content = try await repository.load()
            verbs = content.verbs
            books = content.books
        }
        loadTask = task
        try await task.value
    }

    func refreshBooks() async {
        if let updateTask { return await updateTask.value }
        let task = Task { @MainActor in
            defer { updateTask = nil }
            refreshError = nil
            do {
                _ = try await repository.refreshBooks()
                let content = try await repository.load()
                verbs = content.verbs
                books = content.books
            } catch {
                refreshError = error.localizedDescription
            }
        }
        updateTask = task
        await task.value
    }

    func book(for verbID: String) -> LearningBook? {
        supportedBooks.first { $0.verbFocus?.infinitive == verbID }
    }

    func differentVerb(excluding current: String) throws -> String {
        let candidates = Set(supportedBooks.compactMap { $0.verbFocus?.infinitive }).filter { $0 != current }
        guard let chosen = candidates.randomElement() else { throw LearningContentError.unavailableBook }
        return chosen
    }

    func questions(verbID: String, mode: LearningMode) throws -> [WordQuestion] {
        guard book(for: verbID) != nil, let verb = verbs.first(where: { $0.id == verbID }) else {
            throw LearningContentError.unavailableBook
        }
        return try ConjugationQuestions.make(verb: verb, mode: mode)
    }
}
