import SwiftUI

@main
struct RefinerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            EmptyView()
        }
    }
}
