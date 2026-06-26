import Foundation
import Testing
@testable import Refiner

@Test
@MainActor
func statusNotifierShowsDialogForErrors() {
    let toastPresenter = MockToastPresenter()
    let errorDialogPresenter = MockErrorDialogPresenter()
    let notifier = StatusNotifier(
        toastPresenter: toastPresenter,
        errorDialogPresenter: errorDialogPresenter
    )

    notifier.showError("The selected text could not be read.")

    #expect(errorDialogPresenter.messages == ["The selected text could not be read."])
}

@MainActor
private final class MockToastPresenter: ToastPresenting {
    func show(message: String, isError: Bool, autoDismiss: Bool) {}
    func hide() {}
}

@MainActor
private final class MockErrorDialogPresenter: ErrorDialogPresenting {
    private(set) var messages: [String] = []

    func showError(message: String) {
        messages.append(message)
    }
}
