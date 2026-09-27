import Foundation

enum StoreLocation: String {
    case local
    case icloud

    static let storeFileName = "clips.store"

    static var localDirectoryURL: URL {
        URL.applicationSupportDirectory.appending(path: "pbpaste", directoryHint: .isDirectory)
    }

    static var legacyLocalDirectoryURL: URL {
        URL.applicationSupportDirectory.appending(path: "MyApp", directoryHint: .isDirectory)
    }

    // Probing the ubiquity container requires the iCloud entitlement; this ad-hoc-signed
    // build has none, so this is nil here and storage silently stays local.
    static var iCloudContainerDocumentsURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents", isDirectory: true)
    }

    var directoryURL: URL {
        switch self {
        case .local:
            return Self.localDirectoryURL
        case .icloud:
            // Force-unwrap is safe: .icloud is only chosen after a non-nil container probe.
            return StoreLocation.iCloudContainerDocumentsURL!
        }
    }

    /// Moves the store when the location recorded at last launch differs from the
    /// location the current preferences resolve to. Runs before the ModelContainer
    /// opens; the source directory is never deleted.
    static func migrateIfNeeded(to target: StoreLocation) {
        migrateLegacyLocalDirectoryIfNeeded()

        let defaults = UserDefaults.standard
        let lastRaw = defaults.string(forKey: PreferenceKeys.lastStoreLocation)
        let last = lastRaw.flatMap(StoreLocation.init) ?? .local
        guard last != target else { return }

        let fileManager = FileManager.default
        let sourceDirectory = last.directoryURL
        let sourceStore = sourceDirectory.appending(path: storeFileName)
        // Source gone (e.g. the iCloud container vanished) or nothing to move.
        guard fileManager.fileExists(atPath: sourceStore.path) else { return }

        let targetDirectory = target.directoryURL
        try? fileManager.removeItem(at: targetDirectory)
        try? fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)

        // Copy order: SUPPORT blobs → WAL → store file last as the completion marker,
        // so a crash mid-copy is retried next launch. -shm is rebuilt by SQLite from
        // the WAL and is never copied.
        copySupportDirectory(from: sourceDirectory, to: targetDirectory)
        copyIfPresent("\(storeFileName)-wal", from: sourceDirectory, to: targetDirectory)
        copyIfPresent(storeFileName, from: sourceDirectory, to: targetDirectory)
        defaults.set(target.rawValue, forKey: PreferenceKeys.lastStoreLocation)
    }

    /// One-time rename of the Application Support directory (MyApp → pbpaste): copies
    /// the store into the new directory when only the legacy one has it. The legacy
    /// directory is kept as a backup.
    private static func migrateLegacyLocalDirectoryIfNeeded() {
        let fileManager = FileManager.default
        let newStore = localDirectoryURL.appending(path: storeFileName)
        let legacyStore = legacyLocalDirectoryURL.appending(path: storeFileName)
        guard !fileManager.fileExists(atPath: newStore.path),
              fileManager.fileExists(atPath: legacyStore.path) else { return }

        try? fileManager.createDirectory(at: localDirectoryURL, withIntermediateDirectories: true)
        copySupportDirectory(from: legacyLocalDirectoryURL, to: localDirectoryURL)
        copyIfPresent("\(storeFileName)-wal", from: legacyLocalDirectoryURL, to: localDirectoryURL)
        copyIfPresent(storeFileName, from: legacyLocalDirectoryURL, to: localDirectoryURL)
    }

    // SwiftData keeps .externalStorage blobs in a sibling ".\(base)_SUPPORT" directory;
    // without it, image clips fault on access.
    private static func copySupportDirectory(from source: URL, to target: URL) {
        let base = (storeFileName as NSString).deletingPathExtension
        copyIfPresent(".\(base)_SUPPORT", from: source, to: target)
    }

    private static func copyIfPresent(_ name: String, from source: URL, to target: URL) {
        let sourceURL = source.appending(path: name)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return }
        try? FileManager.default.copyItem(at: sourceURL, to: target.appending(path: name))
    }
}
