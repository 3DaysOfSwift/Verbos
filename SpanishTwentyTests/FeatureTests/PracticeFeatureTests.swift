import Foundation
import Testing
@testable import SpanishTwenty

@MainActor struct PracticeFeatureTests {
    @Test func twentyAnswersFinishAndOnlyOneExtraIsAllowed() async throws {
        let env = try TestEnvironment()
        try await env.start()
        for count in 1...20 {
            try await env.answerCorrectly()
            #expect(env.practice.currentSession?.correctCount == count)
            #expect(env.practice.currentSession?.isComplete == (count == 20))
            if count < 20 {
                let question = try #require(env.practice.currentSession?.question)
                try await env.practice.perform(.next(questionID: question.id))
            }
        }
        #expect(env.practice.canStartExtraPractice)
        try await env.practice.perform(.start(extra: true, mode: .future))
        try await env.finish()
        #expect(env.practice.isDayLocked)
        #expect(env.streak.currentStreak == 1)
        #expect(env.streak.correctAnswerCount == 40)
        await #expect(throws: PracticeError.self) { try await env.practice.perform(.start(extra: true, mode: .present)) }
    }

    @Test func wrongAndRevealedAnswersNeverScore() async throws {
        let env = try TestEnvironment()
        try await env.start()
        let question = try #require(env.practice.currentSession?.question)
        let wrong = try #require(question.choices.first { $0 != question.answer })
        try await env.practice.perform(.answer(questionID: question.id, value: wrong))
        try await env.answerCorrectly()
        #expect(env.practice.currentSession?.correctCount == 0)
        #expect(env.practice.currentSession?.question.wrongAnswers.contains(wrong) == true)
        try await env.practice.perform(.next(questionID: question.id))
        let next = try #require(env.practice.currentSession?.question)
        try await env.practice.perform(.reveal(questionID: next.id))
        try await env.answerCorrectly()
        #expect(env.practice.currentSession?.correctCount == 0)
    }

    @Test func shuffleExcludesCurrentVerbAndFocusLocksAtQuestionTwo() async throws {
        let env = try TestEnvironment()
        try await env.practice.perform(.refresh)
        try await env.practice.perform(.shuffleVerb)
        #expect(env.practice.selectedVerbID != "ser")
        try await env.start()
        try await env.answerCorrectly()
        let oldVerb = try #require(env.practice.currentSession?.verbID)
        try await env.practice.perform(.shuffleVerb)
        #expect(env.practice.currentSession?.verbID != oldVerb)
        #expect(env.practice.currentSession?.correctCount == 0)
        try await env.practice.perform(.mode(.future))
        #expect(env.practice.currentSession?.mode == .future)
        try await env.answerCorrectly()
        let question = try #require(env.practice.currentSession?.question)
        try await env.practice.perform(.next(questionID: question.id))
        await #expect(throws: PracticeError.self) { try await env.practice.perform(.shuffleVerb) }
        await #expect(throws: PracticeError.self) { try await env.practice.perform(.mode(.present)) }
    }

    @Test func failedSaveIsRetryableAndDuplicateAnswersScoreOnce() async throws {
        let env = try TestEnvironment()
        try await env.start()
        await env.repository.fail(true)
        await #expect(throws: TestFailure.self) { try await env.answerCorrectly() }
        #expect(env.practice.currentSession?.correctCount == 0)
        await env.repository.fail(false)
        async let first: Void = env.answerCorrectly()
        async let duplicate: Void = env.answerCorrectly()
        try await first
        try await duplicate
        #expect(env.practice.currentSession?.correctCount == 1)
    }

    @Test func savedDeckResumesWithoutContentAndTomorrowUnlocks() async throws {
        let env = try TestEnvironment()
        try await env.start()
        try await env.answerCorrectly()
        let saved = env.practice.currentSession
        let reopened = try TestEnvironment(repository: env.repository, clock: env.clock)
        await reopened.content.fail(true)
        try await reopened.practice.perform(.refresh)
        #expect(reopened.practice.currentSession == saved)
        let question = try #require(saved?.question)
        try await reopened.practice.perform(.next(questionID: question.id))
        #expect(reopened.practice.currentSession?.questionNumber == 2)
        await reopened.content.fail(false)
        try await reopened.finish()
        try await reopened.practice.perform(.start(extra: true, mode: .future))
        try await reopened.finish()
        #expect(reopened.practice.isDayLocked)
        env.clock.date = try #require(env.calendar.date(byAdding: .day, value: 1, to: env.clock.date))
        try await reopened.practice.perform(.refresh)
        #expect(!reopened.practice.isDayLocked)
        #expect(reopened.practice.currentSession == nil)
        #expect(reopened.streak.currentStreak == 1)
    }
}
