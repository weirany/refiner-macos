import Combine
import Foundation
import Security

protocol APIKeyStoring {
    func loadAPIKey() throws -> String?
    func saveAPIKey(_ apiKey: String) throws
    func deleteAPIKey() throws
}

struct KeychainAPIKeyStore: APIKeyStoring {
    private let service = "com.weiranye.refiner"
    private let account = "openai-api-key"

    func loadAPIKey() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard
                let data = item as? Data,
                let apiKey = String(data: data, encoding: .utf8)
            else {
                return nil
            }
            return apiKey
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unhandledStatus(status)
        }
    }

    func saveAPIKey(_ apiKey: String) throws {
        let data = Data(apiKey.utf8)
        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let attributes = [kSecValueData as String: data]
            let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unhandledStatus(updateStatus)
            }
            return
        }

        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }
    }

    func deleteAPIKey() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledStatus(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

enum KeychainError: Error {
    case unhandledStatus(OSStatus)
}

final class SettingsStore: ObservableObject {
    private enum Keys {
        static let promptTemplate = "promptTemplate"
        static let launchAtLoginEnabled = "launchAtLoginEnabled"
        static let openAIModel = "openAIModel"
    }

    static let defaultOpenAIModel = "gpt-5.4-nano"

    private let userDefaults: UserDefaults
    private let apiKeyStore: APIKeyStoring
    @Published private(set) var promptTemplate: PromptTemplate
    @Published private(set) var launchAtLoginEnabled: Bool
    @Published private(set) var openAIAPIKey: String
    @Published private(set) var openAIModel: String

    init(
        userDefaults: UserDefaults = .standard,
        apiKeyStore: APIKeyStoring = KeychainAPIKeyStore()
    ) {
        self.userDefaults = userDefaults
        self.apiKeyStore = apiKeyStore
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

        openAIAPIKey = (try? apiKeyStore.loadAPIKey()) ?? ""
        let storedModel = userDefaults.string(forKey: Keys.openAIModel)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let storedModel, !storedModel.isEmpty {
            openAIModel = storedModel
        } else {
            openAIModel = Self.defaultOpenAIModel
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

    func saveOpenAIAPIKey(_ rawValue: String) throws {
        let apiKey = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if apiKey.isEmpty {
            try apiKeyStore.deleteAPIKey()
        } else {
            try apiKeyStore.saveAPIKey(apiKey)
        }
        openAIAPIKey = apiKey
    }

    func saveOpenAIModel(_ rawValue: String) {
        let model = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedModel = model.isEmpty ? Self.defaultOpenAIModel : model
        userDefaults.set(resolvedModel, forKey: Keys.openAIModel)
        openAIModel = resolvedModel
    }

    var hasOpenAIAPIKey: Bool {
        !openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
