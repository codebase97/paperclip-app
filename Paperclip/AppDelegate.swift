import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var hotkeyManager: HotkeyManager!
    private var clipboardWatcher: ClipboardWatcher!
    private var pastePickerWindow: NSWindow?
    private var cachedItems: [StackItem] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "paperclip", accessibilityDescription: "Paperclip")
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Create popover with stack view
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: StackView())

        // Create right-click menu
        setupMenu()

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

    private func setupMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Paperclip", action: #selector(showPopover), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Paperclip", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = nil  // Don't show menu on left click
    }

    @objc func handleClick() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // Right click: show menu
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Open Paperclip", action: #selector(showPopover), keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit Paperclip", action: #selector(quitApp), keyEquivalent: "q"))
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil  // Reset so left click works normally
        } else {
            // Left click: toggle popover
            togglePopover()
        }
    }

    @objc func showPopover() {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
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

    @objc func quitApp() {
        NSApp.terminate(nil)
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

    /// Show paste picker (⌘⌥V)
    private func pullAndPaste() {
        Task { @MainActor in
            do {
                let response = try await PaperclipService.shared.getStack(limit: 10)
                self.cachedItems = response.items
                self.showPastePicker()
            } catch {
                Logger.log("❌ Failed to load stack: \(error)")
            }
        }
    }

    private func showPastePicker() {
        // Close existing picker if open
        pastePickerWindow?.close()

        // Get mouse location for positioning
        let mouseLocation = NSEvent.mouseLocation

        // Create picker view
        let pickerView = PastePickerView(items: cachedItems) { [weak self] selectedItem in
            self?.pasteItem(selectedItem)
            self?.pastePickerWindow?.close()
            self?.pastePickerWindow = nil
        } onCancel: { [weak self] in
            self?.pastePickerWindow?.close()
            self?.pastePickerWindow = nil
        }

        let hostingView = NSHostingView(rootView: pickerView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 340, height: min(400, CGFloat(cachedItems.count * 60 + 50)))

        // Create window
        let window = NSPanel(
            contentRect: hostingView.frame,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.hasShadow = true

        // Position near mouse
        let windowFrame = NSRect(
            x: mouseLocation.x - 170,
            y: mouseLocation.y - hostingView.frame.height,
            width: hostingView.frame.width,
            height: hostingView.frame.height
        )
        window.setFrame(windowFrame, display: true)

        pastePickerWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func pasteItem(_ item: StackItem) {
        copyToClipboard(item.content)
        clipboardWatcher?.markAsPulled(item.content)

        // Small delay then paste
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.simulatePaste()
            Logger.log("📋 Pasted: \(item.content.prefix(50))...")
        }
    }

    /// Push clipboard contents (⌘⌥P)
    private func pushSelection() {
        let pasteboard = NSPasteboard.general

        guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
            Logger.log("⚠️ Nothing on clipboard to push")
            showNotification(title: "Paperclip", message: "Nothing on clipboard to push")
            return
        }

        Task {
            do {
                let response = try await PaperclipService.shared.push(content: text, type: "clipboard")
                Logger.log("📤 Pushed: \(text.prefix(50))...")
                await MainActor.run {
                    showNotification(title: "Pushed to Paperclip", message: "\(text.prefix(40))...")
                }
            } catch {
                Logger.log("❌ Push failed: \(error)")
                await MainActor.run {
                    showNotification(title: "Push Failed", message: error.localizedDescription)
                }
            }
        }
    }

    private func showNotification(title: String, message: String) {
        // Create a brief HUD-style notification
        let hudWindow = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 60),
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        hudWindow.isOpaque = false
        hudWindow.backgroundColor = .clear
        hudWindow.level = .floating
        hudWindow.hasShadow = true

        let hudView = NSHostingView(rootView: HUDNotificationView(title: title, message: message))
        hudView.frame = hudWindow.contentView!.bounds
        hudWindow.contentView = hudView

        // Center on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 140
            let y = screenFrame.maxY - 100
            hudWindow.setFrameOrigin(NSPoint(x: x, y: y))
        }

        hudWindow.orderFront(nil)

        // Auto-dismiss after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            hudWindow.close()
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
