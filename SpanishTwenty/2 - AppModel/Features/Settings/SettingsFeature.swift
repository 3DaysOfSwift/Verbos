import Foundation
import Observation

@MainActor @Observable
final class SettingsFeature {
    private(set) var preferredMode: LearningMode
    private let defaults: UserDefaults
    let version: String

    init(defaults: UserDefaults, bundle: Bundle = .main) {
        self.defaults = defaults
        preferredMode = LearningMode(rawValue: defaults.string(forKey: "preferredMode") ?? "") ?? .mixed
        let number = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        version = "Version \(number) (\(build))"
    }

    func selectMode(_ mode: LearningMode) {
        preferredMode = mode
        defaults.set(mode.rawValue, forKey: "preferredMode")
    }
}
