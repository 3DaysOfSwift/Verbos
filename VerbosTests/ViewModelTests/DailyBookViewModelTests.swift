import Testing
@testable import Verbos

@MainActor struct DailyBookViewModelTests {
    @Test func readsTheBookForTheSelectedTodayVerb() async throws {
        let environment = try TestEnvironment()
        let model = DailyBookViewModel(todayFeature: environment.today, libraryFeature: environment.library)

        await model.refresh().value

        #expect(model.verbID == "ser")
        #expect(model.book?.id == "verb-ser")
    }
}
