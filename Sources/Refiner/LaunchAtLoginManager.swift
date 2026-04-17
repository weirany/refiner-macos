import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginManager: ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published private(set) var statusMessage = ""

    private let settingsStore: SettingsStore
    private let service: SMAppService

    init(
        settingsStore: SettingsStore,
        service: SMAppService = .mainApp
    ) {
        self.settingsStore = settingsStore
        self.service = service
        self.isEnabled = settingsStore.launchAtLoginEnabled
        refreshStatus()
    }

    func applyStoredPreference() {
        setEnabled(settingsStore.launchAtLoginEnabled, persistPreference: false)
    }

    func setEnabled(_ enabled: Bool, persistPreference: Bool = true) {
        if persistPreference {
            settingsStore.setLaunchAtLoginEnabled(enabled)
        }

        isEnabled = enabled

        do {
            if enabled {
                if service.status != .enabled {
                    try service.register()
                }
            } else if service.status == .enabled || service.status == .requiresApproval {
                try service.unregister()
            }
        } catch {
            statusMessage = "Launch at login could not be updated: \(error.localizedDescription)"
            refreshStatus()
            return
        }

        refreshStatus()
    }

    func refreshStatus() {
        isEnabled = settingsStore.launchAtLoginEnabled

        switch service.status {
        case .enabled:
            statusMessage = "Refiner is set to launch automatically when you log in."
        case .requiresApproval:
            statusMessage = "Launch at login requires approval in System Settings > General > Login Items."
        case .notRegistered:
            statusMessage = isEnabled
                ? "Launch at login is requested, but this copy of Refiner is not currently registered."
                : "Launch at login is off."
        case .notFound:
            statusMessage = "Launch at login is unavailable for this build. Use the packaged app bundle."
        @unknown default:
            statusMessage = "Launch at login status is unavailable."
        }
    }
}
