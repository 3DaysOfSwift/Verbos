import Foundation

@MainActor
final class AppModel {
    static let shared = live()
    let todayFeature: TodayFeature
    let dayStreakFeature: DayStreakFeature
    let settingsFeature: SettingsFeature
    let libraryFeature: LibraryFeature
    private var didFinishLaunching: Bool

    init(todayFeature: TodayFeature, dayStreakFeature: DayStreakFeature, settingsFeature: SettingsFeature, libraryFeature: LibraryFeature) {
        self.todayFeature = todayFeature
        self.dayStreakFeature = dayStreakFeature
        self.settingsFeature = settingsFeature
        self.libraryFeature = libraryFeature
        didFinishLaunching = false
    }

    static func live() -> AppModel {
        let storeURL = URL.applicationSupportDirectory
            .appending(path: "Verbos", directoryHint: .isDirectory)
            .appending(path: "Sessions.store")
        let repository = SwiftDataManager(storeURL: storeURL)
        let contentRepository = CuentivaContentRepository(
            cacheURL: storeURL.deletingLastPathComponent().appending(path: "Books.json"),
            networkingManager: NetworkingManager())
        let libraryFeature = LibraryFeature(repository: contentRepository)
        let todayFeature = TodayFeature(repository: repository, libraryFeature: libraryFeature)
        let dayStreakFeature = DayStreakFeature(todayFeature: todayFeature)
        let settingsFeature = SettingsFeature(defaults: .standard)
        return AppModel(todayFeature: todayFeature, dayStreakFeature: dayStreakFeature,
                        settingsFeature: settingsFeature, libraryFeature: libraryFeature)
    }

    func applicationDidFinishLaunching() {
        guard !didFinishLaunching else { return }
        didFinishLaunching = true
        // No database boot gate. Each requesting feature reports its own operation failures.
    }
}
