import Foundation

struct AppIdentity: Equatable, Sendable {
    let bundleIdentifier: String?
    let executablePath: String

    init(
        bundleIdentifier: String? = Bundle.main.bundleIdentifier,
        executablePath: String = CommandLine.arguments[0]
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.executablePath = executablePath
    }

    var primaryLabel: String {
        bundleIdentifier ?? executablePath
    }
}
