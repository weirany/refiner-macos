import Combine
import Foundation

final class SettingsStore: ObservableObject {
    private enum Keys {
        static let promptTemplate = "promptTemplate"
    }

    private let userDefaults: UserDefaults
    @Published private(set) var promptTemplate: PromptTemplate

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

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
}
