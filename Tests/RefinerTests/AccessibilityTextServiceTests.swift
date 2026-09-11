import ApplicationServices
import Foundation
import Testing
@testable import Refiner

@Test(arguments: ["\n", "\r\n", "\n\n", "\u{2028}", "\u{2029}", ""])
@MainActor
func accessibilityTextServicePastesCompleteResultWithoutInspectingTarget(suffix: String) async throws {
    let handler = MockAccessibilityElementHandler(
        focusedElement: AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier),
        fullText: "He go." + suffix,
        selectedRange: CFRange(location: 0, length: ("He go." + suffix).utf16.count),
        roleDescription: "text area"
    )
    let insertion = MockTextInsertionHandler()
    let service = AccessibilityTextService(
        accessibilityHandler: handler, textInsertionHandler: insertion,
        hasAccessibilityPermission: { true }
    )
    let context = try service.readSelection().get()
    // The original field may disappear or lose focus while the model is running.
    handler.allowReading = false
    let readsBeforePaste = handler.readCount
    try await service.replaceSelection(in: context, with: "He went." + suffix).get()
    #expect(insertion.insertedTexts == ["He went." + suffix])
    #expect(handler.readCount == readsBeforePaste)
}

@Test(arguments: [CFRange(location: 6, length: 5), CFRange(location: 16, length: 0)])
@MainActor
func accessibilityTextServiceHonorsChangedSelectionOrCursor(range: CFRange) async throws {
    let handler = MockAccessibilityElementHandler(
        focusedElement: AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier),
        fullText: "He go. Next text.",
        selectedRange: CFRange(location: 0, length: 6),
        roleDescription: "text area"
    )
    let insertion = MockTextInsertionHandler()
    insertion.onInsert = { handler.replaceSelectedText($0) }
    let service = AccessibilityTextService(
        accessibilityHandler: handler, textInsertionHandler: insertion,
        hasAccessibilityPermission: { true }
    )
    let context = try service.readSelection().get()
    handler.changeSelection(to: range)
    try await service.replaceSelection(in: context, with: "He went.").get()
    let expected = ("He go. Next text." as NSString).replacingCharacters(
        in: NSRange(location: range.location, length: range.length), with: "He went."
    )
    #expect(handler.fullText == expected)
}

@Test
@MainActor
func accessibilityTextServiceReportsPasteDispatchFailure() async {
    let insertion = MockTextInsertionHandler()
    insertion.succeeds = false
    let service = AccessibilityTextService(textInsertionHandler: insertion)
    let context = RewriteContext(selectedText: "He go.", bundleIdentifier: nil, elementDescription: nil)
    let result = await service.replaceSelection(in: context, with: "He went.")
    guard case .failure(let error) = result else {
        Issue.record("Expected paste dispatch failure")
        return
    }
    #expect(error == .writeFailed)
}

@Test
@MainActor
func accessibilityTextServiceAcceptsSettableFieldWhenAXEditableIsFalse() {
    let targetElement = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
    let handler = MockAccessibilityElementHandler(
        focusedElement: targetElement,
        fullText: "Hello world",
        selectedRange: CFRange(location: 6, length: 5),
        roleDescription: "text area",
        editableAttribute: false,
        valueIsSettable: true
    )
    let service = AccessibilityTextService(
        accessibilityHandler: handler,
        textInsertionHandler: MockTextInsertionHandler(),
        hasAccessibilityPermission: { true }
    )

    let result = service.readSelection()

    switch result {
    case .success(let context):
        #expect(context.selectedText == "world")
    case .failure(let error):
        Issue.record("Expected settable field to be accepted, got \(error)")
    }
}

@Test
@MainActor
func accessibilityTextServiceRejectsNonSettableFieldWhenAXEditableIsFalse() {
    let targetElement = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
    let handler = MockAccessibilityElementHandler(
        focusedElement: targetElement,
        fullText: "Hello world",
        selectedRange: CFRange(location: 6, length: 5),
        roleDescription: "text area",
        role: kAXStaticTextRole,
        editableAttribute: false,
        valueIsSettable: false,
        selectedRangeIsSettable: false
    )
    let service = AccessibilityTextService(
        accessibilityHandler: handler,
        textInsertionHandler: MockTextInsertionHandler(),
        hasAccessibilityPermission: { true }
    )

    #expect(service.readSelection() == .failure(.fieldNotEditable))
}

@Test
@MainActor
func accessibilityTextServiceAcceptsTextAreaRoleWhenElectronReportsNonEditable() {
    let targetElement = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
    let handler = MockAccessibilityElementHandler(
        focusedElement: targetElement,
        fullText: "Hello Slack",
        selectedRange: CFRange(location: 6, length: 5),
        roleDescription: "text area",
        role: kAXTextAreaRole,
        editableAttribute: false,
        valueIsSettable: false,
        selectedRangeIsSettable: false
    )
    let service = AccessibilityTextService(
        accessibilityHandler: handler,
        textInsertionHandler: MockTextInsertionHandler(),
        hasAccessibilityPermission: { true }
    )

    let result = service.readSelection()

    switch result {
    case .success(let context):
        #expect(context.selectedText == "Slack")
    case .failure(let error):
        Issue.record("Expected text-area role fallback to succeed, got \(error)")
    }
}

private final class MockAccessibilityElementHandler: AccessibilityElementHandling, @unchecked Sendable {
    private let focusedElement: AXUIElement
    private let valueIsSettable: Bool
    private let selectedRangeIsSettable: Bool
    private var attributes: [String: CFTypeRef] = [:]
    var allowReading = true
    private(set) var readCount = 0
    var fullText: String { attributes[kAXValueAttribute as String] as! String }

    init(
        focusedElement: AXUIElement,
        fullText: String,
        selectedRange: CFRange,
        roleDescription: String,
        role: String = kAXTextAreaRole,
        editableAttribute: Bool = true,
        valueIsSettable: Bool = true,
        selectedRangeIsSettable: Bool = true
    ) {
        self.focusedElement = focusedElement
        self.valueIsSettable = valueIsSettable
        self.selectedRangeIsSettable = selectedRangeIsSettable
        attributes[kAXValueAttribute as String] = fullText as CFTypeRef
        attributes[kAXRoleAttribute as String] = role as CFTypeRef
        attributes[kAXRoleDescriptionAttribute as String] = roleDescription as CFTypeRef

        var mutableRange = selectedRange
        attributes[kAXSelectedTextRangeAttribute as String] = AXValueCreate(.cfRange, &mutableRange)
        attributes["AXEditable"] = editableAttribute as CFTypeRef
    }

    func copyAttributeValue(
        element: AXUIElement,
        attribute: CFString
    ) -> (AXError, CFTypeRef?) {
        readCount += 1
        guard allowReading else { return (.invalidUIElement, nil) }
        let name = attribute as String

        if name == kAXFocusedUIElementAttribute as String {
            return (.success, focusedElement)
        }

        return (.success, attributes[name])
    }

    func changeSelection(to range: CFRange) {
        var mutableRange = range
        attributes[kAXSelectedTextRangeAttribute as String] = AXValueCreate(.cfRange, &mutableRange)
    }

    func isAttributeSettable(
        element: AXUIElement,
        attribute: CFString
    ) -> (AXError, DarwinBoolean) {
        let isSettable = attribute as String == kAXSelectedTextRangeAttribute
            ? selectedRangeIsSettable
            : valueIsSettable
        return (.success, DarwinBoolean(isSettable))
    }

    func replaceSelectedText(_ text: String) {
        let value = attributes[kAXSelectedTextRangeAttribute as String] as! AXValue
        var range = CFRange()
        AXValueGetValue(value, .cfRange, &range)
        let fullText = attributes[kAXValueAttribute as String] as! NSString
        attributes[kAXValueAttribute as String] = fullText.replacingCharacters(
            in: NSRange(location: range.location, length: range.length), with: text
        ) as CFTypeRef
    }
}

private final class MockTextInsertionHandler: TextInsertionHandling, @unchecked Sendable {
    private(set) var insertedTexts: [String] = []
    var onInsert: ((String) -> Void)?
    var succeeds = true

    func insertText(_ text: String) -> Bool {
        insertedTexts.append(text)
        if succeeds { onInsert?(text) }
        return succeeds
    }
}
