import AppKit
import ShiftInputCore

struct ForegroundApplicationInfo {
    let bundleIdentifier: String
    let localizedName: String
    /// Classified once per activation so the event tap only reads a Bool.
    let isRemoteOrGame: Bool

    init?(runningApplication: NSRunningApplication) {
        guard let bundleIdentifier = runningApplication.bundleIdentifier,
              bundleIdentifier != Bundle.main.bundleIdentifier else {
            return nil
        }

        let bundleURL = runningApplication.bundleURL
        let appBundle = bundleURL.flatMap(Bundle.init(url:))
        self.bundleIdentifier = bundleIdentifier
        self.localizedName = runningApplication.localizedName
            ?? appBundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? appBundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? bundleIdentifier
        self.isRemoteOrGame = ApplicationBypassPolicy.isAutomaticallyBypassed(
            bundleIdentifier: bundleIdentifier,
            localizedName: localizedName,
            bundlePath: bundleURL?.path,
            applicationCategory: appBundle?.object(forInfoDictionaryKey: "LSApplicationCategoryType") as? String
        )
    }
}
