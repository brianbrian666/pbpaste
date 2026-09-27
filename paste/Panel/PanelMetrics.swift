import AppKit

@MainActor
enum PanelMetrics {
    static let cardWidth: CGFloat = 198
    static let cardHeight: CGFloat = 270
    static let cardPadding: CGFloat = 10
    static let cardSpacing: CGFloat = 12
    static let cardCornerRadius: CGFloat = 14

    static let previewWidth: CGFloat = cardWidth - 2 * cardPadding
    static let previewHeight: CGFloat = 156
    static let previewCornerRadius: CGFloat = 10

    static let stripPadding: CGFloat = 16
    static let stripHeight: CGFloat = cardHeight + 2 * stripPadding

    // Initial panel size only; every show resizes the panel to the mouse screen.
    static let maxPanelWidth: CGFloat = 900
    static let bottomMargin: CGFloat = 16
    static let cornerRadius: CGFloat = 14
    static let searchBarHeight: CGFloat = 42
    static let footerHeight: CGFloat = 26
    static let panelHeight: CGFloat = searchBarHeight + stripHeight + footerHeight + 2 // 2 dividers

    static func panelFrame(for visibleFrame: NSRect) -> NSRect {
        NSRect(
            x: visibleFrame.minX,
            y: visibleFrame.minY + bottomMargin,
            width: visibleFrame.width,
            height: panelHeight
        )
    }
}
