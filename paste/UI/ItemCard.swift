import AppKit
import SwiftUI

struct ItemCard: View {
    let item: ClipItem
    let isSelected: Bool

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            preview
            title
                .font(.body)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            metadata
        }
        .padding(PanelMetrics.cardPadding)
        .frame(width: PanelMetrics.cardWidth, height: PanelMetrics.cardHeight)
        .background(
            RoundedRectangle(cornerRadius: PanelMetrics.cardCornerRadius, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PanelMetrics.cardCornerRadius, style: .continuous)
                .strokeBorder(borderColor, lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: PanelMetrics.cardCornerRadius, style: .continuous))
        .onHover { isHovering = $0 }
        .help(helpText)
    }

    private var backgroundColor: Color {
        if isSelected { return Color.accentColor.opacity(0.20) }
        if isHovering { return Color.primary.opacity(0.07) }
        return Color.primary.opacity(0.03)
    }

    private var borderColor: Color {
        if isSelected { return Color.accentColor }
        if isHovering { return .white.opacity(0.18) }
        return .white.opacity(0.08)
    }

    @ViewBuilder
    private var preview: some View {
        Group {
            switch item.kind {
            case .text:
                placeholderBackground {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                }

            case .image:
                if let nsImage = thumbnail {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    placeholderBackground {
                        Image(systemName: "photo")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                    }
                }

            case .files:
                if let firstURL = item.fileURLs.first, let nsImage = ThumbnailCache.fileThumbnail(for: firstURL) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if let firstURL = item.fileURLs.first {
                    placeholderBackground {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: firstURL.path))
                            .resizable()
                            .frame(width: 80, height: 80)
                    }
                } else {
                    placeholderBackground {
                        Image(systemName: "doc")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(width: PanelMetrics.previewWidth, height: PanelMetrics.previewHeight)
        .clipShape(RoundedRectangle(cornerRadius: PanelMetrics.previewCornerRadius, style: .continuous))
        .overlay(alignment: .topTrailing) { pinBadge.padding(4) }
    }

    private func placeholderBackground<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Rectangle().fill(Color.primary.opacity(0.06))
            content()
        }
    }

    @ViewBuilder
    private var pinBadge: some View {
        if item.isPinned {
            Image(systemName: "pin.fill")
                .font(.system(size: 11))
                .foregroundStyle(Color.accentColor)
                .padding(4)
                .background(Circle().fill(.thinMaterial))
        } else if isHovering {
            Image(systemName: "pin")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .padding(4)
                .background(Circle().fill(.thinMaterial))
        }
    }

    @ViewBuilder
    private var title: some View {
        switch item.kind {
        case .text:
            Text(String((item.text ?? "").prefix(400)))
        case .image:
            Text("Image")
        case .files:
            Text(item.fileURLs.first?.lastPathComponent ?? String(localized: "\(item.fileURLs.count) files"))
        }
    }

    private var metadata: some View {
        HStack(spacing: 4) {
            if let appIcon = SourceAppIcon.icon(for: item.sourceAppBundleID) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 14, height: 14)
            }
            Text(RelativeTime.string(for: item.createdAt))
            Spacer(minLength: 0)
            if item.kind == .files, item.fileURLs.count > 1 {
                Text(String(localized: "\(item.fileURLs.count) files"))
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    private var thumbnail: NSImage? {
        guard item.kind == .image else { return nil }
        return ThumbnailCache.thumbnail(for: item)
    }

    private var helpText: String {
        var lines: [String] = []
        if let sourceAppName = item.sourceAppName {
            lines.append(sourceAppName)
        }
        if item.kind == .image, let size = ThumbnailCache.pixelSize(for: item) {
            lines.append("\(Int(size.width)) × \(Int(size.height))")
        }
        if item.kind == .files, let firstURL = item.fileURLs.first {
            lines.append(firstURL.path)
        }
        return lines.joined(separator: "\n")
    }
}

@MainActor
private enum RelativeTime {
    private static let formatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    static func string(for date: Date) -> String {
        formatter.localizedString(for: date, relativeTo: .now)
    }
}

@MainActor
private enum SourceAppIcon {
    private static let cache = NSCache<NSString, NSImage>()

    static func icon(for bundleID: String?) -> NSImage? {
        guard let bundleID else { return nil }
        if let cached = cache.object(forKey: bundleID as NSString) {
            return cached
        }
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        cache.setObject(icon, forKey: bundleID as NSString)
        return icon
    }
}
