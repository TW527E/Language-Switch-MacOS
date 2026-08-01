import AppKit

struct ForegroundApplicationInfo: Equatable {
    let bundleIdentifier: String
    let localizedName: String
    let bundlePath: String?
    let applicationCategory: String?

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
        self.bundlePath = bundleURL?.path
        self.applicationCategory = appBundle?.object(forInfoDictionaryKey: "LSApplicationCategoryType") as? String
    }
}
