import Testing
@testable import SpanishTwenty

@MainActor struct BookViewModelTests {
    @Test func bookLoadsAndUpdateFailureIsVisible() async throws {
        let env = try TestEnvironment()
        let model = BookViewModel(libraryFeature: env.library)
        await model.refresh().value
        #expect(model.book(for: "ser")?.id == "verb-ser")
        #expect(!model.isRefreshing)
        await env.content.fail(true)
        await model.refresh(download: true).value
        #expect(model.errorMessage != nil)
        #expect(model.book(for: "ser") != nil)
    }
}
