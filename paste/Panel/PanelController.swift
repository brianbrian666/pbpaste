import AppKit
import SwiftData
import SwiftUI

@MainActor
final class KeyCommandRelay {
    var handler: ((PanelKeyCommand) -> Void)?

    func forward(_ command: PanelKeyCommand) {
        handler?(command)
    }
}

extension Notification.Name {
    static let clipPanelDidShow = Notification.Name("ClipPanelDidShow")
}

@MainActor
final class PanelController {
    private let monitor: ClipboardMonitor
    private let panel: HistoryPanel
    private let relay = KeyCommandRelay()
    private var hideWorkItem: DispatchWorkItem?

    var isVisible: Bool { panel.isVisible }

    init(store: ClipboardStore, monitor: ClipboardMonitor) {
        self.monitor = monitor

        let initialSize = NSSize(width: PanelMetrics.maxPanelWidth, height: PanelMetrics.panelHeight)
        let panel = HistoryPanel(contentRect: NSRect(origin: .zero, size: initialSize))
        self.panel = panel
        panel.keyHandler = { [relay] command in relay.forward(command) }

        let rootView = HistoryView(
            relay: relay,
            onPaste: { [weak self] item, plainTextOnly in
                self?.performPaste(item, plainTextOnly: plainTextOnly)
            },
            onDismiss: { [weak self] in
                self?.hide()
            }
        )
        .modelContainer(store.container)

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: initialSize)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.sizingOptions = []
        panel.contentView = hostingView

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelDidResignKey),
            name: NSWindow.didResignKeyNotification,
            object: panel
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelDidBecomeKey),
            name: NSWindow.didBecomeKeyNotification,
            object: panel
        )
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        applyFrameForMouseScreen()
        panel.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .clipPanelDidShow, object: nil)
        }
    }

    func hide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        panel.orderOut(nil)
    }

    private var lastAccessibilityPrompt: Date?

    private func performPaste(_ item: ClipItem, plainTextOnly: Bool) {
        PasteboardWriter.write(item, plainTextOnly: plainTextOnly)
        monitor.acknowledgeOwnWrite()
        hide()

        guard Paster.isAccessibilityTrusted else {
            // Degraded mode: the item is on the clipboard but cannot be typed into the
            // previous app. Re-prompt at most every 30 s so repeated clicks still
            // explain themselves without stacking modal alerts.
            if let lastAccessibilityPrompt, Date().timeIntervalSince(lastAccessibilityPrompt) < 30 { return }
            lastAccessibilityPrompt = Date()
            showAccessibilityAlert()
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            MainActor.assumeIsolated {
                Paster.simulatePaste()
            }
        }
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Accessibility Permission Required")
        alert.informativeText = String(
            localized: "Pasting directly needs Accessibility access. Grant it in System Settings > Privacy & Security > Accessibility; until then, items are only copied to the clipboard."
        )
        alert.addButton(withTitle: String(localized: "Open System Settings"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn,
           let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(settingsURL)
        }
    }

    private func applyFrameForMouseScreen() {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else { return }
        panel.setFrame(PanelMetrics.panelFrame(for: visibleFrame), display: false)
    }

    @objc private func panelDidResignKey(_ notification: Notification) {
        // Front apps (especially with an active IME composition) sometimes yank key
        // status back the instant the panel takes it. Debounce: only hide if the
        // panel stays resigned — a becomeKey within the window cancels the hide.
        hideWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, !self.panel.isKeyWindow else { return }
            self.hide()
        }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: item)
    }

    // Re-asserts search-field focus whenever the panel takes key status.
    @objc private func panelDidBecomeKey(_ notification: Notification) {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        NotificationCenter.default.post(name: .clipPanelDidShow, object: nil)
    }
}
