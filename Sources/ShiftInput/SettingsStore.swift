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
        static let showStatusItem = "showStatusItem"
        static let showDockIcon = "showDockIcon"
        static let lastNonEnglishSourceID = "lastNonEnglishSourceID"
        static let hasLaunchedBefore = "hasLaunchedBefore"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let legacyValue = defaults.object(forKey: Key.legacyFeatureEnabled) as? Bool
        defaults.register(defaults: [
            Key.shiftToggleEnabled: legacyValue ?? true,
            Key.pinyinWidthToggleEnabled: legacyValue ?? true,
            Key.showStatusItem: true,
            Key.showDockIcon: false
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
}
