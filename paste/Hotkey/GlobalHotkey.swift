import AppKit
import Carbon.HIToolbox

@MainActor
final class GlobalHotkey {
    private static let signature: OSType = 0x434C4950  // 'CLIP'

    private let handler: () -> Void
    private var keyCode: UInt32
    private var modifiers: UInt32

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    init(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.handler = handler

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr, hotKeyID.signature == GlobalHotkey.signature else { return noErr }
                let instance = Unmanaged<GlobalHotkey>.fromOpaque(userData).takeUnretainedValue()
                MainActor.assumeIsolated {
                    instance.handler()
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        var hotKeyID = EventHotKeyID(signature: Self.signature, id: 1)
        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
    }

    // Swaps the registered combo atomically; on failure re-registers the previous
    // combo so the hotkey keeps working. The installed event handler stays put —
    // it routes by signature and is independent of any particular registration.
    @discardableResult
    func update(keyCode newKeyCode: UInt32, modifiers newModifiers: UInt32) -> OSStatus {
        let previousKeyCode = keyCode
        let previousModifiers = modifiers
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        var id = EventHotKeyID(signature: Self.signature, id: 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(newKeyCode, newModifiers, id, GetEventDispatcherTarget(), 0, &ref)
        if status == noErr {
            keyCode = newKeyCode
            modifiers = newModifiers
            hotKeyRef = ref
        } else {
            var restoreRef: EventHotKeyRef?
            if RegisterEventHotKey(previousKeyCode, previousModifiers, id, GetEventDispatcherTarget(), 0, &restoreRef) == noErr {
                hotKeyRef = restoreRef
            }
        }
        return status
    }

    // Removes the registration (while a recorder captures keys) without tearing
    // down the event handler. The registered combo is otherwise swallowed by the
    // Carbon hotkey machinery and never reaches the recorder's keyDown.
    func suspendRegistration() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    @discardableResult
    func resumeRegistration() -> OSStatus {
        guard hotKeyRef == nil else { return noErr }
        var id = EventHotKeyID(signature: Self.signature, id: 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, id, GetEventDispatcherTarget(), 0, &ref)
        if status == noErr {
            hotKeyRef = ref
        }
        return status
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }
}

extension GlobalHotkey {
    static let commandShift: UInt32 = UInt32(cmdKey | shiftKey)
}
