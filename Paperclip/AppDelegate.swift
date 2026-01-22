import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var hotkeyManager: HotkeyManager!
    private var clipboardWatcher: ClipboardWatcher!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "paperclip", accessibilityDescription: "Paperclip")
            button.action = #selector(togglePopover)
        }

        // Create popover with stack view
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: StackView())

        // Setup hotkeys
        hotkeyManager = HotkeyManager()
        hotkeyManager.onPull = { [weak self] in
            self?.pullFromStack()
        }
        hotkeyManager.onPullAndPaste = { [weak self] in
            self?.pullAndPaste()
        }
        hotkeyManager.onPush = { [weak self] in
            self?.pushSelection()
        }
        hotkeyManager.start()

        // Setup clipboard watcher (auto-push displaced items)
        clipboardWatcher = ClipboardWatcher()
        clipboardWatcher.start()

        Logger.log("📎 Paperclip started")
    }

    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    // MARK: - Stack Operations

    /// Pull latest item to clipboard (⌘⌥C)
    private func pullFromStack() {
        Task {
            do {
                let item = try await PaperclipService.shared.peek()
                copyToClipboard(item.content)
                Logger.log("📋 Pulled: \(item.content.prefix(50))...")
            } catch {
                Logger.log("❌ Pull failed: \(error)")
            }
        }
    }

    /// Pull and paste (⌘⌥V)
    private func pullAndPaste() {
        Task {
            do {
                let item = try await PaperclipService.shared.peek()
                copyToClipboard(item.content)

                // Small delay then paste
                try await Task.sleep(nanoseconds: 100_000_000)
                simulatePaste()

                Logger.log("📋 Pulled and pasted: \(item.content.prefix(50))...")
            } catch {
                Logger.log("❌ Pull+paste failed: \(error)")
            }
        }
    }

    /// Push current selection (⌘⌥P)
    private func pushSelection() {
        // Get current selection via clipboard
        let pasteboard = NSPasteboard.general

        // Save current clipboard
        let savedContent = pasteboard.string(forType: .string)

        // Simulate Cmd+C to copy selection
        simulateCopy()

        // Wait for clipboard to update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            if let text = pasteboard.string(forType: .string), text != savedContent {
                // Push to Paperclip
                Task {
                    do {
                        try await PaperclipService.shared.push(content: text, type: "text")
                        Logger.log("📤 Pushed selection: \(text.prefix(50))...")
                    } catch {
                        Logger.log("❌ Push failed: \(error)")
                    }
                }
            }

            // Restore original clipboard
            if let saved = savedContent {
                pasteboard.clearContents()
                pasteboard.setString(saved, forType: .string)
            }
        }
    }

    // MARK: - Helpers

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func simulateCopy() {
        let keyCode: CGKeyCode = 8 // 'C' key
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else { return }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private func simulatePaste() {
        let keyCode: CGKeyCode = 9 // 'V' key
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else { return }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
