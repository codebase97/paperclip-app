import AppKit

/// Watches clipboard for changes and auto-pushes displaced items to Paperclip
class ClipboardWatcher {
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private var lastContent: String?
    private var isEnabled: Bool = true

    /// Content that was just pulled from Paperclip (don't re-push it)
    private var recentlyPulled: Set<String> = []
    private let recentlyPulledLimit = 10

    func start() {
        lastChangeCount = NSPasteboard.general.changeCount
        lastContent = NSPasteboard.general.string(forType: .string)

        // Poll every 0.5 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }

        Logger.log("👀 Clipboard watcher started")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    /// Mark content as recently pulled (won't be auto-pushed)
    func markAsPulled(_ content: String) {
        recentlyPulled.insert(content)

        // Limit the set size
        if recentlyPulled.count > recentlyPulledLimit {
            recentlyPulled.removeFirst()
        }
    }

    private func checkClipboard() {
        guard isEnabled else { return }

        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount

        guard currentChangeCount != lastChangeCount else { return }

        lastChangeCount = currentChangeCount

        guard let newContent = pasteboard.string(forType: .string),
              !newContent.isEmpty else { return }

        // Don't push if it's the same content
        guard newContent != lastContent else { return }

        // Don't push if this was recently pulled from Paperclip
        guard !recentlyPulled.contains(newContent) else {
            Logger.log("⏭️ Skipping push - content was recently pulled")
            return
        }

        // Push the displaced content (what was there before)
        if let displaced = lastContent, !displaced.isEmpty {
            pushDisplaced(displaced)
        }

        lastContent = newContent
    }

    private func pushDisplaced(_ content: String) {
        Task {
            do {
                try await PaperclipService.shared.push(
                    content: content,
                    type: "clipboard",
                    mimeType: "text/plain"
                )
                Logger.log("📤 Auto-pushed displaced: \(content.prefix(40))...")
            } catch {
                Logger.log("❌ Auto-push failed: \(error)")
            }
        }
    }

    deinit {
        stop()
    }
}
