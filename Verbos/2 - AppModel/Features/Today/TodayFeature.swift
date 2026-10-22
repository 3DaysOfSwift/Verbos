import Foundation
import Observation

@MainActor @Observable
final class TodayFeature {
    enum Command: Hashable {
        case refresh
        case start(extra: Bool, mode: LearningMode)
        case answer(questionID: UUID, value: String)
        case reveal(questionID: UUID)
        case next(questionID: UUID)
        case mode(LearningMode)
        case shuffleVerb
    }

    private(set) var sessions: [TodaySession] = []
    private(set) var today: Date
    private(set) var hasLoaded = false
    let calendar: Calendar
    private let repository: any SessionRepository
    private let now: () -> Date
    private let libraryFeature: LibraryFeature
    private let doubloonFeature: DoubloonFeature
    private(set) var selectedVerbID = "ser"
    @ObservationIgnored private var operationTask: Task<Void, Error>?
    @ObservationIgnored private var operationID: UUID?

    init(repository: any SessionRepository, calendar: Calendar = .current,
         now: @escaping () -> Date = Date.init,
         libraryFeature: LibraryFeature, doubloonFeature: DoubloonFeature) {
        self.repository = repository
        self.calendar = calendar
        self.now = now
        self.libraryFeature = libraryFeature
        self.doubloonFeature = doubloonFeature
        today = calendar.startOfDay(for: now())
    }

    var todaySessions: [TodaySession] {
        sessions.filter { calendar.isDate($0.day, inSameDayAs: today) }
    }
    var isSelectedVerbReady: Bool { libraryFeature.book(for: selectedVerbID) != nil }
    var currentSession: TodaySession? {
        todaySessions.first(where: { $0.isExtraPractice }) ?? todaySessions.first
    }
    var canStartExtraPractice: Bool {
        todaySessions.contains(where: { !$0.isExtraPractice && $0.isComplete }) &&
        !todaySessions.contains(where: { $0.isExtraPractice })
    }
    var isDayLocked: Bool {
        todaySessions.contains(where: { $0.isExtraPractice && $0.isComplete })
    }
    // This is the reusable activity boundary. Streaks need dates, not word questions.
    var completedActivityDays: Set<Date> {
        Set(sessions.filter { !$0.isExtraPractice && $0.isComplete }.map { $0.day })
    }

    func perform(_ command: Command) async throws {
        let predecessor = operationTask
        let identifier = UUID()
        let task = Task { @MainActor in
            // A failed write does not poison subsequent retries. Distinct commands stay ordered.
            _ = try? await predecessor?.value
            try Task.checkCancellation()
            try await self.execute(command)
        }
        operationTask = task
        operationID = identifier
        defer {
            if operationID == identifier {
                operationTask = nil
                operationID = nil
            }
        }
        try await task.value
    }

    private func execute(_ command: Command) async throws {
        today = calendar.startOfDay(for: now())
        if !hasLoaded {
            sessions = try await repository.fetchSessions()
            hasLoaded = true
        }
        try await reconcileProgressRewards()
        switch command {
        case .refresh:
            if currentSession == nil { try await libraryFeature.load() }
            if var session = currentSession, !session.isComplete,
               session.question.example == nil || session.deck.contains(where: { $0.example == nil }) {
                // Upgrade older saved questions without replacing their answers or progress.
                try await libraryFeature.load()
                if session.question.example == nil {
                    session.question.example = try libraryFeature.example(for: session.question)
                }
                for index in session.deck.indices where session.deck[index].example == nil {
                    session.deck[index].example = try libraryFeature.example(for: session.deck[index])
                }
                try await save(session)
            }
            return
        case let .start(extra, mode):
            guard extra ? canStartExtraPractice : todaySessions.isEmpty else {
                throw TodayError.unavailableSession
            }
            try await libraryFeature.load()
            let verbID = extra ? (currentSession?.verbID ?? selectedVerbID) : selectedVerbID
            let deck = try libraryFeature.questions(verbID: verbID, mode: mode)
            guard let question = deck.first, let book = libraryFeature.book(for: verbID) else {
                throw LearningContentError.unavailableBook
            }
            let session = TodaySession(id: UUID(), day: today, isExtraPractice: extra,
                mode: mode, verbID: verbID, bookTitle: book.title, deck: deck, question: question)
            try await save(session)
        case .shuffleVerb where currentSession == nil:
            try await libraryFeature.load()
            selectedVerbID = try libraryFeature.differentVerb(excluding: selectedVerbID)
        default:
            guard var session = currentSession, !session.isComplete else {
                throw TodayError.unavailableSession
            }
            switch command {
            case let .answer(questionID, value):
                guard session.question.id == questionID else { throw TodayError.staleQuestion }
                guard !session.question.isResolved, session.question.choices.contains(value) else { return }
                if value == session.question.answer {
                    session.question.isAnswered = true
                    if session.question.wrongAnswers.isEmpty {
                        session.correctCount += 1
                    }
                    if session.correctCount >= TodaySession.target { session.completedAt = now() }
                } else {
                    session.question.wrongAnswers.insert(value)
                }
            case let .reveal(questionID):
                guard session.question.id == questionID else { throw TodayError.staleQuestion }
                guard !session.question.isResolved else { return }
                session.question.isRevealed = true
            case let .next(questionID):
                guard session.question.id == questionID else { throw TodayError.staleQuestion }
                guard session.question.isResolved else { throw TodayError.unresolvedQuestion }
                session.questionNumber += 1
                guard !session.deck.isEmpty else { throw LearningContentError.missingContent }
                session.question = session.deck[(session.questionNumber - 1) % session.deck.count].freshCopy()
            case .mode, .shuffleVerb:
                guard session.canChangeFocus else { throw TodayError.focusLocked }
                try await libraryFeature.load()
                let mode: LearningMode
                let verbID: String
                if case let .mode(selection) = command {
                    mode = selection
                    verbID = session.verbID
                } else {
                    mode = session.mode
                    verbID = try libraryFeature.differentVerb(excluding: session.verbID)
                }
                let deck = try libraryFeature.questions(verbID: verbID, mode: mode)
                guard let question = deck.first, let book = libraryFeature.book(for: verbID) else {
                    throw LearningContentError.unavailableBook
                }
                session.mode = mode
                session.verbID = verbID
                session.bookTitle = book.title
                session.deck = deck
                session.correctCount = 0
                session.question = question
            case .refresh, .start:
                return
            }
            try await save(session)
        }
    }

    private func save(_ session: TodaySession) async throws {
        // Publish only durable results; failed writes leave the same question ready for retry.
        try await repository.save(session)
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
        try await doubloonFeature.awardProgress(for: session)
    }

    private func reconcileProgressRewards() async throws {
        for session in sessions where session.correctCount >= 10 {
            try await doubloonFeature.awardProgress(for: session)
        }
    }
}
