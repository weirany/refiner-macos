import Foundation

enum AppMenu {
    static func menuTitles(versionTitle: String) -> [String] {
        [
            "Settings…",
            versionTitle,
            "Quit",
        ]
    }
}
