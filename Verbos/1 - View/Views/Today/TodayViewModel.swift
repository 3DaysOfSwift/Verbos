import Foundation
import Observation

@MainActor @Observable
final class TodayViewModel {
    private let todayFeature: TodayFeature
    private let dayStreakFeature: DayStreakFeature
    private let settingsFeature: SettingsFeature
    private(set) var errorMessage: String?
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
         settingsFeature: SettingsFeature = AppModel.shared.settingsFeature) {
        self.todayFeature = todayFeature
        self.dayStreakFeature = dayStreakFeature
        self.settingsFeature = settingsFeature
    }

    var session: TodaySession? { todayFeature.currentSession }
    var isSessionInProgress: Bool { session?.isComplete == false }
    var questionAwaitingAdvanceID: UUID? {
        guard let session, !session.isComplete, session.question.isResolved else { return nil }
        return session.question.id
    }
    var hasLoaded: Bool { todayFeature.hasLoaded }
    var isSelectedVerbReady: Bool { todayFeature.isSelectedVerbReady }
    var canStartExtraPractice: Bool { todayFeature.canStartExtraPractice }
    var isDayLocked: Bool { todayFeature.isDayLocked }
    var streak: Int { dayStreakFeature.currentStreak }
    var week: [StreakDay] { dayStreakFeature.week }
    var selectedVerbID: String { session?.verbID ?? todayFeature.selectedVerbID }
    var preferredMode: LearningMode { settingsFeature.preferredMode }
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

    @discardableResult
    func refresh() -> Task<Void, Never> {
        if let refreshTask { return refreshTask }
        let task = Task { @MainActor in
            defer { refreshTask = nil }
            do { try await todayFeature.perform(.refresh) }
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
            do { try await todayFeature.perform(command) }
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
                try await Task.sleep(for: .seconds(2))
                try Task.checkCancellation()
                guard questionAwaitingAdvanceID == questionID else { return }
                await perform(.next(questionID: questionID)).value
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
