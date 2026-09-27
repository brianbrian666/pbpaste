import AppKit
import Carbon.HIToolbox

enum PanelKeyCommand {
    case selectPrevious
    case selectNext
    case paste
    case pasteAsPlainText
    case dismiss
}

@MainActor
final class HistoryPanel: NSPanel {
    var keyHandler: ((PanelKeyCommand) -> Void)?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        keyHandler?(.dismiss)
    }

    // Intercepts strip-navigation keys before the search field's field editor swallows them.
    override func sendEvent(_ event: NSEvent) {
        guard event.type == .keyDown, let keyHandler else {
            super.sendEvent(event)
            return
        }
        let code = Int(event.keyCode)

        // Plain arrows drive the card strip; modified arrows stay with the field editor (caret/word/selection).
        if code == kVK_LeftArrow || code == kVK_RightArrow || code == kVK_UpArrow || code == kVK_DownArrow {
            guard event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty else {
                super.sendEvent(event)
                return
            }
            let isBackward = code == kVK_LeftArrow || code == kVK_UpArrow
            keyHandler(isBackward ? .selectPrevious : .selectNext)
            return
        }

        let hardModifiers = event.modifierFlags.intersection([.command, .control])
        switch code {
        case kVK_Return:
            guard hardModifiers.isEmpty else {
                super.sendEvent(event)
                return
            }
            keyHandler(event.modifierFlags.contains(.option) ? .pasteAsPlainText : .paste)
        case kVK_Escape:
            keyHandler(.dismiss)
        default:
            super.sendEvent(event)
        }
    }
}
