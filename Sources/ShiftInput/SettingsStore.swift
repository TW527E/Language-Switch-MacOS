import Foundation

extension Notification.Name {
    static let shiftInputSettingsDidChange = Notification.Name("ShiftInput.settingsDidChange")
}

final class SettingsStore {
    private enum Key {
        static let shiftToggleEnabled = "shiftToggleEnabled"
        static let pinyinWidthToggleEnabled = "pinyinWidthToggleEnabled"
        static let automaticallyBypassRemoteAppsAndGames = "automaticallyBypassRemoteAppsAndGames"
        static let shiftExcludedBundleIDs = "shiftExcludedBundleIDs"
        static let pinyinWidthExcludedBundleIDs = "pinyinWidthExcludedBundleIDs"
        static let showStatusItem = "showStatusItem"
        static let showDockIcon = "showDockIcon"
        static let showCenterHUDAsFallback = "showCenterHUDAsFallback"
        static let lastNonEnglishSourceID = "lastNonEnglishSourceID"
        static let hasLaunchedBefore = "hasLaunchedBefore"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Unregistered keys read as false or empty.
        defaults.register(defaults: [
            Key.shiftToggleEnabled: true,
            Key.pinyinWidthToggleEnabled: true,
            Key.automaticallyBypassRemoteAppsAndGames: true,
            Key.showStatusItem: true
        ])
    }

    var shiftToggleEnabled: Bool {
        get { defaults.bool(forKey: Key.shiftToggleEnabled) }
        set { set(newValue, forKey: Key.shiftToggleEnabled) }
    }

    var pinyinWidthToggleEnabled: Bool {
        get { defaults.bool(forKey: Key.pinyinWidthToggleEnabled) }
        set { set(newValue, forKey: Key.pinyinWidthToggleEnabled) }
    }

    var hasEnabledKeyboardFeature: Bool {
        shiftToggleEnabled || pinyinWidthToggleEnabled
    }

    var automaticallyBypassRemoteAppsAndGames: Bool {
        get { defaults.bool(forKey: Key.automaticallyBypassRemoteAppsAndGames) }
        set { set(newValue, forKey: Key.automaticallyBypassRemoteAppsAndGames) }
    }

    var shiftExcludedBundleIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: Key.shiftExcludedBundleIDs) ?? []) }
        set { set(newValue.sorted(), forKey: Key.shiftExcludedBundleIDs) }
    }

    var pinyinWidthExcludedBundleIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: Key.pinyinWidthExcludedBundleIDs) ?? []) }
        set { set(newValue.sorted(), forKey: Key.pinyinWidthExcludedBundleIDs) }
    }

    var excludedApplicationBundleIDs: Set<String> {
        shiftExcludedBundleIDs.union(pinyinWidthExcludedBundleIDs)
    }

    /// Adds or removes an app for both shortcuts at once.
    func setBypassed(_ bypassed: Bool, bundleIdentifier: String) {
        if bypassed {
            shiftExcludedBundleIDs.insert(bundleIdentifier)
            pinyinWidthExcludedBundleIDs.insert(bundleIdentifier)
        } else {
            shiftExcludedBundleIDs.remove(bundleIdentifier)
            pinyinWidthExcludedBundleIDs.remove(bundleIdentifier)
        }
    }

    var showStatusItem: Bool {
        get { defaults.bool(forKey: Key.showStatusItem) }
        set { set(newValue, forKey: Key.showStatusItem) }
    }

    var showDockIcon: Bool {
        get { defaults.bool(forKey: Key.showDockIcon) }
        set { set(newValue, forKey: Key.showDockIcon) }
    }

    var showCenterHUDAsFallback: Bool {
        get { defaults.bool(forKey: Key.showCenterHUDAsFallback) }
        set { set(newValue, forKey: Key.showCenterHUDAsFallback) }
    }

    var lastNonEnglishSourceID: String? {
        get { defaults.string(forKey: Key.lastNonEnglishSourceID) }
        set { defaults.set(newValue, forKey: Key.lastNonEnglishSourceID) }
    }

    /// Returns true once, on the first successful application launch.
    func consumeFirstLaunch() -> Bool {
        guard !defaults.bool(forKey: Key.hasLaunchedBefore) else { return false }
        defaults.set(true, forKey: Key.hasLaunchedBefore)
        return true
    }

    private func set<Value: Equatable>(_ value: Value, forKey key: String) {
        guard defaults.object(forKey: key) as? Value != value else { return }
        defaults.set(value, forKey: key)
        NotificationCenter.default.post(name: .shiftInputSettingsDidChange, object: self)
    }
}
