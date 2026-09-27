import AppKit

enum Relauncher {
    // A bare `open` would only activate the already-running instance; spawn the
    // executable directly and terminate. Termination runs applicationWillTerminate
    // (monitor stopped, hotkey unregistered, CoreData WAL checkpointed).
    static func relaunch() {
        let process = Process()
        process.executableURL = Bundle.main.executableURL
        try? process.run()
        NSApp.terminate(nil)
    }
}
