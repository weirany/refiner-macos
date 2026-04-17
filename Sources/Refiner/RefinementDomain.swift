import Foundation

struct RewriteContext: Equatable, Sendable {
    let selectedText: String
    let bundleIdentifier: String?
    let elementDescription: String?
}

struct RewriteResult: Equatable, Sendable {
    let rewrittenText: String
}

enum TextSelectionError: Error, Equatable, Sendable {
    case accessibilityPermissionMissing
    case focusedElementUnavailable
    case fieldNotEditable
    case noSelection
    case readFailed
    case writeFailed

    var message: String {
        switch self {
        case .accessibilityPermissionMissing:
            "Accessibility permission is required to refine selected text."
        case .focusedElementUnavailable:
            "No focused editable text field was found."
        case .fieldNotEditable:
            "The focused text field is not editable."
        case .noSelection:
            "Select some text in an editable field first."
        case .readFailed:
            "The selected text could not be read."
        case .writeFailed:
            "The refined text could not be written back."
        }
    }
}

enum LocalRewriteError: Error, Equatable, Sendable {
    case modelUnavailable(LocalModelAvailabilityState)
    case generationFailed(String)
    case emptyResponse

    var message: String {
        switch self {
        case .modelUnavailable(let state):
            state.message
        case .generationFailed(let description):
            description
        case .emptyResponse:
            "The local model returned an empty rewrite."
        }
    }
}

@MainActor
protocol TextSelectionHandling {
    func readSelection() -> Result<RewriteContext, TextSelectionError>
    func replaceSelection(
        in context: RewriteContext,
        with refinedText: String
    ) -> Result<Void, TextSelectionError>
}

@MainActor
protocol LocalRewriting {
    func currentAvailability() -> LocalModelAvailabilityState
    func rewrite(_ context: RewriteContext) async -> Result<RewriteResult, LocalRewriteError>
}

@MainActor
protocol WorkflowNotifying {
    func showRunning()
    func showSuccess(_ message: String)
    func showError(_ message: String)
}
