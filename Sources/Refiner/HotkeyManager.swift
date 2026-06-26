import Carbon
import Foundation

final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var handler: (@Sendable () -> Void)?

    func register(
        shortcut: RefinerKeyboardShortcut,
        handler: @escaping @Sendable () -> Void
    ) {
        self.handler = handler

        if eventHandler == nil {
            var eventType = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )

            InstallEventHandler(
                GetApplicationEventTarget(),
                { _, event, userData in
                    guard
                        let event,
                        let userData
                    else {
                        return noErr
                    }

                    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                    var hotKeyID = EventHotKeyID()
                    GetEventParameter(
                        event,
                        EventParamName(kEventParamDirectObject),
                        EventParamType(typeEventHotKeyID),
                        nil,
                        MemoryLayout<EventHotKeyID>.size,
                        nil,
                        &hotKeyID
                    )

                    if hotKeyID.id == 1 {
                        manager.handler?()
                    }

                    return noErr
                },
                1,
                &eventType,
                UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
                &eventHandler
            )
        }

        unregisterHotKeyIfNeeded()

        let hotKeyID = EventHotKeyID(signature: fourCharCode("RFIN"), id: 1)
        RegisterEventHotKey(
            shortcut.key.carbonKeyCode,
            shortcut.carbonModifierFlags,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        unregisterHotKeyIfNeeded()

        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private func unregisterHotKeyIfNeeded() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func fourCharCode(_ value: String) -> FourCharCode {
        value.utf16.reduce(0) { partialResult, character in
            (partialResult << 8) + FourCharCode(character)
        }
    }
}
