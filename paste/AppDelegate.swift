import AppKit
import ApplicationServices
import Carbon.HIToolbox
import ServiceManagement
import SwiftUI

enum PreferenceKeys {
    static let hotkeyCode = "hotkeyCode"
    static let hotkeyModifiers = "hotkeyModifiers"
    static let retention = "retention"
    static let useICloudStorage = "useICloudStorage"
    static let lastStoreLocation = "lastStoreLocation"
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var store: ClipboardStore?
    private var monitor: ClipboardMonitor?
    private var panelController: PanelController?
    private var hotkey: GlobalHotkey?
    private var statusItem: NSStatusItem?
    private var preferencesController: PreferencesWindowController?

    private var pauseItem: NSMenuItem?
    private var launchAtLoginItem: NSMenuItem?
    private var accessibilityItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        guard let store = try? ClipboardStore() else {
            NSApp.terminate(nil)
            return
        }
        self.store = store
        store.pruneRetentionIfNeeded()

        let monitor = ClipboardMonitor(store: store)
        self.monitor = monitor
        monitor.start()

        panelController = PanelController(store: store, monitor: monitor)

        let combo = KeyCombo.stored()
        hotkey = GlobalHotkey(
            keyCode: combo.keyCode,
            modifiers: combo.carbonModifiers
        ) { [weak self] in
            self?.panelController?.toggle()
        }

        setupStatusItem()

        // The SwiftUI Settings scene injects its own empty ⌘, item into the main menu;
        // scrub it so only the status-item entry opens the real preferences window.
        DispatchQueue.main.async { [weak self] in
            self?.scrubAutoSettingsMenuItem()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stop()
        hotkey?.unregister()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "doc.on.clipboard",
            accessibilityDescription: "pbpaste"
        )
        let menu = NSMenu()
        menu.delegate = self

        let showItem = menu.addItem(
            withTitle: String(localized: "Show Clipboard History"),
            action: #selector(showHistory),
            keyEquivalent: ""
        )
        showItem.target = self

        menu.addItem(.separator())

        pauseItem = menu.addItem(
            withTitle: String(localized: "Pause Monitoring"),
            action: #selector(togglePause),
            keyEquivalent: ""
        )
        pauseItem?.target = self

        accessibilityItem = menu.addItem(
            withTitle: String(localized: "Accessibility Permission"),
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        accessibilityItem?.target = self

        launchAtLoginItem = menu.addItem(
            withTitle: String(localized: "Launch at Login"),
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginItem?.target = self

        menu.addItem(.separator())

        let clearItem = menu.addItem(
            withTitle: String(localized: "Clear History"),
            action: #selector(clearHistory),
            keyEquivalent: ""
        )
        clearItem.target = self

        let settingsItem = menu.addItem(
            withTitle: String(localized: "Settings…"),
            action: #selector(showPreferences),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = self

        menu.addItem(.separator())

        let quitItem = menu.addItem(
            withTitle: String(localized: "Quit pbpaste"),
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self

        item.menu = menu
        statusItem = item
    }

    func menuWillOpen(_ menu: NSMenu) {
        pauseItem?.state = monitor?.isPaused == true ? .on : .off
        launchAtLoginItem?.state = SMAppService.mainApp.status == .enabled ? .on : .off
        accessibilityItem?.state = Paster.isAccessibilityTrusted ? .on : .off
    }

    @objc private func showHistory() {
        panelController?.toggle()
    }

    @objc private func openAccessibilitySettings() {
        guard let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(settingsURL)
    }

    @objc private func togglePause() {
        guard let monitor else { return }
        monitor.isPaused.toggle()
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            NSSound.beep()
        }
    }

    @objc private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Clear clipboard history?")
        alert.informativeText = String(localized: "Pinned items are kept.")
        alert.addButton(withTitle: String(localized: "Clear"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            store?.clearUnpinned()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func showPreferences() {
        if preferencesController == nil {
            let view = PreferencesView(
                hotkeyCombo: KeyCombo.stored(),
                iCloudContainerAvailable: store?.iCloudContainerAvailable ?? false,
                onHotkeyRecordingChanged: { [weak self] recording in
                    self?.setHotkeyRecording(recording)
                },
                onHotkeyApply: { [weak self] combo in
                    self?.applyHotkey(combo)
                },
                onRetentionChanged: { [weak self] in
                    self?.store?.pruneRetentionIfNeeded()
                }
            )
            let controller = PreferencesWindowController(view: view)
            controller.onWindowWillClose = { [weak self] in
                self?.setHotkeyRecording(false)
            }
            preferencesController = controller
        }
        preferencesController?.show()
    }

    private func applyHotkey(_ combo: KeyCombo) {
        guard let hotkey else { return }
        // Conflicts are best-effort: Carbon hotkey registration is non-exclusive, so
        // failure here is rare and the previous combo is kept by update's rollback.
        guard hotkey.update(keyCode: combo.keyCode, modifiers: combo.carbonModifiers) == noErr else {
            NSSound.beep()
            return
        }
        combo.persist()
    }

    private func setHotkeyRecording(_ recording: Bool) {
        if recording {
            hotkey?.suspendRegistration()
        } else {
            hotkey?.resumeRegistration()
        }
    }

    private func scrubAutoSettingsMenuItem() {
        guard let mainMenu = NSApp.mainMenu else { return }
        for item in mainMenu.items {
            guard let submenu = item.submenu else { continue }
            for subitem in submenu.items where subitem.keyEquivalent == "," {
                submenu.removeItem(subitem)
            }
        }
    }
}
