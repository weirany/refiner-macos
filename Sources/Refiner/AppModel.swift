import Foundation

@MainActor
final class AppModel {
    static let shared = AppModel()

    let settingsStore: SettingsStore
    let launchAtLoginManager: LaunchAtLoginManager
    let availabilityMonitor: AvailabilityMonitor
    let statusNotifier: StatusNotifier
    let textService: AccessibilityTextService
    let rewriteService: OpenAIRewriteService
    let hotkeyManager: HotkeyManager

    private init() {
        settingsStore = SettingsStore()
        launchAtLoginManager = LaunchAtLoginManager(settingsStore: settingsStore)
        availabilityMonitor = AvailabilityMonitor(settingsStore: settingsStore)
        statusNotifier = StatusNotifier()
        textService = AccessibilityTextService()
        rewriteService = OpenAIRewriteService(settingsStore: settingsStore)
        hotkeyManager = HotkeyManager()
        launchAtLoginManager.applyStoredPreference()
    }

    func refreshAvailability() {
        availabilityMonitor.refresh()
    }

    func runRefinement() {
        refreshAvailability()

        let workflow = RefinementWorkflow(
            textService: textService,
            rewriteService: rewriteService,
            notifier: statusNotifier
        )

        Task {
            await workflow.refineSelection()
            await MainActor.run {
                self.refreshAvailability()
            }
        }
    }
}
