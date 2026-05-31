import Foundation

enum AppMenu {
    static func menuTitles(versionTitle: String) -> [String] {
        [
            "Refine Selected Text",
            "Settings…",
            versionTitle,
            "Quit",
        ]
    }
}
