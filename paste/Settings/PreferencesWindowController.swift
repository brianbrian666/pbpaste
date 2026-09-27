import AppKit
import SwiftUI

@MainActor
final class PreferencesWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    var onWindowWillClose: (() -> Void)?

    init(view: PreferencesView) {
        let hosting = NSHostingView(rootView: view)
        hosting.sizingOptions = []
        let rect = NSRect(x: 0, y: 0, width: 400, height: 320)
        let window = NSWindow(contentRect: rect, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.contentView = hosting
        window.title = String(localized: "pbpaste Settings")
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
        super.init()
        window.delegate = self
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        if let hosting = window.contentView as? NSHostingView<PreferencesView> {
            window.setContentSize(hosting.fittingSize)
        }
        window.makeKeyAndOrderFront(nil)
    }

    // If the window is closed mid-recording the hotkey registration must come back.
    func windowWillClose(_ notification: Notification) {
        onWindowWillClose?()
    }
}
