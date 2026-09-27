import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ClipItem.createdAt, order: .reverse) private var items: [ClipItem]

    @State private var listModel = PanelListModel()
    @FocusState private var searchFieldFocused: Bool

    let relay: KeyCommandRelay
    let onPaste: (ClipItem, Bool) -> Void
    let onDismiss: () -> Void

    var body: some View {
        @Bindable var model = listModel

        VStack(spacing: 0) {
            searchBar(searchText: $model.searchText)
            Divider()
            strip
            Divider()
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: PanelMetrics.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PanelMetrics.cornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
        .onAppear {
            listModel.items = items
            relay.handler = handle(_:)
            searchFieldFocused = true
        }
        .onChange(of: items) { _, newItems in
            listModel.items = newItems
        }
        .onReceive(NotificationCenter.default.publisher(for: .clipPanelDidShow)) { _ in
            listModel.searchText = ""
            listModel.timeFilter = .all
            searchFieldFocused = true
        }
    }

    private func searchBar(searchText: Binding<String>) -> some View {
        @Bindable var model = listModel

        return HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search clipboard history", text: searchText)
                .textFieldStyle(.plain)
                .focused($searchFieldFocused)
            Menu {
                Picker(String(localized: "Time Filter"), selection: $model.timeFilter) {
                    ForEach(TimeFilter.allCases, id: \.self) { filter in
                        Text(filter.label).tag(filter)
                    }
                }
            } label: {
                Label(listModel.timeFilter.label, systemImage: "clock")
            }
            .controlSize(.small)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var emptyStateText: String {
        if listModel.items.isEmpty { return String(localized: "No clipboard history yet") }
        if !listModel.searchText.isEmpty { return String(localized: "No matches") }
        return String(localized: "No items in this time range")
    }

    private var strip: some View {
        let filtered = listModel.filteredItems

        return Group {
            if filtered.isEmpty {
                Text(emptyStateText)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { geo in
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .center, spacing: PanelMetrics.cardSpacing) {
                                ForEach(filtered, id: \.persistentModelID) { item in
                                    ItemCard(
                                        item: item,
                                        isSelected: listModel.selectedItem?.persistentModelID == item.persistentModelID
                                    )
                                    .id(item.persistentModelID)
                                    .onTapGesture {
                                        onPaste(item, false)
                                    }
                                    .contextMenu {
                                        Button("Paste as Plain Text") { onPaste(item, true) }
                                        Button(item.isPinned ? "Unpin" : "Pin") {
                                            item.isPinned.toggle()
                                            try? modelContext.save()
                                        }
                                        Divider()
                                        Button("Delete", role: .destructive) {
                                            modelContext.delete(item)
                                            try? modelContext.save()
                                        }
                                    }
                                }
                            }
                            .padding(PanelMetrics.stripPadding)
                            .frame(minWidth: geo.size.width, alignment: .center)
                        }
                        .onChange(of: listModel.selectedIndex) { _, _ in
                            if let id = listModel.selectedItem?.persistentModelID {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                        .onChange(of: listModel.searchText) { _, _ in
                            if let id = listModel.filteredItems.first?.persistentModelID {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                        .onChange(of: listModel.timeFilter) { _, _ in
                            if let id = listModel.filteredItems.first?.persistentModelID {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .frame(minHeight: PanelMetrics.stripHeight)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text("←→ Select")
            Text("↩ Paste")
            Text("⌥↩ Plain Text")
            Text("⎋ Close")
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func handle(_ command: PanelKeyCommand) {
        switch command {
        case .selectPrevious:
            listModel.selectPrevious()
        case .selectNext:
            listModel.selectNext()
        case .paste:
            if let item = listModel.selectedItem { onPaste(item, false) }
        case .pasteAsPlainText:
            if let item = listModel.selectedItem { onPaste(item, true) }
        case .dismiss:
            onDismiss()
        }
    }
}
