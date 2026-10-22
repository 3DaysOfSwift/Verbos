import Foundation

@MainActor
final class AppModel {
    static let shared = live()
    let practiceFeature: PracticeFeature
    let dayStreakFeature: DayStreakFeature
    let settingsFeature: SettingsFeature
    let libraryFeature: LibraryFeature
    private var didFinishLaunching: Bool

    init(practiceFeature: PracticeFeature, dayStreakFeature: DayStreakFeature, settingsFeature: SettingsFeature, libraryFeature: LibraryFeature) {
        self.practiceFeature = practiceFeature
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
        let practiceFeature = PracticeFeature(repository: repository, libraryFeature: libraryFeature)
        let dayStreakFeature = DayStreakFeature(practiceFeature: practiceFeature)
        let settingsFeature = SettingsFeature(defaults: .standard)
        return AppModel(practiceFeature: practiceFeature, dayStreakFeature: dayStreakFeature,
                        settingsFeature: settingsFeature, libraryFeature: libraryFeature)
    }

    func applicationDidFinishLaunching() {
        guard !didFinishLaunching else { return }
        didFinishLaunching = true
        // No database boot gate. Each requesting feature reports its own operation failures.
    }
}
