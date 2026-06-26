import AppKit
import Foundation

@MainActor
protocol ToastPresenting {
    func show(message: String, isError: Bool, autoDismiss: Bool)
    func hide()
}

@MainActor
protocol ErrorDialogPresenting {
    func showError(message: String)
}

@MainActor
final class StatusNotifier: WorkflowNotifying {
    enum ActivityState {
        case idle
        case running
        case error
    }

    var onStateChange: ((ActivityState) -> Void)?

    private let toastPresenter: ToastPresenting
    private let errorDialogPresenter: ErrorDialogPresenting
    private var resetTask: Task<Void, Never>?

    init(
        toastPresenter: ToastPresenting = ToastPresenter(),
        errorDialogPresenter: ErrorDialogPresenting = ErrorDialogPresenter()
    ) {
        self.toastPresenter = toastPresenter
        self.errorDialogPresenter = errorDialogPresenter
    }

    func showRunning() {
        resetTask?.cancel()
        onStateChange?(.running)
        toastPresenter.show(message: "Refining selected text…", isError: false, autoDismiss: false)
    }

    func showSuccess(_ message: String) {
        toastPresenter.show(message: message, isError: false, autoDismiss: true)
        transitionToIdle(after: 2.0)
    }

    func showError(_ message: String) {
        onStateChange?(.error)
        toastPresenter.show(message: message, isError: true, autoDismiss: true)
        errorDialogPresenter.showError(message: message)
        transitionToIdle(after: 2.0)
    }

    private func transitionToIdle(after delay: TimeInterval) {
        resetTask?.cancel()
        resetTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else {
                return
            }
            onStateChange?(.idle)
        }
    }
}

@MainActor
final class ErrorDialogPresenter: ErrorDialogPresenting {
    func showError(message: String) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Refiner Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
