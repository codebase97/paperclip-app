import SwiftUI

/// Main view showing the Paperclip stack in the popover
struct StackView: View {
    @StateObject private var viewModel = StackViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "paperclip")
                    .foregroundColor(.accentColor)
                Text("Paperclip")
                    .font(.headline)
                Spacer()
                Button(action: viewModel.refresh) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.isLoading)
            }
            .padding()

            Divider()

            // Stack content
            if viewModel.isLoading && viewModel.items.isEmpty {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Spacer()
            } else if viewModel.items.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Stack is empty")
                        .foregroundColor(.secondary)
                    Text("⌘⌥P to push selection")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(viewModel.items) { item in
                            StackItemRow(item: item, onCopy: {
                                viewModel.copyItem(item)
                            })
                        }
                    }
                }
            }

            Divider()

            // Footer with hotkey hints
            HStack(spacing: 16) {
                HotkeyHint(keys: "⌘⌥C", label: "Pull")
                HotkeyHint(keys: "⌘⌥V", label: "Paste")
                HotkeyHint(keys: "⌘⌥P", label: "Push")
                Spacer()
                Text("\(viewModel.total) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(width: 320, height: 400)
        .onAppear {
            viewModel.refresh()
        }
    }
}

struct StackItemRow: View {
    let item: StackItem
    let onCopy: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.preview)
                    .lineLimit(2)
                    .font(.system(.body, design: .monospaced))

                HStack(spacing: 8) {
                    Text(item.relativeTime)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let metadata = item.metadata, let source = metadata.source {
                        Text(source)
                            .font(.caption)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.2))
                            .cornerRadius(3)
                    }
                }
            }

            Spacer()

            if isHovered {
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture(count: 2) {
            onCopy()
        }
    }
}

struct HotkeyHint: View {
    let keys: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Text(keys)
                .font(.caption)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(3)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - View Model

@MainActor
class StackViewModel: ObservableObject {
    @Published var items: [StackItem] = []
    @Published var total: Int = 0
    @Published var isLoading = false

    func refresh() {
        guard !isLoading else { return }
        isLoading = true

        Task {
            do {
                let response = try await PaperclipService.shared.getStack(limit: 20)
                self.items = response.items
                self.total = response.total
            } catch PaperclipError.stackEmpty {
                self.items = []
                self.total = 0
            } catch {
                Logger.log("❌ Failed to load stack: \(error)")
            }
            self.isLoading = false
        }
    }

    func copyItem(_ item: StackItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.content, forType: .string)
        Logger.log("📋 Copied: \(item.content.prefix(40))...")
    }
}

#Preview {
    StackView()
}
