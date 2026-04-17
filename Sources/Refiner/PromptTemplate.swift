import Foundation

struct PromptTemplate: Equatable, Sendable {
    enum Error: Swift.Error, Equatable {
        case missingPlaceholder
    }

    static let placeholder = "{original_text}"
    static let defaultValue = """
    Rewrite the text below into natural, native English. Follow these formatting rules:
    Punctuation: Do not use em dashes (—). However, preserve hyphens in compound words (e.g., "e-commerce," "long-term," or "2-week sprint").
    Output: Provide only the revised text with no explanations or introductory remarks.
    text to rewrite:
    \(placeholder)
    """

    let rawValue: String

    init(rawValue: String) throws {
        guard rawValue.contains(Self.placeholder) else {
            throw Error.missingPlaceholder
        }

        self.rawValue = rawValue
    }

    func render(with originalText: String) -> String {
        rawValue.replacingOccurrences(of: Self.placeholder, with: originalText)
    }
}
