import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let appIdentity = AppIdentity()
    private let appVersion = AppVersion()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        configureStatusItem()
        AppModel.shared.statusNotifier.onStateChange = { [weak self] state in
            self?.updateStatusIcon(for: state)
        }
        AppModel.shared.refreshAvailability()
        AppModel.shared.hotkeyManager.register {
            Task { @MainActor in
                AppModel.shared.runRefinement()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppModel.shared.hotkeyManager.unregister()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = nil
        item.autosaveName = appIdentity.statusItemAutosaveName
        item.button?.imagePosition = .imageOnly
        item.button?.toolTip = "Refiner"
        item.menu = makeMenu()
        statusItem = item
        updateStatusIcon(for: .idle)
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let refineItem = menu.addItem(
            withTitle: "Refine Selected Text",
            action: #selector(refineSelectedText),
            keyEquivalent: "r"
        )
        refineItem.keyEquivalentModifierMask = .option
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        menu.addItem(.separator())
        let versionItem = NSMenuItem(
            title: appVersion.menuTitle,
            action: nil,
            keyEquivalent: ""
        )
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        menu.addItem(
            withTitle: "Quit",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        menu.items.forEach { $0.target = self }
        return menu
    }

    private func updateStatusIcon(for state: StatusNotifier.ActivityState) {
        statusItem?.button?.image = StatusIconImage.image(for: state)
    }

    @objc
    private func refineSelectedText() {
        AppModel.shared.runRefinement()
    }

    @objc
    private func openSettings() {
        DispatchQueue.main.async {
            SettingsWindowController.shared.show(
                settingsStore: AppModel.shared.settingsStore,
                launchAtLoginManager: AppModel.shared.launchAtLoginManager,
                availabilityMonitor: AppModel.shared.availabilityMonitor
            )
        }
    }

    @objc
    private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
