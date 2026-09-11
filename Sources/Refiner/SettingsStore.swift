import Combine
import Foundation

final class SettingsStore: ObservableObject {
    private enum Keys {
        static let promptTemplate = "promptTemplate"
        static let launchAtLoginEnabled = "launchAtLoginEnabled"
        static let openAIModel = "openAIModel"
        static let keyboardShortcut = "keyboardShortcut"
    }

    static let defaultOpenAIModel = "gpt-5.6-luna"
    private static let legacyDefaultOpenAIModel = "gpt-5.4-nano"

    private let userDefaults: UserDefaults
    private let openAIAPIKeyStore: OpenAIAPIKeyStoring
    @Published private(set) var promptTemplate: PromptTemplate
    @Published private(set) var launchAtLoginEnabled: Bool
    @Published private(set) var openAIAPIKey: String
    @Published private(set) var openAIModel: String
    @Published private(set) var keyboardShortcut: RefinerKeyboardShortcut

    init(
        userDefaults: UserDefaults = .standard,
        openAIAPIKeyStore: OpenAIAPIKeyStoring = KeychainOpenAIAPIKeyStore()
    ) {
        self.userDefaults = userDefaults
        self.openAIAPIKeyStore = openAIAPIKeyStore
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

        openAIAPIKey = openAIAPIKeyStore.loadAPIKey()
        let storedModel = userDefaults.string(forKey: Keys.openAIModel)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if storedModel == Self.legacyDefaultOpenAIModel {
            openAIModel = Self.defaultOpenAIModel
            userDefaults.set(Self.defaultOpenAIModel, forKey: Keys.openAIModel)
        } else if let storedModel, !storedModel.isEmpty {
            openAIModel = storedModel
        } else {
            openAIModel = Self.defaultOpenAIModel
        }

        if let shortcutData = userDefaults.data(forKey: Keys.keyboardShortcut),
           let shortcut = try? JSONDecoder().decode(RefinerKeyboardShortcut.self, from: shortcutData) {
            keyboardShortcut = shortcut
        } else {
            keyboardShortcut = .defaultShortcut
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

    func saveOpenAIAPIKey(_ rawValue: String) {
        let apiKey = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if apiKey.isEmpty {
            openAIAPIKeyStore.deleteAPIKey()
        } else {
            openAIAPIKeyStore.saveAPIKey(apiKey)
        }
        openAIAPIKey = apiKey
    }

    func saveOpenAIModel(_ rawValue: String) {
        let model = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedModel = model.isEmpty ? Self.defaultOpenAIModel : model
        userDefaults.set(resolvedModel, forKey: Keys.openAIModel)
        openAIModel = resolvedModel
    }

    func saveKeyboardShortcut(_ shortcut: RefinerKeyboardShortcut) {
        guard let data = try? JSONEncoder().encode(shortcut) else {
            return
        }

        userDefaults.set(data, forKey: Keys.keyboardShortcut)
        keyboardShortcut = shortcut
    }

    func restoreDefaultKeyboardShortcut() {
        saveKeyboardShortcut(.defaultShortcut)
    }

    var hasOpenAIAPIKey: Bool {
        !openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
