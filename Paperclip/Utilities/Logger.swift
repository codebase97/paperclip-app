import Foundation
import os.log

/// Simple logging utility for Paperclip
enum Logger {
    private static let log = OSLog(subsystem: "cc.airbase.paperclip", category: "general")

    static func log(_ message: String) {
        os_log("%{public}@", log: log, type: .info, message)
        #if DEBUG
        print("[Paperclip] \(message)")
        #endif
    }

    static func error(_ message: String) {
        os_log("%{public}@", log: log, type: .error, message)
        #if DEBUG
        print("[Paperclip] ❌ \(message)")
        #endif
    }
}
