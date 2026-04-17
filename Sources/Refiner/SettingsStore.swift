import Combine
import Foundation

final class SettingsStore: ObservableObject {
    private enum Keys {
        static let promptTemplate = "promptTemplate"
        static let launchAtLoginEnabled = "launchAtLoginEnabled"
    }

    private let userDefaults: UserDefaults
    @Published private(set) var promptTemplate: PromptTemplate
    @Published private(set) var launchAtLoginEnabled: Bool

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if userDefaults.object(forKey: Keys.launchAtLoginEnabled) == nil {
            launchAtLoginEnabled = true
            userDefaults.set(true, forKey: Keys.launchAtLoginEnabled)
        } else {
            launchAtLoginEnabled = userDefaults.bool(forKey: Keys.launchAtLoginEnabled)
        }

        let storedValue = userDefaults.string(forKey: Keys.promptTemplate)
        if let storedValue, let template = try? PromptTemplate(rawValue: storedValue) {
            promptTemplate = template
        } else {
            promptTemplate = try! PromptTemplate(rawValue: PromptTemplate.defaultValue)
        }
    }

    func savePromptTemplate(_ rawValue: String) throws {
        let template = try PromptTemplate(rawValue: rawValue)
        userDefaults.set(rawValue, forKey: Keys.promptTemplate)
        promptTemplate = template
    }

    func setLaunchAtLoginEnabled(_ isEnabled: Bool) {
        userDefaults.set(isEnabled, forKey: Keys.launchAtLoginEnabled)
        launchAtLoginEnabled = isEnabled
    }
}
