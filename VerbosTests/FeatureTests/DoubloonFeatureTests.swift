import Foundation
import Testing
@testable import Verbos

@MainActor struct DoubloonFeatureTests {
    @Test func completedDailySessionAwardsTwoDoubloonsAndUnlocksOneBookUntilTomorrow() async throws {
        let environment = try TestEnvironment()
        try await environment.start()
        try await environment.finish()

        #expect(environment.doubloons.balance == 2)
        try await environment.doubloons.unlockDailyBook(id: "verb-ser", on: environment.clock.date)
        #expect(environment.doubloons.balance == 1)
        #expect(environment.doubloons.unlockedBookID(for: environment.clock.date) == "verb-ser")

        environment.clock.date = try #require(environment.calendar.date(byAdding: .day, value: 1, to: environment.clock.date))
        #expect(environment.doubloons.unlockedBookID(for: environment.clock.date) == nil)
    }

    @Test func extraPracticeAwardsItsOwnTwoMilestones() async throws {
        let environment = try TestEnvironment()
        try await environment.start()
        try await environment.finish()
        try await environment.today.perform(.start(extra: true, mode: .mixed))
        try await environment.finish()

        #expect(environment.doubloons.balance == 4)
    }

    @Test func tenthAnswerAwardsOnceAcrossDuplicatesAndRelaunch() async throws {
        let env = try TestEnvironment()
        try await env.start()
        for _ in 0..<9 {
            try await env.answerCorrectly()
            let question = try #require(env.today.currentSession?.question)
            try await env.today.perform(.next(questionID: question.id))
        }
        #expect(env.doubloons.balance == 0)
        let question = try #require(env.today.currentSession?.question)
        try await env.answerCorrectly()
        #expect(env.doubloons.balance == 1)
        async let first: Void = env.today.perform(.answer(questionID: question.id, value: question.answer))
        async let duplicate: Void = env.today.perform(.answer(questionID: question.id, value: question.answer))
        try await first
        try await duplicate
        #expect(env.doubloons.balance == 1)
        let resumed = try TestEnvironment(repository: env.repository, clock: env.clock)
        try await resumed.today.perform(.refresh)
        #expect(resumed.doubloons.balance == 1)
        #expect(resumed.today.currentSession?.correctCount == 10)
    }

    @Test func failedCoinSaveRecoversFromSavedProgress() async throws {
        let env = try TestEnvironment()
        try await env.start()
        for _ in 0..<9 {
            try await env.answerCorrectly()
            let question = try #require(env.today.currentSession?.question)
            try await env.today.perform(.next(questionID: question.id))
        }
        await env.repository.failWalletSave(true)
        await #expect(throws: TestFailure.self) { try await env.answerCorrectly() }
        #expect(env.today.currentSession?.correctCount == 10)
        #expect(env.doubloons.balance == 0)
        await env.repository.failWalletSave(false)
        try await env.today.perform(.refresh)
        try await env.today.perform(.refresh)
        #expect(env.doubloons.balance == 1)
    }

    @Test func legacyCompletionCoinCountsTowardNewMilestones() async throws {
        let env = try TestEnvironment()
        try await env.start()
        try await env.finish()
        let day = env.calendar.startOfDay(for: env.clock.date)
        let legacy = "{\"balance\":1,\"rewardedDays\":[\(day.timeIntervalSinceReferenceDate)]}"
        let wallet = try JSONDecoder().decode(DoubloonWallet.self, from: Data(legacy.utf8))
        try await env.repository.saveDoubloonWallet(wallet)
        let resumed = try TestEnvironment(repository: env.repository, clock: env.clock)
        try await resumed.today.perform(.refresh)
        try await resumed.today.perform(.refresh)
        #expect(resumed.doubloons.balance == 2)
    }
}
