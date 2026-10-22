import Foundation
import Testing
@testable import Verbos

@MainActor struct TodayFeatureTests {
    @Test func twentyAnswersFinishAndOnlyOneExtraIsAllowed() async throws {
        let env = try TestEnvironment()
        try await env.start()
        for count in 1...20 {
            try await env.answerCorrectly()
            #expect(env.today.currentSession?.correctCount == count)
            #expect(env.today.currentSession?.isComplete == (count == 20))
            if count < 20 {
                let question = try #require(env.today.currentSession?.question)
                try await env.today.perform(.next(questionID: question.id))
            }
        }
        #expect(env.today.canStartExtraPractice)
        try await env.today.perform(.start(extra: true, mode: .future))
        try await env.finish()
        #expect(env.today.isDayLocked)
        #expect(env.streak.currentStreak == 1)
        #expect(env.streak.correctAnswerCount == 40)
        await #expect(throws: TodayError.self) { try await env.today.perform(.start(extra: true, mode: .present)) }
    }

    @Test func wrongAndRevealedAnswersNeverScore() async throws {
        let env = try TestEnvironment()
        try await env.start()
        let question = try #require(env.today.currentSession?.question)
        let wrong = try #require(question.choices.first { $0 != question.answer })
        try await env.today.perform(.answer(questionID: question.id, value: wrong))
        try await env.answerCorrectly()
        #expect(env.today.currentSession?.correctCount == 0)
        #expect(env.today.currentSession?.question.wrongAnswers.contains(wrong) == true)
        try await env.today.perform(.next(questionID: question.id))
        let next = try #require(env.today.currentSession?.question)
        try await env.today.perform(.reveal(questionID: next.id))
        try await env.answerCorrectly()
        #expect(env.today.currentSession?.correctCount == 0)
    }

    @Test func shuffleExcludesCurrentVerbAndFocusLocksAtQuestionTwo() async throws {
        let env = try TestEnvironment()
        try await env.today.perform(.refresh)
        try await env.today.perform(.shuffleVerb)
        #expect(env.today.selectedVerbID != "ser")
        try await env.start()
        try await env.answerCorrectly()
        let oldVerb = try #require(env.today.currentSession?.verbID)
        try await env.today.perform(.shuffleVerb)
        #expect(env.today.currentSession?.verbID != oldVerb)
        #expect(env.today.currentSession?.correctCount == 0)
        try await env.today.perform(.mode(.future))
        #expect(env.today.currentSession?.mode == .future)
        try await env.answerCorrectly()
        let question = try #require(env.today.currentSession?.question)
        try await env.today.perform(.next(questionID: question.id))
        await #expect(throws: TodayError.self) { try await env.today.perform(.shuffleVerb) }
        await #expect(throws: TodayError.self) { try await env.today.perform(.mode(.present)) }
    }

    @Test func failedSaveIsRetryableAndDuplicateAnswersScoreOnce() async throws {
        let env = try TestEnvironment()
        try await env.start()
        await env.repository.fail(true)
        await #expect(throws: TestFailure.self) { try await env.answerCorrectly() }
        #expect(env.today.currentSession?.correctCount == 0)
        await env.repository.fail(false)
        async let first: Void = env.answerCorrectly()
        async let duplicate: Void = env.answerCorrectly()
        try await first
        try await duplicate
        #expect(env.today.currentSession?.correctCount == 1)
    }

    @Test func savedDeckResumesWithoutContentAndTomorrowUnlocks() async throws {
        let env = try TestEnvironment()
        try await env.start()
        try await env.answerCorrectly()
        let saved = env.today.currentSession
        let reopened = try TestEnvironment(repository: env.repository, clock: env.clock)
        await reopened.content.fail(true)
        try await reopened.today.perform(.refresh)
        #expect(reopened.today.currentSession == saved)
        let question = try #require(saved?.question)
        try await reopened.today.perform(.next(questionID: question.id))
        #expect(reopened.today.currentSession?.questionNumber == 2)
        await reopened.content.fail(false)
        try await reopened.finish()
        try await reopened.today.perform(.start(extra: true, mode: .future))
        try await reopened.finish()
        #expect(reopened.today.isDayLocked)
        env.clock.date = try #require(env.calendar.date(byAdding: .day, value: 1, to: env.clock.date))
        try await reopened.today.perform(.refresh)
        #expect(!reopened.today.isDayLocked)
        #expect(reopened.today.currentSession == nil)
        #expect(reopened.streak.currentStreak == 1)
    }
}
