import ApplicationServices
import Foundation
import Testing
@testable import Refiner

@Test
@MainActor
func accessibilityTextServiceReplacesOnlySelectedRange() {
    let targetElement = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
    let handler = MockAccessibilityElementHandler(
        focusedElement: targetElement,
        fullText: "Hello world again",
        selectedRange: CFRange(location: 6, length: 5),
        roleDescription: "text area"
    )
    let insertionHandler = MockTextInsertionHandler()
    let service = AccessibilityTextService(
        accessibilityHandler: handler,
        textInsertionHandler: insertionHandler,
        hasAccessibilityPermission: { true }
    )

    let readResult = service.readSelection()
    let context: RewriteContext
    switch readResult {
    case .success(let value):
        context = value
    case .failure(let error):
        Issue.record("Expected readSelection to succeed, got \(error)")
        return
    }

    let replaceResult = service.replaceSelection(in: context, with: "friend")

    switch replaceResult {
    case .success:
        break
    case .failure(let error):
        Issue.record("Expected replaceSelection to succeed, got \(error)")
    }

    #expect(context.selectedText == "world")
    #expect(insertionHandler.insertedTexts == ["friend"])
    #expect(handler.setAttributeNames == [kAXSelectedTextRangeAttribute as String])
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
        editableAttribute: false,
        valueIsSettable: false
    )
    let service = AccessibilityTextService(
        accessibilityHandler: handler,
        textInsertionHandler: MockTextInsertionHandler(),
        hasAccessibilityPermission: { true }
    )

    #expect(service.readSelection() == .failure(.fieldNotEditable))
}

private final class MockAccessibilityElementHandler: AccessibilityElementHandling, @unchecked Sendable {
    private let focusedElement: AXUIElement
    private let valueIsSettable: Bool
    private var attributes: [String: CFTypeRef] = [:]
    private(set) var setAttributeNames: [String] = []

    init(
        focusedElement: AXUIElement,
        fullText: String,
        selectedRange: CFRange,
        roleDescription: String,
        editableAttribute: Bool = true,
        valueIsSettable: Bool = true
    ) {
        self.focusedElement = focusedElement
        self.valueIsSettable = valueIsSettable
        attributes[kAXValueAttribute as String] = fullText as CFTypeRef
        attributes[kAXRoleDescriptionAttribute as String] = roleDescription as CFTypeRef

        var mutableRange = selectedRange
        attributes[kAXSelectedTextRangeAttribute as String] = AXValueCreate(.cfRange, &mutableRange)
        attributes["AXEditable"] = editableAttribute as CFTypeRef
    }

    func copyAttributeValue(
        element: AXUIElement,
        attribute: CFString
    ) -> (AXError, CFTypeRef?) {
        let name = attribute as String

        if name == kAXFocusedUIElementAttribute as String {
            return (.success, focusedElement)
        }

        return (.success, attributes[name])
    }

    func setAttributeValue(
        element: AXUIElement,
        attribute: CFString,
        value: CFTypeRef
    ) -> AXError {
        attributes[attribute as String] = value
        setAttributeNames.append(attribute as String)
        return .success
    }

    func isAttributeSettable(
        element: AXUIElement,
        attribute: CFString
    ) -> (AXError, DarwinBoolean) {
        (.success, DarwinBoolean(valueIsSettable))
    }
}

private final class MockTextInsertionHandler: TextInsertionHandling, @unchecked Sendable {
    private(set) var insertedTexts: [String] = []

    func insertText(_ text: String) -> Bool {
        insertedTexts.append(text)
        return true
    }
}
