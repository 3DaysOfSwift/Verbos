import Foundation
import Observation

@MainActor @Observable
final class TodayViewModel {
    private let todayFeature: TodayFeature
    private let dayStreakFeature: DayStreakFeature
    private let settingsFeature: SettingsFeature
    private let doubloonFeature: DoubloonFeature
    private(set) var errorMessage: String?
    private(set) var celebrationCorrectCount: Int?
    private(set) var isSavingAnswer = false
    private var pausedSessionID: UUID?
    @ObservationIgnored private var queuedCommandTask: Task<Void, Never>?
    @ObservationIgnored private var pendingCommandTasks: [TodayFeature.Command: Task<Void, Never>] = [:]
    @ObservationIgnored private var lastCommandID: UUID?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var automaticAdvanceTask: Task<Void, Never>?
    @ObservationIgnored private var automaticAdvanceID: UUID?
    @ObservationIgnored private var scheduledQuestionID: UUID?
    @ObservationIgnored private var retryCommand: TodayFeature.Command = .refresh

    init(todayFeature: TodayFeature = AppModel.shared.todayFeature,
         dayStreakFeature: DayStreakFeature = AppModel.shared.dayStreakFeature,
         settingsFeature: SettingsFeature = AppModel.shared.settingsFeature,
         doubloonFeature: DoubloonFeature = AppModel.shared.doubloonFeature) {
        self.todayFeature = todayFeature
        self.dayStreakFeature = dayStreakFeature
        self.settingsFeature = settingsFeature
        self.doubloonFeature = doubloonFeature
    }

    var session: TodaySession? { todayFeature.currentSession }
    var spanishExample: AttributedString? {
        guard let question = session?.question, let example = question.example else { return nil }
        var conjugation = AttributedString(question.spanish)
        conjugation.inlinePresentationIntent = .stronglyEmphasized
        return AttributedString(question.person.capitalized + " ") + conjugation
            + AttributedString(" " + example.spanishEnding)
    }
    var exampleTranslation: String? {
        guard let question = session?.question, question.isResolved else { return nil }
        return question.example?.english
    }
    var isSessionInProgress: Bool {
        if let session, pausedSessionID == session.id { return false }
        return session?.isComplete == false || celebrationCorrectCount != nil || isSavingAnswer
    }
    var isSessionPaused: Bool { session?.isComplete == false && session?.id == pausedSessionID }
    var canStartOrResume: Bool { isSessionPaused || isSelectedVerbReady }
    var playAccessibilityLabel: String {
        isSessionPaused ? "Resume saved practice" : "Start 20 questions about \(selectedVerbID)"
    }
    var practiceSummary: String {
        if isSessionPaused, let session {
            return "\(session.correctCount) of \(TodaySession.target) correct. Your progress is saved."
        }
        return "Practice one verb twenty times each day."
    }
    var feedbackDelay: Duration { celebrationCorrectCount == nil ? .seconds(3) : .seconds(5) }
    var questionAwaitingAdvanceID: UUID? {
        guard isSessionInProgress, !isSavingAnswer, errorMessage == nil, let session,
              !session.isComplete || celebrationCorrectCount != nil,
              session.question.isResolved else { return nil }
        return session.question.id
    }
    var hasLoaded: Bool { todayFeature.hasLoaded }
    var doubloonBalance: Int { doubloonFeature.balance }
    var isSelectedVerbReady: Bool { todayFeature.isSelectedVerbReady }
    var canStartExtraPractice: Bool { todayFeature.canStartExtraPractice }
    var isDayLocked: Bool { todayFeature.isDayLocked }
    var streak: Int { dayStreakFeature.currentStreak }
    var week: [StreakDay] { dayStreakFeature.week }
    var selectedVerbID: String { session?.verbID ?? todayFeature.selectedVerbID }
    var preferredMode: LearningMode { settingsFeature.preferredMode }
    var sessionDoubloonsEarned: Int {
        guard let session else { return 0 }
        return doubloonFeature.earnedDoubloons(for: session.id)
    }
    var feedback: String {
        guard let question = session?.question else { return "" }
        if question.isRevealed { return "Answer revealed. This question earns no point." }
        if question.isAnswered {
            return question.wrongAnswers.isEmpty ? "That's right. One point earned!" : "You've found it! No point this time—keep going."
        }
        if !question.wrongAnswers.isEmpty { return "Not quite. Try another answer. This question won't earn a point." }
        return "Tap the question to reveal the answer."
    }

    func selectMode(_ mode: LearningMode) { settingsFeature.selectMode(mode) }

    func cancelPractice() {
        pausedSessionID = session?.id
        automaticAdvanceTask?.cancel()
        celebrationCorrectCount = nil
    }

    func startOrResumePractice() {
        if isSessionPaused {
            pausedSessionID = nil
        } else {
            perform(.start(extra: false, mode: preferredMode))
        }
    }

    @discardableResult
    func refresh() -> Task<Void, Never> {
        if let refreshTask { return refreshTask }
        let task = Task { @MainActor in
            defer { refreshTask = nil }
            do {
                try await doubloonFeature.load()
                try await todayFeature.perform(.refresh)
            }
            catch {
                retryCommand = .refresh
                errorMessage = error.localizedDescription
            }
        }
        refreshTask = task
        return task
    }

    @discardableResult
    func perform(_ command: TodayFeature.Command) -> Task<Void, Never> {
        if let task = pendingCommandTasks[command] { return task }
        let predecessor = queuedCommandTask
        let identifier = UUID()
        let task = Task { @MainActor in
            await predecessor?.value
            defer {
                pendingCommandTasks[command] = nil
                if lastCommandID == identifier {
                    queuedCommandTask = nil
                    lastCommandID = nil
                }
            }
            errorMessage = nil
            retryCommand = command
            if case .next = command, isSessionPaused { return }
            let previousCorrectCount = session?.correctCount ?? 0
            if case .answer = command { isSavingAnswer = true }
            defer { isSavingAnswer = false }
            do {
                try await todayFeature.perform(command)
                if case .answer = command, let session, pausedSessionID != session.id,
                   session.correctCount > previousCorrectCount,
                   session.correctCount.isMultiple(of: 10),
                   sessionDoubloonsEarned >= session.correctCount / 10 {
                    celebrationCorrectCount = session.correctCount
                }
            }
            catch { errorMessage = error.localizedDescription }
        }
        queuedCommandTask = task
        pendingCommandTasks[command] = task
        lastCommandID = identifier
        return task
    }

    // This delay belongs to the visible question, not to the durable save operation.
    func advanceAfterFeedback() async {
        guard let questionID = questionAwaitingAdvanceID else { return }
        if let task = automaticAdvanceTask, scheduledQuestionID == questionID, !task.isCancelled {
            await withTaskCancellationHandler {
                await task.value
            } onCancel: {
                task.cancel()
            }
            return
        }

        automaticAdvanceTask?.cancel()
        let identifier = UUID()
        let task = Task { @MainActor in
            do {
                try await Task.sleep(for: feedbackDelay)
                try Task.checkCancellation()
                guard questionAwaitingAdvanceID == questionID else { return }
                if session?.isComplete == true {
                    celebrationCorrectCount = nil
                } else {
                    await perform(.next(questionID: questionID)).value
                    if errorMessage == nil { celebrationCorrectCount = nil }
                }
            } catch {
                // Leaving the screen cancels only feedback timing; saved progress is untouched.
            }
        }
        automaticAdvanceTask = task
        automaticAdvanceID = identifier
        scheduledQuestionID = questionID
        defer {
            if automaticAdvanceID == identifier {
                automaticAdvanceTask = nil
                automaticAdvanceID = nil
                scheduledQuestionID = nil
            }
        }
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    func retry() { perform(retryCommand) }
}
