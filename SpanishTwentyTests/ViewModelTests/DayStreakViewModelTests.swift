import Testing
@testable import SpanishTwenty

@MainActor struct DayStreakViewModelTests {
    @Test func readsSameSavedProgress() async throws {
        let env = try TestEnvironment()
        let model = DayStreakViewModel(dayStreakFeature: env.streak)
        try await env.start()
        try await env.finish()
        #expect(model.currentStreak == 1)
        #expect(model.correctAnswerCount == 20)
        #expect(model.completedDates.count == 1)
    }
}
