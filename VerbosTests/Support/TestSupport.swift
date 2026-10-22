import Foundation
import Testing
@testable import Verbos

enum TestFailure: Error { case storage }

actor MemorySessions: SessionRepository, DoubloonRepository {
    var sessions: [TodaySession] = []
    var doubloonWallet = DoubloonWallet()
    var shouldFail = false
    var shouldFailWalletSave = false
    private(set) var saveCount = 0
    func fail(_ flag: Bool) { shouldFail = flag }
    func failWalletSave(_ flag: Bool) { shouldFailWalletSave = flag }
    func fetchSessions() throws -> [TodaySession] {
        if shouldFail { throw TestFailure.storage }
        return sessions
    }
    func save(_ session: TodaySession) throws {
        if shouldFail { throw TestFailure.storage }
        sessions.removeAll { $0.id == session.id }
        sessions.append(session)
        saveCount += 1
    }
    func fetchDoubloonWallet() throws -> DoubloonWallet {
        if shouldFail { throw TestFailure.storage }
        return doubloonWallet
    }
    func saveDoubloonWallet(_ wallet: DoubloonWallet) throws {
        if shouldFail || shouldFailWalletSave { throw TestFailure.storage }
        doubloonWallet = wallet
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
    let doubloons: DoubloonFeature
    let today: TodayFeature
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
        doubloons = DoubloonFeature(repository: repository, calendar: calendar, now: { clock.date })
        today = TodayFeature(repository: repository, calendar: calendar, now: { clock.date }, libraryFeature: library,
                             doubloonFeature: doubloons)
        streak = DayStreakFeature(todayFeature: today, calendar: calendar)
    }
    func start() async throws { try await today.perform(.start(extra: false, mode: .mixed)) }
    func answerCorrectly() async throws {
        let question = try #require(today.currentSession?.question)
        try await today.perform(.answer(questionID: question.id, value: question.answer))
    }
    func finish() async throws {
        // A finite bound makes a broken completion rule fail rather than hang the suite.
        for _ in 0..<20 {
            let session = try #require(today.currentSession)
            if session.isComplete { return }
            if session.question.isResolved { try await today.perform(.next(questionID: session.question.id)) }
            try await answerCorrectly()
        }
        #expect(today.currentSession?.isComplete == true)
    }
}
