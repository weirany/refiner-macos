import Carbon
import AppKit
import Foundation

struct RefinerKeyboardShortcut: Codable, Equatable, Sendable {
    enum Modifier: String, CaseIterable, Codable, Hashable, Sendable {
        case control
        case option
        case shift
        case command

        var displayName: String {
            switch self {
            case .control:
                "Control"
            case .option:
                "Option"
            case .shift:
                "Shift"
            case .command:
                "Command"
            }
        }

        var carbonFlag: Int {
            switch self {
            case .control:
                controlKey
            case .option:
                optionKey
            case .shift:
                shiftKey
            case .command:
                cmdKey
            }
        }
    }

    enum Key: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
        case a
        case b
        case c
        case d
        case e
        case f
        case g
        case h
        case i
        case j
        case k
        case l
        case m
        case n
        case o
        case p
        case q
        case r
        case s
        case t
        case u
        case v
        case w
        case x
        case y
        case z
        case space

        var id: String {
            rawValue
        }

        var displayName: String {
            switch self {
            case .space:
                "Space"
            default:
                rawValue.uppercased()
            }
        }

        var carbonKeyCode: UInt32 {
            switch self {
            case .a:
                UInt32(kVK_ANSI_A)
            case .b:
                UInt32(kVK_ANSI_B)
            case .c:
                UInt32(kVK_ANSI_C)
            case .d:
                UInt32(kVK_ANSI_D)
            case .e:
                UInt32(kVK_ANSI_E)
            case .f:
                UInt32(kVK_ANSI_F)
            case .g:
                UInt32(kVK_ANSI_G)
            case .h:
                UInt32(kVK_ANSI_H)
            case .i:
                UInt32(kVK_ANSI_I)
            case .j:
                UInt32(kVK_ANSI_J)
            case .k:
                UInt32(kVK_ANSI_K)
            case .l:
                UInt32(kVK_ANSI_L)
            case .m:
                UInt32(kVK_ANSI_M)
            case .n:
                UInt32(kVK_ANSI_N)
            case .o:
                UInt32(kVK_ANSI_O)
            case .p:
                UInt32(kVK_ANSI_P)
            case .q:
                UInt32(kVK_ANSI_Q)
            case .r:
                UInt32(kVK_ANSI_R)
            case .s:
                UInt32(kVK_ANSI_S)
            case .t:
                UInt32(kVK_ANSI_T)
            case .u:
                UInt32(kVK_ANSI_U)
            case .v:
                UInt32(kVK_ANSI_V)
            case .w:
                UInt32(kVK_ANSI_W)
            case .x:
                UInt32(kVK_ANSI_X)
            case .y:
                UInt32(kVK_ANSI_Y)
            case .z:
                UInt32(kVK_ANSI_Z)
            case .space:
                UInt32(kVK_Space)
            }
        }
    }

    static let defaultShortcut = RefinerKeyboardShortcut(modifiers: [.option], key: .r)

    var modifiers: Set<Modifier>
    var key: Key

    var displayName: String {
        let modifierNames = Modifier.allCases
            .filter { modifiers.contains($0) }
            .map(\.displayName)
        return (modifierNames + [key.displayName]).joined(separator: "+")
    }

    var carbonModifierFlags: UInt32 {
        UInt32(modifiers.reduce(0) { $0 | $1.carbonFlag })
    }

    var keyEquivalent: String {
        switch key {
        case .space:
            " "
        default:
            key.rawValue
        }
    }

    var appKitModifierFlags: NSEvent.ModifierFlags {
        modifiers.reduce([]) { flags, modifier in
            switch modifier {
            case .control:
                flags.union(.control)
            case .option:
                flags.union(.option)
            case .shift:
                flags.union(.shift)
            case .command:
                flags.union(.command)
            }
        }
    }
}
