import AppKit
import ApplicationServices

enum AccessibilityPermission {
    struct Status {
        let accessibility: Bool
        let inputMonitoring: Bool

        var isFullyGranted: Bool { accessibility && inputMonitoring }

        var missingDescription: String {
            var missing: [String] = []
            if !accessibility { missing.append("輔助使用") }
            if !inputMonitoring { missing.append("輸入監控") }
            return missing.joined(separator: "、")
        }
    }

    static var status: Status {
        Status(
            accessibility: AXIsProcessTrusted() && CGPreflightPostEventAccess(),
            inputMonitoring: CGPreflightListenEventAccess()
        )
    }

    static var isGranted: Bool {
        status.isFullyGranted
    }

    @discardableResult
    static func requestIfNeeded() -> Bool {
        let current = status
        if !current.accessibility {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
            _ = CGRequestPostEventAccess()
        }
        if !current.inputMonitoring {
            _ = CGRequestListenEventAccess()
        }
        return status.isFullyGranted
    }

    static func openMissingSystemSettings() {
        let pane = status.inputMonitoring ? "Privacy_Accessibility" : "Privacy_ListenEvent"
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
