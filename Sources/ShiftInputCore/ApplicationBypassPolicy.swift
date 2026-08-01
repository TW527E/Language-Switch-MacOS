import Foundation

/// Decides whether a ShiftInput shortcut should be left untouched for the foreground app.
///
/// The policy intentionally uses stable application metadata instead of polling
/// windows or processes, keeping the event-tap callback deterministic and cheap.
public enum ApplicationBypassPolicy {
    private static let remoteBundleIDFragments = [
        "anydesk",
        "chrome-remote-desktop",
        "chromeremotedesktop",
        "jumpdesktop",
        "logmein",
        "moonlight",
        "nomachine",
        "parsec",
        "realvnc",
        "remotedesktop",
        "rustdesk",
        "splashtop",
        "steamlink",
        "teamviewer",
        "todesk",
        "vncviewer"
    ]

    private static let remoteBundleIDs = Set([
        "com.microsoft.rdc.macos",
        "com.microsoft.windowsapp",
        "com.parallels.desktop.console",
        "com.valvesoftware.steam",
        "com.vmware.fusion"
    ])

    private static let remoteNameFragments = [
        "anydesk",
        "jump desktop",
        "microsoft remote desktop",
        "moonlight",
        "nomachine",
        "parsec",
        "remote desktop",
        "rustdesk",
        "splashtop",
        "steam link",
        "teamviewer",
        "todesk",
        "vnc viewer",
        "windows app"
    ]

    private static let gamePathFragments = [
        "/steamapps/common/",
        "/gog games/",
        "/epic games/"
    ]

    public static func shouldBypass(
        bundleIdentifier: String?,
        localizedName: String?,
        bundlePath: String?,
        applicationCategory: String?,
        excludedBundleIdentifiers: Set<String>,
        automaticBypassEnabled: Bool
    ) -> Bool {
        let normalizedBundleID = normalize(bundleIdentifier)
        if !normalizedBundleID.isEmpty,
           excludedBundleIdentifiers.contains(where: { normalize($0) == normalizedBundleID }) {
            return true
        }

        guard automaticBypassEnabled else { return false }
        return isAutomaticallyBypassed(
            bundleIdentifier: bundleIdentifier,
            localizedName: localizedName,
            bundlePath: bundlePath,
            applicationCategory: applicationCategory
        )
    }

    public static func isAutomaticallyBypassed(
        bundleIdentifier: String?,
        localizedName: String?,
        bundlePath: String?,
        applicationCategory: String?
    ) -> Bool {
        let normalizedBundleID = normalize(bundleIdentifier)
        if remoteBundleIDs.contains(normalizedBundleID)
            || remoteBundleIDFragments.contains(where: normalizedBundleID.contains) {
            return true
        }

        let normalizedName = normalize(localizedName)
        if remoteNameFragments.contains(where: normalizedName.contains) {
            return true
        }

        if normalize(applicationCategory) == "public.app-category.games" {
            return true
        }

        let normalizedPath = normalize(bundlePath)
        return gamePathFragments.contains(where: normalizedPath.contains)
    }

    private static func normalize(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    }
}
