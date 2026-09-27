import AppKit

@MainActor
enum PasteboardWriter {
    static func write(_ item: ClipItem, plainTextOnly: Bool) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.kind {
        case .text:
            var types: [NSPasteboard.PasteboardType] = []
            if !plainTextOnly, item.rtfData != nil { types.append(.rtf) }
            if item.text != nil { types.append(.string) }
            pasteboard.declareTypes(types, owner: nil)
            if !plainTextOnly, let rtf = item.rtfData {
                pasteboard.setData(rtf, forType: .rtf)
            }
            if let text = item.text {
                pasteboard.setString(text, forType: .string)
            }

        case .image:
            guard let data = item.imageData else { return }
            pasteboard.declareTypes([.png, .tiff], owner: nil)
            pasteboard.setData(data, forType: .png)
            if let tiff = NSImage(data: data)?.tiffRepresentation {
                pasteboard.setData(tiff, forType: .tiff)
            }

        case .files:
            pasteboard.writeObjects(item.fileURLs.map { $0 as NSURL })
        }
    }
}
