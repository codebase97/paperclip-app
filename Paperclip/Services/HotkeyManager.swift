import AppKit
import Carbon

/// Manages global hotkeys for Paperclip
class HotkeyManager {
    var onPull: (() -> Void)?      // ⌘⌥C
    var onPullAndPaste: (() -> Void)?  // ⌘⌥V
    var onPush: (() -> Void)?      // ⌘⌥P

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func start() {
        // Request accessibility permissions
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if !trusted {
            Logger.log("⚠️ Accessibility permission needed for hotkeys")
            return
        }

        // Create event tap for key events
        let eventMask = (1 << CGEventType.keyDown.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap = eventTap else {
            Logger.log("❌ Failed to create event tap")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        Logger.log("✅ Hotkeys registered")
    }

    func stop() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }

        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // Check for Cmd+Opt modifier
        let cmdOpt: CGEventFlags = [.maskCommand, .maskAlternate]
        guard flags.contains(cmdOpt) else {
            return Unmanaged.passRetained(event)
        }

        // Remove other modifiers for comparison
        let relevantFlags = flags.intersection([.maskCommand, .maskAlternate, .maskShift, .maskControl])
        guard relevantFlags == cmdOpt else {
            return Unmanaged.passRetained(event)
        }

        switch keyCode {
        case 8:  // C key - Pull to clipboard
            Logger.log("🔑 ⌘⌥C pressed")
            DispatchQueue.main.async { [weak self] in
                self?.onPull?()
            }
            return nil  // Consume event

        case 9:  // V key - Pull and paste
            Logger.log("🔑 ⌘⌥V pressed")
            DispatchQueue.main.async { [weak self] in
                self?.onPullAndPaste?()
            }
            return nil  // Consume event

        case 35: // P key - Push selection
            Logger.log("🔑 ⌘⌥P pressed")
            DispatchQueue.main.async { [weak self] in
                self?.onPush?()
            }
            return nil  // Consume event

        default:
            return Unmanaged.passRetained(event)
        }
    }

    deinit {
        stop()
    }
}
