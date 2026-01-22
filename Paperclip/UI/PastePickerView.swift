import SwiftUI

/// Floating picker for selecting an item to paste
struct PastePickerView: View {
    let items: [StackItem]
    let onSelect: (StackItem) -> Void
    let onCancel: () -> Void

    @State private var selectedIndex: Int = 0
    @State private var searchText: String = ""

    var filteredItems: [StackItem] {
        if searchText.isEmpty {
            return items
        }
        return items.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "paperclip")
                    .foregroundColor(.blue)
                Text("Paste from Paperclip")
                    .font(.headline)
                Spacer()
                Text("⌘⌥V")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Items list
            if filteredItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text("No items")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                                PastePickerRow(
                                    item: item,
                                    isSelected: index == selectedIndex,
                                    index: index
                                )
                                .id(index)
                                .onTapGesture {
                                    onSelect(item)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: selectedIndex) { newIndex in
                        withAnimation {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }

            Divider()

            // Footer hints
            HStack(spacing: 16) {
                KeyHint(keys: "↑↓", label: "Navigate")
                KeyHint(keys: "↵", label: "Paste")
                KeyHint(keys: "esc", label: "Cancel")
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 340)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                return self.handleKeyEvent(event)
            }
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        switch event.keyCode {
        case 125: // Down arrow
            if selectedIndex < filteredItems.count - 1 {
                selectedIndex += 1
            }
            return nil
        case 126: // Up arrow
            if selectedIndex > 0 {
                selectedIndex -= 1
            }
            return nil
        case 36: // Return/Enter
            if !filteredItems.isEmpty && selectedIndex < filteredItems.count {
                onSelect(filteredItems[selectedIndex])
            }
            return nil
        case 53: // Escape
            onCancel()
            return nil
        default:
            return event
        }
    }
}

struct PastePickerRow: View {
    let item: StackItem
    let isSelected: Bool
    let index: Int

    var body: some View {
        HStack(spacing: 8) {
            // Index number
            Text("\(index + 1)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.preview)
                    .lineLimit(2)
                    .font(.system(.body, design: .default))

                HStack(spacing: 6) {
                    Text(item.relativeTime)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if let metadata = item.metadata {
                        if let source = metadata.source {
                            Text(source)
                                .font(.caption2)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(3)
                        }
                        if let device = metadata.device_name {
                            Text(device)
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(3)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(6)
        .padding(.horizontal, 4)
    }
}

struct KeyHint: View {
    let keys: String
    let label: String

    var body: some View {
        HStack(spacing: 3) {
            Text(keys)
                .font(.caption2)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(3)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}
