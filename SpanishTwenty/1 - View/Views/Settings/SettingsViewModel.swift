import Observation

@MainActor @Observable
final class SettingsViewModel {
    private let settingsFeature: SettingsFeature

    init(settingsFeature: SettingsFeature = AppModel.shared.settingsFeature) {
        self.settingsFeature = settingsFeature
    }

    var preferredMode: LearningMode { settingsFeature.preferredMode }
    var version: String { settingsFeature.version }
    func selectMode(_ mode: LearningMode) { settingsFeature.selectMode(mode) }
}
