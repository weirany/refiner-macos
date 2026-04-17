import AppKit
import ApplicationServices
import Foundation

final class AccessibilityTextService: TextSelectionHandling, @unchecked Sendable {
    private struct SelectionSnapshot {
        let element: AXUIElement
        let fullText: String
        let selectedRange: CFRange
    }

    private var lastSnapshot: SelectionSnapshot?

    func readSelection() -> Result<RewriteContext, TextSelectionError> {
        guard AXIsProcessTrusted() else {
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
            fullText: fullText,
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

        let nsText = snapshot.fullText as NSString
        let selectedRange = NSRange(
            location: snapshot.selectedRange.location,
            length: snapshot.selectedRange.length
        )
        let replacement = nsText.replacingCharacters(in: selectedRange, with: refinedText)

        let setValueResult = AXUIElementSetAttributeValue(
            snapshot.element,
            kAXValueAttribute as CFString,
            replacement as CFTypeRef
        )
        guard setValueResult == .success else {
            return .failure(.writeFailed)
        }

        var collapsedRange = CFRange(
            location: selectedRange.location + (refinedText as NSString).length,
            length: 0
        )
        guard
            let rangeValue = AXValueCreate(.cfRange, &collapsedRange)
        else {
            return .failure(.writeFailed)
        }

        let setRangeResult = AXUIElementSetAttributeValue(
            snapshot.element,
            kAXSelectedTextRangeAttribute as CFString,
            rangeValue
        )
        guard setRangeResult == .success else {
            return .failure(.writeFailed)
        }

        lastSnapshot = nil
        return .success(())
    }

    static func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    @MainActor
    static func requestAccessibilityPermission() -> Bool {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let options = [key: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func focusedElement() -> AXUIElement? {
        let appElement = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focused
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

        var settable = DarwinBoolean(false)
        let result = AXUIElementIsAttributeSettable(
            element,
            kAXValueAttribute as CFString,
            &settable
        )

        return result == .success && settable.boolValue
    }

    private func stringAttribute(_ attribute: String, on element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        )

        guard result == .success else {
            return nil
        }

        return value as? String
    }

    private func boolAttribute(_ attribute: String, on element: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        )

        guard result == .success else {
            return nil
        }

        return value as? Bool
    }

    private func selectedTextRange(on element: AXUIElement) -> CFRange? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &value
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
