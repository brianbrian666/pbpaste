import Foundation
import SwiftData

enum ClipKind: String, Codable {
    case text
    case image
    case files
}

@Model
final class ClipItem {
    var kind: ClipKind
    var text: String?
    var rtfData: Data?
    @Attribute(.externalStorage) var imageData: Data?
    var fileURLStrings: [String]
    var contentHash: String
    var createdAt: Date
    var isPinned: Bool
    var sourceAppName: String?
    var sourceAppBundleID: String?

    init(
        kind: ClipKind,
        text: String? = nil,
        rtfData: Data? = nil,
        imageData: Data? = nil,
        fileURLStrings: [String] = [],
        contentHash: String,
        createdAt: Date = .now,
        isPinned: Bool = false,
        sourceAppName: String? = nil,
        sourceAppBundleID: String? = nil
    ) {
        self.kind = kind
        self.text = text
        self.rtfData = rtfData
        self.imageData = imageData
        self.fileURLStrings = fileURLStrings
        self.contentHash = contentHash
        self.createdAt = createdAt
        self.isPinned = isPinned
        self.sourceAppName = sourceAppName
        self.sourceAppBundleID = sourceAppBundleID
    }
}

extension ClipItem {
    var fileURLs: [URL] {
        fileURLStrings.compactMap(URL.init(string:))
    }

    func matchesSearch(_ query: String) -> Bool {
        guard !query.isEmpty else { return true }
        if let text, text.localizedCaseInsensitiveContains(query) { return true }
        if fileURLStrings.contains(where: { $0.localizedCaseInsensitiveContains(query) }) { return true }
        if let sourceAppName, sourceAppName.localizedCaseInsensitiveContains(query) { return true }
        return false
    }
}
