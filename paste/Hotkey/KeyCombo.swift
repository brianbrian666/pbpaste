import AppKit
import Carbon.HIToolbox
import CoreServices

@MainActor
struct KeyCombo: Equatable {
    let keyCode: UInt32
    let carbonModifiers: UInt32

    static let `default` = KeyCombo(keyCode: UInt32(kVK_ANSI_V), carbonModifiers: GlobalHotkey.commandShift)

    // keyCode 0 is kVK_ANSI_A and a bare function key legitimately stores modifiers == 0,
    // so presence must be checked with object(forKey:), never integer(forKey:) != 0.
    static func stored(defaults: UserDefaults = .standard) -> KeyCombo {
        guard
            let code = defaults.object(forKey: PreferenceKeys.hotkeyCode) as? Int,
            let modifiers = defaults.object(forKey: PreferenceKeys.hotkeyModifiers) as? Int,
            (0...127).contains(code)
        else { return .default }
        return KeyCombo(keyCode: UInt32(code), carbonModifiers: UInt32(modifiers))
    }

    func persist(to defaults: UserDefaults = .standard) {
        defaults.set(Int(keyCode), forKey: PreferenceKeys.hotkeyCode)
        defaults.set(Int(carbonModifiers), forKey: PreferenceKeys.hotkeyModifiers)
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    static func isFunctionKey(_ keyCode: UInt32) -> Bool {
        switch keyCode {
        case UInt32(kVK_F1), UInt32(kVK_F2), UInt32(kVK_F3), UInt32(kVK_F4),
             UInt32(kVK_F5), UInt32(kVK_F6), UInt32(kVK_F7), UInt32(kVK_F8),
             UInt32(kVK_F9), UInt32(kVK_F10), UInt32(kVK_F11), UInt32(kVK_F12),
             UInt32(kVK_F13), UInt32(kVK_F14), UInt32(kVK_F15), UInt32(kVK_F16),
             UInt32(kVK_F17), UInt32(kVK_F18), UInt32(kVK_F19):
            return true
        default:
            return false
        }
    }

    var displayString: String {
        modifierSymbols + keySymbol
    }

    private var modifierSymbols: String {
        var symbols = ""
        if carbonModifiers & UInt32(controlKey) != 0 { symbols += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { symbols += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { symbols += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { symbols += "⌘" }
        return symbols
    }

    private var keySymbol: String {
        KeyCombo.symbolCache.keySymbol(for: keyCode)
    }

    // The hotkey is keycode-based (layout-independent), so the display string must be
    // computed against the current input source — a recorded character would lie after
    // a layout switch. Cached per input source so layout changes recompute.
    private final class SymbolCache {
        private var inputSourceID: String?
        private var symbols: [UInt32: String] = [:]

        func keySymbol(for keyCode: UInt32) -> String {
            if let special = Self.specialKeySymbol(keyCode) { return special }
            let currentSource = Self.currentInputSourceID
            if currentSource != inputSourceID {
                inputSourceID = currentSource
                symbols.removeAll()
            }
            if let cached = symbols[keyCode] { return cached }
            let symbol = Self.translatedKeySymbol(keyCode: keyCode) ?? "Key \(keyCode)"
            symbols[keyCode] = symbol
            return symbol
        }

        private static var currentInputSourceID: String {
            guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
                  let pointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceID)
            else { return "" }
            return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
        }

        private static func specialKeySymbol(_ keyCode: UInt32) -> String? {
            switch keyCode {
            case UInt32(kVK_Space): return "Space"
            case UInt32(kVK_Return): return "↩"
            case UInt32(kVK_Tab): return "⇥"
            case UInt32(kVK_Escape): return "⎋"
            case UInt32(kVK_Delete): return "⌫"
            case UInt32(kVK_ForwardDelete): return "⌦"
            case UInt32(kVK_LeftArrow): return "←"
            case UInt32(kVK_RightArrow): return "→"
            case UInt32(kVK_UpArrow): return "↑"
            case UInt32(kVK_DownArrow): return "↓"
            case UInt32(kVK_Home): return "↖"
            case UInt32(kVK_End): return "↘"
            case UInt32(kVK_PageUp): return "⇞"
            case UInt32(kVK_PageDown): return "⇟"
            case UInt32(kVK_F1): return "F1"
            case UInt32(kVK_F2): return "F2"
            case UInt32(kVK_F3): return "F3"
            case UInt32(kVK_F4): return "F4"
            case UInt32(kVK_F5): return "F5"
            case UInt32(kVK_F6): return "F6"
            case UInt32(kVK_F7): return "F7"
            case UInt32(kVK_F8): return "F8"
            case UInt32(kVK_F9): return "F9"
            case UInt32(kVK_F10): return "F10"
            case UInt32(kVK_F11): return "F11"
            case UInt32(kVK_F12): return "F12"
            case UInt32(kVK_F13): return "F13"
            case UInt32(kVK_F14): return "F14"
            case UInt32(kVK_F15): return "F15"
            case UInt32(kVK_F16): return "F16"
            case UInt32(kVK_F17): return "F17"
            case UInt32(kVK_F18): return "F18"
            case UInt32(kVK_F19): return "F19"
            default: return nil
            }
        }

        private static func translatedKeySymbol(keyCode: UInt32) -> String? {
            guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue()
                ?? TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
            else { return nil }
            guard let layoutPointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
                return nil
            }
            let layoutData = Unmanaged<CFData>.fromOpaque(layoutPointer).takeUnretainedValue() as Data
            var deadKeyState: UInt32 = 0
            var actualLength: Int = 0
            var chars = [UniChar](repeating: 0, count: 4)
            let status: OSStatus = layoutData.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> OSStatus in
                guard let base = raw.baseAddress else { return OSStatus(paramErr) }
                let layout = base.assumingMemoryBound(to: UCKeyboardLayout.self)
                return UCKeyTranslate(
                    layout,
                    UInt16(keyCode),
                    UInt16(kUCKeyActionDisplay),
                    0,
                    UInt32(LMGetKbdType()),
                    OptionBits(kUCKeyTranslateNoDeadKeysMask),
                    &deadKeyState,
                    4,
                    &actualLength,
                    &chars
                )
            }
            guard status == noErr, actualLength > 0 else { return nil }
            let string = String(utf16CodeUnits: chars, count: Int(actualLength))
            return string.count == 1 ? string.uppercased() : string
        }
    }

    private static let symbolCache = SymbolCache()
}
