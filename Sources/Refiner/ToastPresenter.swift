import AppKit
import SwiftUI

@MainActor
final class ToastPresenter: ToastPresenting {
    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?

    func show(message: String, isError: Bool, autoDismiss: Bool) {
        dismissTask?.cancel()

        let hostingController = NSHostingController(
            rootView: ToastView(message: message, isError: isError)
        )

        let panel = panel ?? {
            let newPanel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 320, height: 84),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            newPanel.isFloatingPanel = true
            newPanel.level = .statusBar
            newPanel.backgroundColor = .clear
            newPanel.isOpaque = false
            newPanel.hasShadow = true
            newPanel.collectionBehavior = [.canJoinAllSpaces, .transient]
            newPanel.hidesOnDeactivate = false
            return newPanel
        }()

        panel.contentViewController = hostingController
        self.panel = panel
        panel.setFrameOrigin(panelOrigin(for: panel.frame.size))
        panel.orderFrontRegardless()

        if autoDismiss {
            dismissTask = Task {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else {
                    return
                }
                self.hide()
            }
        }
    }

    func hide() {
        dismissTask?.cancel()
        panel?.orderOut(nil)
    }

    private func panelOrigin(for size: NSSize) -> NSPoint {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return NSPoint(
            x: screen.maxX - size.width - 24,
            y: screen.maxY - size.height - 24
        )
    }
}

private struct ToastView: View {
    let message: String
    let isError: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "wand.and.stars")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(isError ? Color.orange : Color.accentColor)

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18))
        )
        .padding(8)
        .frame(width: 320)
    }
}
