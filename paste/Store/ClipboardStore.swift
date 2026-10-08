import Foundation
import SwiftData

@MainActor
final class ClipboardStore {
    static let maxUnpinnedItems = 300

    let container: ModelContainer
    let usingICloud: Bool
    let iCloudContainerAvailable: Bool

    init() throws {
        let prefICloud = UserDefaults.standard.bool(forKey: PreferenceKeys.useICloudStorage)
        let containerDocuments = StoreLocation.iCloudContainerDocumentsURL
        let location = (prefICloud && containerDocuments != nil) ? StoreLocation.icloud : .local
        try StoreLocation.migrateIfNeeded(to: location)
        let directory = location.directoryURL
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let storeURL = directory.appending(path: StoreLocation.storeFileName)
        let configuration = ModelConfiguration(url: storeURL)
        container = try ModelContainer(for: ClipItem.self, configurations: configuration)
        // Record the lineage only after the container opens; a failed launch retries the move.
        UserDefaults.standard.set(location.rawValue, forKey: PreferenceKeys.lastStoreLocation)
        usingICloud = (location == .icloud)
        iCloudContainerAvailable = (containerDocuments != nil)
    }

    var context: ModelContext { container.mainContext }

    /// Inserts new content, or moves an existing duplicate to the top of the history.
    @discardableResult
    func insert(_ payload: ClipPayload) -> ClipItem? {
        let hash = payload.contentHash
        let descriptor = FetchDescriptor<ClipItem>(predicate: #Predicate { $0.contentHash == hash })

        if let existing = (try? context.fetch(descriptor))?.first {
            if !existing.isPinned {
                existing.createdAt = .now
                try? context.save()
            }
            return existing
        }

        let item = ClipItem(
            kind: payload.kind,
            text: payload.text,
            rtfData: payload.rtfData,
            imageData: payload.imageData,
            fileURLStrings: payload.fileURLs.map(\.absoluteString),
            contentHash: hash,
            isPinned: false,
            sourceAppName: payload.sourceAppName,
            sourceAppBundleID: payload.sourceAppBundleID
        )
        context.insert(item)
        pruneIfNeeded()
        pruneRetentionIfNeeded()
        try? context.save()
        return item
    }

    func togglePin(_ item: ClipItem) {
        item.isPinned.toggle()
        try? context.save()
    }

    func delete(_ item: ClipItem) {
        context.delete(item)
        try? context.save()
    }

    func clearUnpinned() {
        try? context.delete(model: ClipItem.self, where: #Predicate { !$0.isPinned })
        try? context.save()
    }

    // Deletes unpinned items older than the retention period. Pinned items are
    // exempt from retention pruning; "forever" is a cheap no-op.
    func pruneRetentionIfNeeded() {
        guard let cutoff = RetentionPeriod.current.cutoff else { return }
        try? context.delete(model: ClipItem.self, where: #Predicate<ClipItem> { !$0.isPinned && $0.createdAt < cutoff })
        try? context.save()
    }

    private func pruneIfNeeded() {
        let unpinned = FetchDescriptor<ClipItem>(
            predicate: #Predicate { !$0.isPinned },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        guard let count = try? context.fetchCount(unpinned), count > Self.maxUnpinnedItems else { return }

        var overflow = FetchDescriptor<ClipItem>(
            predicate: #Predicate { !$0.isPinned },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        overflow.fetchLimit = count - Self.maxUnpinnedItems
        for item in (try? context.fetch(overflow)) ?? [] {
            context.delete(item)
        }
    }
}
