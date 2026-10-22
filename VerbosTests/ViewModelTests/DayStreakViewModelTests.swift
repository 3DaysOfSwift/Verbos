import Testing
@testable import Verbos

@MainActor struct DayStreakViewModelTests {
    @Test func readsSameSavedProgress() async throws {
        let env = try TestEnvironment()
        let model = DayStreakViewModel(dayStreakFeature: env.streak, doubloonFeature: env.doubloons)
        try await env.start()
        try await env.finish()
        #expect(model.currentStreak == 1)
        #expect(model.correctAnswerCount == 20)
        #expect(model.completedDates.count == 1)
        #expect(model.doubloonBalance == 2)
        try await env.doubloons.unlockDailyBook(id: "verb-ser", on: env.clock.date)
        #expect(model.doubloonBalance == 1)
    }

    @Test func loadsSavedBalanceBeforeAnyPractice() async throws {
        let env = try TestEnvironment()
        var wallet = DoubloonWallet()
        wallet.balance = 7
        try await env.repository.saveDoubloonWallet(wallet)
        let model = DayStreakViewModel(dayStreakFeature: env.streak, doubloonFeature: env.doubloons)
        await model.refresh().value
        #expect(model.errorMessage == nil)
        #expect(model.doubloonBalance == 7)
    }
}
