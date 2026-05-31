import AppKit
import ApplicationServices
import Foundation

protocol AccessibilityElementHandling: Sendable {
    func copyAttributeValue(
        element: AXUIElement,
        attribute: CFString
    ) -> (AXError, CFTypeRef?)
    func setAttributeValue(
        element: AXUIElement,
        attribute: CFString,
        value: CFTypeRef
    ) -> AXError
    func isAttributeSettable(
        element: AXUIElement,
        attribute: CFString
    ) -> (AXError, DarwinBoolean)
}

private struct LiveAccessibilityElementHandler: AccessibilityElementHandling {
    func copyAttributeValue(
        element: AXUIElement,
        attribute: CFString
    ) -> (AXError, CFTypeRef?) {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        return (result, value)
    }

    func setAttributeValue(
        element: AXUIElement,
        attribute: CFString,
        value: CFTypeRef
    ) -> AXError {
        AXUIElementSetAttributeValue(element, attribute, value)
    }

    func isAttributeSettable(
        element: AXUIElement,
        attribute: CFString
    ) -> (AXError, DarwinBoolean) {
        var settable = DarwinBoolean(false)
        let result = AXUIElementIsAttributeSettable(element, attribute, &settable)
        return (result, settable)
    }
}

protocol TextInsertionHandling: Sendable {
    func insertText(_ text: String) -> Bool
}

private struct LiveTextInsertionHandler: TextInsertionHandling {
    func insertText(_ text: String) -> Bool {
        guard !text.isEmpty else {
            return true
        }

        guard
            let source = CGEventSource(stateID: .hidSystemState),
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        else {
            return false
        }

        let unicodeScalars = Array(text.utf16)
        keyDown.keyboardSetUnicodeString(stringLength: unicodeScalars.count, unicodeString: unicodeScalars)
        keyUp.keyboardSetUnicodeString(stringLength: unicodeScalars.count, unicodeString: unicodeScalars)
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}

final class AccessibilityTextService: TextSelectionHandling, @unchecked Sendable {
    private struct SelectionSnapshot {
        let element: AXUIElement
        let selectedRange: CFRange
    }

    private let accessibilityHandler: AccessibilityElementHandling
    private let textInsertionHandler: TextInsertionHandling
    private let hasAccessibilityPermission: @Sendable () -> Bool
    private var lastSnapshot: SelectionSnapshot?

    init(
        accessibilityHandler: AccessibilityElementHandling = LiveAccessibilityElementHandler(),
        textInsertionHandler: TextInsertionHandling = LiveTextInsertionHandler(),
        hasAccessibilityPermission: @escaping @Sendable () -> Bool = AXIsProcessTrusted
    ) {
        self.accessibilityHandler = accessibilityHandler
        self.textInsertionHandler = textInsertionHandler
        self.hasAccessibilityPermission = hasAccessibilityPermission
    }

    func readSelection() -> Result<RewriteContext, TextSelectionError> {
        guard hasAccessibilityPermission() else {
            return .failure(.accessibilityPermissionMissing)
        }

        guard let element = focusedElement() else {
            return .failure(.focusedElementUnavailable)
        }

        guard isEditable(element) else {
            return .failure(.fieldNotEditable)
        }

        guard
            let fullText = stringAttribute(kAXValueAttribute, on: element),
            let selectedRange = selectedTextRange(on: element)
        else {
            return .failure(.readFailed)
        }

        guard selectedRange.length > 0 else {
            return .failure(.noSelection)
        }

        let nsText = fullText as NSString
        let selectedText = nsText.substring(with: NSRange(location: selectedRange.location, length: selectedRange.length))
        let role = stringAttribute(kAXRoleDescriptionAttribute, on: element)

        lastSnapshot = SelectionSnapshot(
            element: element,
            selectedRange: selectedRange
        )

        return .success(
            RewriteContext(
                selectedText: selectedText,
                bundleIdentifier: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
                elementDescription: role
            )
        )
    }

    func replaceSelection(
        in context: RewriteContext,
        with refinedText: String
    ) -> Result<Void, TextSelectionError> {
        guard let snapshot = lastSnapshot else {
            return .failure(.writeFailed)
        }

        var selectedRange = snapshot.selectedRange
        guard
            let rangeValue = AXValueCreate(.cfRange, &selectedRange)
        else {
            return .failure(.writeFailed)
        }

        let setRangeResult = accessibilityHandler.setAttributeValue(
            element: snapshot.element,
            attribute: kAXSelectedTextRangeAttribute as CFString,
            value: rangeValue
        )
        guard setRangeResult == .success else {
            return .failure(.writeFailed)
        }

        guard textInsertionHandler.insertText(refinedText) else {
            return .failure(.writeFailed)
        }

        lastSnapshot = nil
        return .success(())
    }

    static func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    private func focusedElement() -> AXUIElement? {
        let appElement = AXUIElementCreateSystemWide()
        let (result, focused) = accessibilityHandler.copyAttributeValue(
            element: appElement,
            attribute: kAXFocusedUIElementAttribute as CFString
        )

        guard result == .success else {
            return nil
        }

        return (focused as! AXUIElement)
    }

    private func isEditable(_ element: AXUIElement) -> Bool {
        if let editableValue = boolAttribute("AXEditable", on: element) {
            return editableValue
        }

        let (result, settable) = accessibilityHandler.isAttributeSettable(
            element: element,
            attribute: kAXValueAttribute as CFString
        )

        return result == .success && settable.boolValue
    }

    private func stringAttribute(_ attribute: String, on element: AXUIElement) -> String? {
        let (result, value) = accessibilityHandler.copyAttributeValue(
            element: element,
            attribute: attribute as CFString
        )

        guard result == .success else {
            return nil
        }

        return value as? String
    }

    private func boolAttribute(_ attribute: String, on element: AXUIElement) -> Bool? {
        let (result, value) = accessibilityHandler.copyAttributeValue(
            element: element,
            attribute: attribute as CFString
        )

        guard result == .success else {
            return nil
        }

        return value as? Bool
    }

    private func selectedTextRange(on element: AXUIElement) -> CFRange? {
        let (result, value) = accessibilityHandler.copyAttributeValue(
            element: element,
            attribute: kAXSelectedTextRangeAttribute as CFString
        )

        guard result == .success, let axValue = value, CFGetTypeID(axValue) == AXValueGetTypeID() else {
            return nil
        }

        let rangeValue = axValue as! AXValue
        guard AXValueGetType(rangeValue) == .cfRange else {
            return nil
        }

        var range = CFRange()
        return AXValueGetValue(rangeValue, .cfRange, &range) ? range : nil
    }
}
