import Combine
import Foundation

@MainActor
final class AvailabilityMonitor: ObservableObject {
    @Published private(set) var state: RewriteAvailabilityState = .available

    private let settingsStore: SettingsStore

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    func refresh() {
        state = settingsStore.hasOpenAIAPIKey ? .available : .missingAPIKey
    }
}
