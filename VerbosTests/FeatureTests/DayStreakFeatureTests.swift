import Testing
@testable import Verbos

@MainActor struct DayStreakFeatureTests {
    @Test func completedDailySessionProducesOneStreakDay() async throws {
        let env = try TestEnvironment()
        try await env.start()
        try await env.finish()
        #expect(env.streak.currentStreak == 1)
        #expect(env.streak.longestStreak == 1)
        #expect(env.streak.completedDayCount == 1)
        #expect(env.streak.week.count == 7)
    }
}
