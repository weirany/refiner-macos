import AppKit
import Foundation

@MainActor
final class StatusNotifier: WorkflowNotifying {
    enum ActivityState {
        case idle
        case running
        case error
    }

    var onStateChange: ((ActivityState) -> Void)?

    private let toastPresenter = ToastPresenter()
    private var resetTask: Task<Void, Never>?

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
