import AppKit

enum StatusIconImage {
    static let idleTemplateResourceName = "MenuBarIconTemplate@2x"
    static let idleTemplateResourceExtension = "png"
    static let menuBarPointSize = NSSize(width: 18, height: 18)

    static func symbolName(for state: StatusNotifier.ActivityState) -> String? {
        switch state {
        case .idle:
            nil
        case .running:
            "ellipsis.circle"
        case .error:
            "exclamationmark.circle"
        }
    }

    @MainActor
    static func image(for state: StatusNotifier.ActivityState) -> NSImage? {
        if let symbolName = symbolName(for: state) {
            let image = NSImage(
                systemSymbolName: symbolName,
                accessibilityDescription: "Refiner"
            )
            image?.isTemplate = true
            return image
        }

        guard let imageURL = idleTemplateResourceURL() else {
            return nil
        }

        let image = NSImage(contentsOf: imageURL)
        image?.size = menuBarPointSize
        image?.isTemplate = true
        image?.accessibilityDescription = "Refiner"
        return image
    }

    static func idleTemplateResourceURL(bundle: Bundle = .main) -> URL? {
        bundle.url(
            forResource: idleTemplateResourceName,
            withExtension: idleTemplateResourceExtension
        ) ?? Bundle.module.url(
            forResource: idleTemplateResourceName,
            withExtension: idleTemplateResourceExtension
        )
    }
}
