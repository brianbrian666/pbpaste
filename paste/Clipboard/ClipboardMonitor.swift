import AppKit

@MainActor
final class ClipboardMonitor {
    private let store: ClipboardStore
    private var timer: Timer?
    private var lastChangeCount: Int

    var isPaused = false

    init(store: ClipboardStore) {
        self.store = store
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.poll()
            }
        }
        // .common mode keeps polling while menus are open or the user is scrolling.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Moves the baseline past the pasteboard change caused by our own paste action.
    func acknowledgeOwnWrite() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    private func poll() {
        guard !isPaused else { return }
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        guard let payload = ClipPayload.read(from: pasteboard) else { return }
        store.insert(payload)
    }
}
