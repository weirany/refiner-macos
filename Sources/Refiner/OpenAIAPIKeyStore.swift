import Foundation
import Security

protocol OpenAIAPIKeyStoring {
    func loadAPIKey() -> String
    func saveAPIKey(_ apiKey: String)
    func deleteAPIKey()
}

final class KeychainOpenAIAPIKeyStore: OpenAIAPIKeyStoring {
    private let service: String
    private let account: String

    init(
        service: String = "com.weiranye.refiner.openai",
        account: String = "OpenAI API Key"
    ) {
        self.service = service
        self.account = account
    }

    func loadAPIKey() -> String {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard
            status == errSecSuccess,
            let data = item as? Data,
            let value = String(data: data, encoding: .utf8)
        else {
            return ""
        }

        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func saveAPIKey(_ apiKey: String) {
        let data = Data(apiKey.utf8)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemUpdate(baseQuery() as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = baseQuery()
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    func deleteAPIKey() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
