import Foundation
import Testing
@testable import SpanishTwenty

@MainActor struct SettingsViewModelTests {
    @Test func selectionUpdatesFeature() throws {
        let name = "SpanishTwentyTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let feature = SettingsFeature(defaults: defaults)
        let model = SettingsViewModel(settingsFeature: feature)
        model.selectMode(.preterite)
        #expect(feature.preferredMode == .preterite)
        #expect(model.preferredMode == .preterite)
    }
}
