import AppKit
import Testing
@testable import Refiner

@Test
@MainActor
func idleStatusIconUsesBundledTemplateImage() throws {
    #expect(StatusIconImage.symbolName(for: .idle) == nil)

    let image = try #require(StatusIconImage.image(for: .idle))

    #expect(image.isTemplate)
    #expect(image.size == NSSize(width: 18, height: 18))
}

@Test
func activityStatusIconsKeepSystemSymbols() {
    #expect(StatusIconImage.symbolName(for: .running) == "ellipsis.circle")
    #expect(StatusIconImage.symbolName(for: .error) == "exclamationmark.circle")
}
