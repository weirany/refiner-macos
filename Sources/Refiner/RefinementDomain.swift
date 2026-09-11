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

enum RewriteAvailabilityState: Equatable, Sendable {
    case available
    case missingAPIKey

    var message: String {
        switch self {
        case .available:
            "OpenAI API key is configured."
        case .missingAPIKey:
            "OpenAI API key is missing. Open Settings and enter your API key."
        }
    }
}

enum RewriteError: Error, Equatable, Sendable {
    case unavailable(RewriteAvailabilityState)
    case generationFailed(String)
    case emptyResponse

    var message: String {
        switch self {
        case .unavailable(let state):
            state.message
        case .generationFailed(let description):
            description
        case .emptyResponse:
            "OpenAI returned an empty rewrite."
        }
    }
}

@MainActor
protocol TextSelectionHandling {
    func readSelection() -> Result<RewriteContext, TextSelectionError>
    func replaceSelection(
        in context: RewriteContext,
        with refinedText: String
    ) async -> Result<Void, TextSelectionError>
}

@MainActor
protocol Rewriting {
    func currentAvailability() -> RewriteAvailabilityState
    func rewrite(_ context: RewriteContext) async -> Result<RewriteResult, RewriteError>
}

@MainActor
protocol WorkflowNotifying {
    func showRunning()
    func showSuccess(_ message: String)
    func showError(_ message: String)
}
