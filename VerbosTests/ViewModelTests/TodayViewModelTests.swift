import Foundation
import Testing
@testable import Verbos

@MainActor struct TodayViewModelTests {
    @Test func loadsAccountBalanceAndReflectsBookSpending() async throws {
        let env = try TestEnvironment()
        var wallet = DoubloonWallet()
        wallet.balance = 7
        try await env.repository.saveDoubloonWallet(wallet)
        let name = "VerbosTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let model = TodayViewModel(todayFeature: env.today, dayStreakFeature: env.streak,
                                  settingsFeature: SettingsFeature(defaults: defaults), doubloonFeature: env.doubloons)
        await model.refresh().value
        #expect(model.errorMessage == nil)
        #expect(model.doubloonBalance == 7)
        try await env.doubloons.unlockDailyBook(id: "verb-ser", on: env.clock.date)
        #expect(model.doubloonBalance == 6)
    }

    @Test func cancelReturnsToTodayAndResumeKeepsSavedProgress() async throws {
        let env = try TestEnvironment()
        let name = "VerbosTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let model = TodayViewModel(todayFeature: env.today, dayStreakFeature: env.streak,
                                  settingsFeature: SettingsFeature(defaults: defaults), doubloonFeature: env.doubloons)
        await model.perform(.start(extra: false, mode: .mixed)).value
        let sessionID = try #require(model.session?.id)
        let question = try #require(model.session?.question)
        await model.perform(.answer(questionID: question.id, value: question.answer)).value
        model.cancelPractice()
        #expect(model.isSessionPaused)
        #expect(!model.isSessionInProgress)
        #expect(model.questionAwaitingAdvanceID == nil)
        #expect(model.canStartOrResume)
        await model.advanceAfterFeedback()
        await model.refresh().value
        #expect(model.isSessionPaused)
        #expect(model.session?.question.id == question.id)
        #expect(model.session?.correctCount == 1)
        model.startOrResumePractice()
        #expect(model.isSessionInProgress)
        #expect(!model.isSessionPaused)
        #expect(model.session?.id == sessionID)
        #expect(model.session?.correctCount == 1)
        await model.advanceAfterFeedback()
        #expect(model.session?.questionNumber == 2)
        #expect(model.session?.correctCount == 1)
        #expect(env.today.todaySessions.count == 1)
    }

    @Test func revealAdvancesAfterFeedbackWithoutScoring() async throws {
        let env = try TestEnvironment()
        let name = "VerbosTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let model = TodayViewModel(todayFeature: env.today, dayStreakFeature: env.streak,
                                      settingsFeature: SettingsFeature(defaults: defaults), doubloonFeature: env.doubloons)
        await model.perform(.start(extra: false, mode: .mixed)).value
        #expect(model.isSessionInProgress)
        let question = try #require(model.session?.question)
        #expect(model.spanishExample != nil)
        #expect(model.exampleTranslation == nil)
        await model.perform(.reveal(questionID: question.id)).value
        #expect(model.exampleTranslation == question.example?.english)
        let started = ContinuousClock.now
        async let first: Void = model.advanceAfterFeedback()
        async let duplicate: Void = model.advanceAfterFeedback()
        await first
        await duplicate
        #expect(started.duration(to: .now) >= .seconds(3))
        #expect(model.session?.questionNumber == 2)
        #expect(model.session?.correctCount == 0)
        #expect(model.session?.question.isResolved == false)
    }

    @Test func milestonesPauseBeforeNextQuestionAndCompletion() async throws {
        let env = try TestEnvironment()
        let name = "VerbosTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let model = TodayViewModel(todayFeature: env.today, dayStreakFeature: env.streak,
                                  settingsFeature: SettingsFeature(defaults: defaults), doubloonFeature: env.doubloons)
        await model.perform(.start(extra: false, mode: .mixed)).value
        for count in 1...20 {
            let question = try #require(model.session?.question)
            await model.perform(.answer(questionID: question.id, value: question.answer)).value
            if count.isMultiple(of: 10) {
                #expect(model.celebrationCorrectCount == count)
                #expect(model.sessionDoubloonsEarned == count / 10)
                #expect(model.feedbackDelay == .seconds(5))
                #expect(model.isSessionInProgress)
                await model.advanceAfterFeedback()
                #expect(model.celebrationCorrectCount == nil)
            } else {
                #expect(model.celebrationCorrectCount == nil)
                #expect(model.feedbackDelay == .seconds(3))
                await model.perform(.next(questionID: question.id)).value
            }
        }
        #expect(model.session?.isComplete == true)
        #expect(!model.isSessionInProgress)
        #expect(model.sessionDoubloonsEarned == 2)
    }
}
