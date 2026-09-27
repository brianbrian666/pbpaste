import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor
final class HotkeyRecorderView: NSView {
    enum RecorderState {
        case idle
        case recording
        case invalid(String)
    }

    var current: KeyCombo = .default
    var onRecordingChanged: (Bool) -> Void = { _ in }
    var onApply: (KeyCombo) -> Void = { _ in }

    private var state: RecorderState = .idle {
        didSet { needsDisplay = true }
    }
    private var liveModifiers: NSEvent.ModifierFlags = []

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 150, height: 24) }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.75, dy: 0.75), xRadius: 5, yRadius: 5)
        NSColor.textBackgroundColor.setFill()
        path.fill()

        switch state {
        case .recording:
            NSColor.controlAccentColor.setStroke()
        case .invalid:
            NSColor.systemRed.setStroke()
        case .idle:
            NSColor.separatorColor.setStroke()
        }
        path.lineWidth = state.isRecording ? 2 : 1
        path.stroke()

        let text: String
        var font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        var color = NSColor.labelColor
        switch state {
        case .idle:
            text = current.displayString
        case .recording:
            let prompt = String(localized: "Press keys…")
            let symbols = liveModifierSymbols
            text = symbols.isEmpty ? prompt : symbols + " " + prompt
        case .invalid(let message):
            text = message
            font = NSFont.systemFont(ofSize: 11)
            color = NSColor.systemRed
        }
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = text.size(withAttributes: attributes)
        text.draw(
            at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2),
            withAttributes: attributes
        )
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        switch state {
        case .recording:
            cancelRecording()
        case .idle, .invalid:
            state = .recording
            liveModifiers = []
            onRecordingChanged(true)
        }
    }

    override func resignFirstResponder() -> Bool {
        cancelRecording()
        return true
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = KeyCombo.carbonModifiers(from: event.modifierFlags)
        if event.keyCode == UInt16(kVK_Escape) {
            cancelRecording()
            return
        }
        if event.keyCode == UInt16(kVK_Tab), modifiers == 0 {
            // Swallow a bare Tab so focus cannot escape the view mid-recording.
            return
        }
        if (event.keyCode == UInt16(kVK_Delete) || event.keyCode == UInt16(kVK_ForwardDelete)),
           modifiers == 0 {
            cancelRecording()
            return
        }
        guard modifiers != 0 || KeyCombo.isFunctionKey(UInt32(event.keyCode)) else {
            NSSound.beep()
            state = .invalid(String(localized: "Shortcut needs ⌘, ⌃, ⌥, or a function key."))
            return
        }
        let combo = KeyCombo(keyCode: UInt32(event.keyCode), carbonModifiers: modifiers)
        current = combo
        state = .idle
        liveModifiers = []
        onRecordingChanged(false)
        onApply(combo)
    }

    override func flagsChanged(with event: NSEvent) {
        guard case .recording = state else { return }
        liveModifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        needsDisplay = true
    }

    private func cancelRecording() {
        guard case .recording = state else { return }
        state = .idle
        liveModifiers = []
        onRecordingChanged(false)
    }

    private var liveModifierSymbols: String {
        var symbols = ""
        if liveModifiers.contains(.control) { symbols += "⌃" }
        if liveModifiers.contains(.option) { symbols += "⌥" }
        if liveModifiers.contains(.shift) { symbols += "⇧" }
        if liveModifiers.contains(.command) { symbols += "⌘" }
        return symbols
    }
}

extension HotkeyRecorderView.RecorderState {
    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }
}

struct HotkeyRecorder: NSViewRepresentable {
    var current: KeyCombo
    var onRecordingChanged: (Bool) -> Void
    var onApply: (KeyCombo) -> Void

    func makeNSView(context: Context) -> HotkeyRecorderView {
        let view = HotkeyRecorderView()
        view.current = current
        view.onRecordingChanged = onRecordingChanged
        view.onApply = onApply
        return view
    }

    func updateNSView(_ nsView: HotkeyRecorderView, context: Context) {
        nsView.current = current
        nsView.onRecordingChanged = onRecordingChanged
        nsView.onApply = onApply
    }
}
