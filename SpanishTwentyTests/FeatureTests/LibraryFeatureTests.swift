import Testing
@testable import SpanishTwenty

@MainActor struct LibraryFeatureTests {
    @Test func sameSourceContainsThreeSupportedBooksAndValidClouds() async throws {
        let env = try TestEnvironment()
        async let first: Void = env.library.load()
        async let second: Void = env.library.load()
        try await first
        try await second
        #expect(await env.content.loadCount == 1)
        #expect(Set(env.library.supportedBooks.compactMap { $0.verbFocus?.infinitive }) == ["ser", "estar", "querer"])
        for book in env.library.supportedBooks {
            let verbID = try #require(book.verbFocus?.infinitive)
            for mode in LearningMode.allCases {
                let deck = try env.library.questions(verbID: verbID, mode: mode)
                #expect(deck.count == (mode == .mixed ? 18 : 6))
                for question in deck {
                    #expect(question.choices.count == 9)
                    #expect(Set(question.choices).count == 9)
                    #expect(question.choices.filter { $0 == question.answer }.count == 1)
                    #expect(!question.person.isEmpty)
                    #expect(mode.tenses.contains(question.tense))
                }
            }
        }
    }
    @Test func translationsDistinguishTensePersonAndAmbiguousForms() throws {
        let content = try ContentFixtures.load()
        let ser = try #require(content.verbs.first { $0.id == "ser" })
        #expect(try ConjugationQuestions.translation(verb: ser, tense: .preterite, person: 0) == "I was")
        #expect(try ConjugationQuestions.translation(verb: ser, tense: .future, person: 0) == "I will be")
        #expect(try ConjugationQuestions.translation(verb: ser, tense: .imperfect, person: 0) == "I used to be")
        let future = try ConjugationQuestions.make(verb: ser, mode: .future)
        #expect(future.contains { $0.spanish == "seréis" && $0.answer == "You (plural) will be" })
    }
    @Test func failedUpdateRetainsBooks() async throws {
        let env = try TestEnvironment()
        try await env.library.load()
        let titles = env.library.books.map(\.title)
        await env.content.fail(true)
        await env.library.refreshBooks()
        #expect(env.library.refreshError != nil)
        #expect(env.library.books.map(\.title) == titles)
    }
}
