import Foundation
import Testing
@testable import SpanishTwenty

@MainActor struct SettingsFeatureTests {
    @Test func modePersists() throws {
        let name = "SpanishTwentyTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let feature = SettingsFeature(defaults: defaults)
        #expect(feature.preferredMode == .mixed)
        feature.selectMode(.future)
        #expect(SettingsFeature(defaults: defaults).preferredMode == .future)
    }
}
