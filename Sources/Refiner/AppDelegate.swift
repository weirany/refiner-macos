import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

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
        item.button?.imagePosition = .imageOnly
        item.button?.toolTip = "Refiner"
        item.menu = makeMenu()
        statusItem = item
        updateStatusIcon(for: .idle)
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(
            withTitle: "Refine Selected Text",
            action: #selector(refineSelectedText),
            keyEquivalent: ""
        )
        menu.addItem(
            withTitle: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        menu.items.forEach { $0.target = self }
        return menu
    }

    private func updateStatusIcon(for state: StatusNotifier.ActivityState) {
        let symbolName: String
        switch state {
        case .idle:
            symbolName = "wand.and.sparkles"
        case .running:
            symbolName = "ellipsis.circle"
        case .error:
            symbolName = "exclamationmark.circle"
        }

        statusItem?.button?.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "Refiner"
        )
    }

    @objc
    private func refineSelectedText() {
        AppModel.shared.runRefinement()
    }

    @objc
    private func openSettings() {
        SettingsWindowController.shared.show(
            settingsStore: AppModel.shared.settingsStore,
            availabilityMonitor: AppModel.shared.availabilityMonitor
        )
    }

    @objc
    private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
