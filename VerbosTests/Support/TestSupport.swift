import Foundation
import Testing
@testable import Verbos

enum TestFailure: Error { case storage }

actor MemorySessions: SessionRepository {
    var sessions: [PracticeSession] = []
    var shouldFail = false
    private(set) var saveCount = 0
    func fail(_ flag: Bool) { shouldFail = flag }
    func fetchSessions() throws -> [PracticeSession] {
        if shouldFail { throw TestFailure.storage }
        return sessions
    }
    func save(_ session: PracticeSession) throws {
        if shouldFail { throw TestFailure.storage }
        sessions.removeAll { $0.id == session.id }
        sessions.append(session)
        saveCount += 1
    }
}

actor MemoryContent: LearningContentRepository {
    let content: LearningContent
    var shouldFail = false
    private(set) var loadCount = 0
    init(_ content: LearningContent) { self.content = content }
    func fail(_ flag: Bool) { shouldFail = flag }
    func load() throws -> LearningContent {
        loadCount += 1
        if shouldFail { throw TestFailure.storage }
        return content
    }
    func refreshBooks() throws -> [LearningBook] {
        if shouldFail { throw TestFailure.storage }
        return content.books
    }
}

enum ContentFixtures {
    static func load() throws -> LearningContent {
        let root = URL(filePath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Verbos/3 - App Resources")
        let booksURL = Bundle.main.url(forResource: "books", withExtension: "json") ?? root.appending(path: "books.json")
        let verbsURL = Bundle.main.url(forResource: "verbs", withExtension: "json") ?? root.appending(path: "verbs.json")
        return LearningContent(
            books: try JSONDecoder().decode([LearningBook].self, from: Data(contentsOf: booksURL)),
            verbs: try JSONDecoder().decode([LearningVerb].self, from: Data(contentsOf: verbsURL)))
    }
}

@MainActor final class TestClock {
    var date = Date(timeIntervalSince1970: 1_800_446_400)
}

@MainActor struct TestEnvironment {
    let repository: MemorySessions
    let content: MemoryContent
    let library: LibraryFeature
    let practice: PracticeFeature
    let streak: DayStreakFeature
    let clock: TestClock
    let calendar: Calendar

    init(repository: MemorySessions = MemorySessions(), clock: TestClock = TestClock()) throws {
        self.repository = repository
        self.clock = clock
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        self.calendar = calendar
        content = MemoryContent(try ContentFixtures.load())
        library = LibraryFeature(repository: content)
        practice = PracticeFeature(repository: repository, calendar: calendar, now: { clock.date }, libraryFeature: library)
        streak = DayStreakFeature(practiceFeature: practice, calendar: calendar)
    }
    func start() async throws { try await practice.perform(.start(extra: false, mode: .mixed)) }
    func answerCorrectly() async throws {
        let question = try #require(practice.currentSession?.question)
        try await practice.perform(.answer(questionID: question.id, value: question.answer))
    }
    func finish() async throws {
        // A finite bound makes a broken completion rule fail rather than hang the suite.
        for _ in 0..<20 {
            let session = try #require(practice.currentSession)
            if session.isComplete { return }
            if session.question.isResolved { try await practice.perform(.next(questionID: session.question.id)) }
            try await answerCorrectly()
        }
        #expect(practice.currentSession?.isComplete == true)
    }
}
