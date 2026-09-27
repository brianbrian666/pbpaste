import Foundation
import Observation

@MainActor
@Observable
final class PanelListModel {
    var searchText = "" {
        didSet { selectedIndex = 0 }
    }

    var timeFilter: TimeFilter = .all {
        didSet { selectedIndex = 0 }
    }

    var items: [ClipItem] = [] {
        didSet { clampSelection() }
    }

    var selectedIndex = 0

    var filteredItems: [ClipItem] {
        var matching = items.filter { $0.matchesSearch(searchText) }
        if let cutoff = timeFilter.cutoff {
            matching = matching.filter { $0.createdAt >= cutoff }
        }
        let pinned = matching.filter(\.isPinned)
        let unpinned = matching.filter { !$0.isPinned }
        return pinned + unpinned
    }

    var selectedItem: ClipItem? {
        let filtered = filteredItems
        guard filtered.indices.contains(selectedIndex) else { return nil }
        return filtered[selectedIndex]
    }

    /// Previous/next are strip positions: index 0 is the leftmost card.
    func selectPrevious() {
        selectedIndex = max(0, selectedIndex - 1)
    }

    func selectNext() {
        selectedIndex = min(max(0, filteredItems.count - 1), selectedIndex + 1)
    }

    private func clampSelection() {
        selectedIndex = min(max(0, selectedIndex), max(0, filteredItems.count - 1))
    }
}
