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
    static func migrateIfNeeded(to target: StoreLocation) throws {
        try migrateLegacyLocalDirectoryIfNeeded()

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
        // Do not proceed with a partial migration. The source stays intact and the
        // caller will leave lastStoreLocation unchanged, so the copy is retried on
        // the next launch.
        if fileManager.fileExists(atPath: targetDirectory.path) {
            let backup = targetDirectory
                .deletingLastPathComponent()
                .appending(path: "\(targetDirectory.lastPathComponent).migration-backup-\(UUID().uuidString)")
            try fileManager.moveItem(at: targetDirectory, to: backup)
        }
        try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)

        // Copy order: SUPPORT blobs → WAL → store file last as the completion marker,
        // so a crash mid-copy is retried next launch. -shm is rebuilt by SQLite from
        // the WAL and is never copied.
        try copySupportDirectory(from: sourceDirectory, to: targetDirectory)
        try copyIfPresent("\(storeFileName)-wal", from: sourceDirectory, to: targetDirectory)
        try copyIfPresent(storeFileName, from: sourceDirectory, to: targetDirectory)
        // ClipboardStore records the new location only after ModelContainer opens.
    }

    /// One-time rename of the Application Support directory (MyApp → pbpaste): copies
    /// the store into the new directory when only the legacy one has it. The legacy
    /// directory is kept as a backup.
    private static func migrateLegacyLocalDirectoryIfNeeded() throws {
        let fileManager = FileManager.default
        let newStore = localDirectoryURL.appending(path: storeFileName)
        let legacyStore = legacyLocalDirectoryURL.appending(path: storeFileName)
        guard !fileManager.fileExists(atPath: newStore.path),
              fileManager.fileExists(atPath: legacyStore.path) else { return }

        try fileManager.createDirectory(at: localDirectoryURL, withIntermediateDirectories: true)
        // A prior interrupted attempt may have left support/WAL files behind.
        // Remove only those incomplete destination files before retrying.
        let supportName = ".\((storeFileName as NSString).deletingPathExtension)_SUPPORT"
        for name in [supportName, "\(storeFileName)-wal"] {
            let destination = localDirectoryURL.appending(path: name)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
        }
        try copySupportDirectory(from: legacyLocalDirectoryURL, to: localDirectoryURL)
        try copyIfPresent("\(storeFileName)-wal", from: legacyLocalDirectoryURL, to: localDirectoryURL)
        try copyIfPresent(storeFileName, from: legacyLocalDirectoryURL, to: localDirectoryURL)
    }

    // SwiftData keeps .externalStorage blobs in a sibling ".\(base)_SUPPORT" directory;
    // without it, image clips fault on access.
    private static func copySupportDirectory(from source: URL, to target: URL) throws {
        let base = (storeFileName as NSString).deletingPathExtension
        try copyIfPresent(".\(base)_SUPPORT", from: source, to: target)
    }

    private static func copyIfPresent(_ name: String, from source: URL, to target: URL) throws {
        let sourceURL = source.appending(path: name)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return }
        try FileManager.default.copyItem(at: sourceURL, to: target.appending(path: name))
    }
}
