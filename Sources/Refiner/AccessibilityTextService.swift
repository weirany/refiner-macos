import AppKit
import ApplicationServices
import Foundation
import OSLog

protocol AccessibilityElementHandling: Sendable {
    func copyAttributeValue(
        element: AXUIElement,
        attribute: CFString
    ) -> (AXError, CFTypeRef?)
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
    @MainActor func insertText(_ text: String) async -> Bool
}

private struct LiveTextInsertionHandler: TextInsertionHandling {
    @MainActor func insertText(_ text: String) async -> Bool {
        guard !text.isEmpty else {
            return true
        }

        let pasteboard = NSPasteboard.general
        let previousItems = PasteboardSnapshot.capture(from: pasteboard)
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            previousItems.restore(to: pasteboard)
            return false
        }
        let insertedTextChangeCount = pasteboard.changeCount

        guard postPasteShortcut() else {
            previousItems.restore(to: pasteboard)
            return false
        }

        // Let the main run loop serve clipboard requests while the editor pastes.
        try? await Task.sleep(for: .milliseconds(500))
        if pasteboard.changeCount == insertedTextChangeCount {
            previousItems.restore(to: pasteboard)
        }
        return true
    }

    private func postPasteShortcut() -> Bool {
        let pasteKeyCode: CGKeyCode = 9
        guard
            let source = CGEventSource(stateID: .hidSystemState),
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: pasteKeyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: pasteKeyCode, keyDown: false)
        else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}

private struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    static func capture(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let items = pasteboard.pasteboardItems?.map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            })
        } ?? []
        return PasteboardSnapshot(items: items)
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let restoredItems = items.map { values in
            let item = NSPasteboardItem()
            for (type, data) in values {
                item.setData(data, forType: type)
            }
            return item
        }
        if !restoredItems.isEmpty {
            pasteboard.writeObjects(restoredItems)
        }
    }
}

final class AccessibilityTextService: TextSelectionHandling, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.weiranye.refiner", category: "WriteBack")
    private let accessibilityHandler: AccessibilityElementHandling
    private let textInsertionHandler: TextInsertionHandling
    private let hasAccessibilityPermission: @Sendable () -> Bool

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
        guard selectedRange.location >= 0,
              selectedRange.length <= nsText.length,
              selectedRange.location <= nsText.length - selectedRange.length else {
            return .failure(.readFailed)
        }
        let selectedText = nsText.substring(with: NSRange(location: selectedRange.location, length: selectedRange.length))
        let role = stringAttribute(kAXRoleDescriptionAttribute, on: element)

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
    ) async -> Result<Void, TextSelectionError> {
        logger.notice("Starting writeback; generated text differs: \(refinedText != context.selectedText)")
        // Honor the user's current focus, selection, and cursor position.
        // Do not restore the original selection or inspect the editor after pasting.
        guard await textInsertionHandler.insertText(refinedText) else {
            logger.error("Paste dispatch failed")
            return .failure(.writeFailed)
        }
        logger.notice("Paste dispatched")
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
        if boolAttribute("AXEditable", on: element) == true {
            return true
        }

        if isAttributeSettable(kAXValueAttribute, on: element)
            || isAttributeSettable(kAXSelectedTextRangeAttribute, on: element) {
            return true
        }

        let textEntryRoles = [
            kAXTextFieldRole,
            kAXTextAreaRole,
            kAXComboBoxRole,
        ]
        let role = stringAttribute(kAXRoleAttribute, on: element)

        return role.map(textEntryRoles.contains) == true
            && selectedTextRange(on: element) != nil
    }

    private func isAttributeSettable(_ attribute: String, on element: AXUIElement) -> Bool {
        let (result, settable) = accessibilityHandler.isAttributeSettable(
            element: element,
            attribute: attribute as CFString
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
