import AppKit
import ApplicationServices
import Carbon.HIToolbox

@MainActor
enum Paster {
    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system permission prompt the first time; returns the current trust state.
    @discardableResult
    static func requestAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Posts ⌘V to the active app. Only meaningful after the panel has been hidden.
    static func simulatePaste() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let keyV = CGKeyCode(kVK_ANSI_V)
        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false)
        else { return }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
