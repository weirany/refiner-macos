@MainActor
struct RefinementWorkflow {
    let textService: TextSelectionHandling
    let rewriteService: Rewriting
    let notifier: WorkflowNotifying

    func refineSelection() async {
        let availability = rewriteService.currentAvailability()
        guard availability == .available else {
            notifier.showError(availability.message)
            return
        }

        let context: RewriteContext
        switch textService.readSelection() {
        case .success(let value):
            context = value
        case .failure(let error):
            notifier.showError(error.message)
            return
        }

        notifier.showRunning()

        let rewriteResult: RewriteResult
        switch await rewriteService.rewrite(context) {
        case .success(let value):
            rewriteResult = value
        case .failure(let error):
            notifier.showError(error.message)
            return
        }

        switch textService.replaceSelection(in: context, with: rewriteResult.rewrittenText) {
        case .success:
            notifier.showSuccess("Successfully Refined")
        case .failure(let error):
            notifier.showError(error.message)
        }
    }
}
