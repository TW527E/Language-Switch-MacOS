import Foundation

extension Notification.Name {
    static let shiftInputSettingsDidChange = Notification.Name("ShiftInput.settingsDidChange")
}

final class SettingsStore {
    static let shared = SettingsStore()

    private enum Key {
        static let legacyFeatureEnabled = "featureEnabled"
        static let shiftToggleEnabled = "shiftToggleEnabled"
        static let pinyinWidthToggleEnabled = "pinyinWidthToggleEnabled"
        static let automaticallyBypassRemoteAppsAndGames = "automaticallyBypassRemoteAppsAndGames"
        static let shiftExcludedBundleIDs = "shiftExcludedBundleIDs"
        static let pinyinWidthExcludedBundleIDs = "pinyinWidthExcludedBundleIDs"
        static let shortcutBypassRulesVersion = "shortcutBypassRulesVersion"
        static let showStatusItem = "showStatusItem"
        static let showDockIcon = "showDockIcon"
        static let lastNonEnglishSourceID = "lastNonEnglishSourceID"
        static let hasLaunchedBefore = "hasLaunchedBefore"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let legacyValue = defaults.object(forKey: Key.legacyFeatureEnabled) as? Bool
        let existingWidthExclusions = defaults.stringArray(forKey: Key.pinyinWidthExcludedBundleIDs) ?? []
        let shortcutBypassRulesVersion = defaults.integer(forKey: Key.shortcutBypassRulesVersion)
        defaults.register(defaults: [
            Key.shiftToggleEnabled: legacyValue ?? true,
            Key.pinyinWidthToggleEnabled: legacyValue ?? true,
            Key.automaticallyBypassRemoteAppsAndGames: true,
            Key.shiftExcludedBundleIDs: [String](),
            Key.pinyinWidthExcludedBundleIDs: [String](),
            Key.showStatusItem: true,
            Key.showDockIcon: false
        ])
        // The first local test build only stored Shift + Space exclusions.
        // Promote those entries to the new default of bypassing both shortcuts.
        if shortcutBypassRulesVersion < 1 {
            if !existingWidthExclusions.isEmpty {
                defaults.set(existingWidthExclusions, forKey: Key.shiftExcludedBundleIDs)
            }
            defaults.set(1, forKey: Key.shortcutBypassRulesVersion)
        }
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

    var pinyinWidthExcludedBundleIDs: Set<String> {
        Set(defaults.stringArray(forKey: Key.pinyinWidthExcludedBundleIDs) ?? [])
    }

    var shiftExcludedBundleIDs: Set<String> {
        Set(defaults.stringArray(forKey: Key.shiftExcludedBundleIDs) ?? [])
    }

    var excludedApplicationBundleIDs: Set<String> {
        shiftExcludedBundleIDs.union(pinyinWidthExcludedBundleIDs)
    }

    func addExcludedApplication(bundleIdentifier: String) {
        var shiftBundleIDs = shiftExcludedBundleIDs
        var widthBundleIDs = pinyinWidthExcludedBundleIDs
        shiftBundleIDs.insert(bundleIdentifier)
        widthBundleIDs.insert(bundleIdentifier)
        defaults.set(shiftBundleIDs.sorted(), forKey: Key.shiftExcludedBundleIDs)
        defaults.set(widthBundleIDs.sorted(), forKey: Key.pinyinWidthExcludedBundleIDs)
        NotificationCenter.default.post(name: .shiftInputSettingsDidChange, object: self)
    }

    func removeExcludedApplication(bundleIdentifier: String) {
        var shiftBundleIDs = shiftExcludedBundleIDs
        var widthBundleIDs = pinyinWidthExcludedBundleIDs
        let shiftRemoved = shiftBundleIDs.remove(bundleIdentifier) != nil
        let widthRemoved = widthBundleIDs.remove(bundleIdentifier) != nil
        guard shiftRemoved || widthRemoved else { return }
        defaults.set(shiftBundleIDs.sorted(), forKey: Key.shiftExcludedBundleIDs)
        defaults.set(widthBundleIDs.sorted(), forKey: Key.pinyinWidthExcludedBundleIDs)
        NotificationCenter.default.post(name: .shiftInputSettingsDidChange, object: self)
    }

    func setShiftExcluded(_ excluded: Bool, bundleIdentifier: String) {
        setBundleIdentifier(bundleIdentifier, excluded: excluded, forKey: Key.shiftExcludedBundleIDs)
    }

    func setPinyinWidthExcluded(_ excluded: Bool, bundleIdentifier: String) {
        setBundleIdentifier(bundleIdentifier, excluded: excluded, forKey: Key.pinyinWidthExcludedBundleIDs)
    }

    var showStatusItem: Bool {
        get { defaults.bool(forKey: Key.showStatusItem) }
        set { set(newValue, forKey: Key.showStatusItem) }
    }

    var showDockIcon: Bool {
        get { defaults.bool(forKey: Key.showDockIcon) }
        set { set(newValue, forKey: Key.showDockIcon) }
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

    private func set(_ value: Bool, forKey key: String) {
        guard defaults.bool(forKey: key) != value else { return }
        defaults.set(value, forKey: key)
        NotificationCenter.default.post(name: .shiftInputSettingsDidChange, object: self)
    }

    private func setBundleIdentifier(_ bundleIdentifier: String, excluded: Bool, forKey key: String) {
        var bundleIDs = Set(defaults.stringArray(forKey: key) ?? [])
        let changed: Bool
        if excluded {
            changed = bundleIDs.insert(bundleIdentifier).inserted
        } else {
            changed = bundleIDs.remove(bundleIdentifier) != nil
        }
        guard changed else { return }
        defaults.set(bundleIDs.sorted(), forKey: key)
        NotificationCenter.default.post(name: .shiftInputSettingsDidChange, object: self)
    }
}
