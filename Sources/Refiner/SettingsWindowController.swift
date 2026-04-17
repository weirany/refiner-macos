import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show(
        settingsStore: SettingsStore,
        availabilityMonitor: AvailabilityMonitor
    ) {
        if window == nil {
            let contentView = SettingsView(
                settingsStore: settingsStore,
                availabilityMonitor: availabilityMonitor
            )
            .frame(minWidth: 540, minHeight: 440)

            let hostingController = NSHostingController(rootView: contentView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Settings"
            window.setContentSize(NSSize(width: 560, height: 460))
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.center()
            window.isReleasedWhenClosed = false
            window.setFrameAutosaveName("RefinerSettingsWindow")
            self.window = window
        } else if let hostingController = window?.contentViewController as? NSHostingController<SettingsView> {
            hostingController.rootView = SettingsView(
                settingsStore: settingsStore,
                availabilityMonitor: availabilityMonitor
            )
        }

        availabilityMonitor.refresh()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
