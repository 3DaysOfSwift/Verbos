import Foundation
import Testing
@testable import SpanishTwenty

@MainActor struct PracticeViewModelTests {
    @Test func revealAdvancesAfterFeedbackWithoutScoring() async throws {
        let env = try TestEnvironment()
        let name = "SpanishTwentyTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let model = PracticeViewModel(practiceFeature: env.practice, dayStreakFeature: env.streak,
                                      settingsFeature: SettingsFeature(defaults: defaults))
        await model.perform(.start(extra: false, mode: .mixed)).value
        #expect(model.isSessionInProgress)
        let question = try #require(model.session?.question)
        await model.perform(.reveal(questionID: question.id)).value
        let started = ContinuousClock.now
        async let first: Void = model.advanceAfterFeedback()
        async let duplicate: Void = model.advanceAfterFeedback()
        await first
        await duplicate
        #expect(started.duration(to: .now) >= .seconds(2))
        #expect(model.session?.questionNumber == 2)
        #expect(model.session?.correctCount == 0)
        #expect(model.session?.question.isResolved == false)
    }
}
