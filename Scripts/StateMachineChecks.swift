import Foundation

private let leftShift: UInt16 = 56
private let rightShift: UInt16 = 60
private let space: UInt16 = 49
private var checkCount = 0

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    checkCount += 1
    guard condition() else {
        fputs("FAILED: \(message)\n", stderr)
        exit(1)
    }
}

@main
enum StateMachineChecks {
    static func main() {
        var state = ShiftGestureStateMachine()
        expect(state.shiftFlagsChanged(keyCode: leftShift) == .pass, "Shift down passes")
        expect(state.shiftFlagsChanged(keyCode: leftShift) == .toggleInputSource, "unused Shift toggles")

        state.reset()
        _ = state.shiftFlagsChanged(keyCode: leftShift)
        expect(state.keyDown(keyCode: 0, isPlainShiftSpace: false) == .pass, "typing passes")
        expect(state.shiftFlagsChanged(keyCode: leftShift) == .pass, "used Shift does not toggle")

        state.reset()
        _ = state.shiftFlagsChanged(keyCode: leftShift)
        expect(state.keyDown(keyCode: space, isPlainShiftSpace: true) == .requestWidthToggle, "Shift-Space requests width toggle")
        expect(state.widthToggleWasHandled() == .consume, "handled Space down is consumed")
        expect(state.keyUp(keyCode: space) == .consume, "handled Space up is consumed")
        expect(state.shiftFlagsChanged(keyCode: leftShift) == .pass, "Shift-Space does not also switch source")

        state.reset()
        _ = state.shiftFlagsChanged(keyCode: leftShift)
        _ = state.keyDown(keyCode: space, isPlainShiftSpace: true)
        expect(state.keyUp(keyCode: space) == .pass, "unsupported Shift-Space passes")
        expect(state.shiftFlagsChanged(keyCode: leftShift) == .pass, "unsupported Shift-Space still marks Shift used")

        state.reset()
        _ = state.shiftFlagsChanged(keyCode: leftShift)
        _ = state.pointerActivity()
        expect(state.shiftFlagsChanged(keyCode: leftShift) == .pass, "Shift-click does not switch")

        state.reset()
        _ = state.shiftFlagsChanged(keyCode: leftShift)
        _ = state.shiftFlagsChanged(keyCode: rightShift)
        expect(state.shiftFlagsChanged(keyCode: leftShift) == .pass, "first Shift release passes")
        expect(state.shiftFlagsChanged(keyCode: rightShift) == .toggleInputSource, "last unused Shift release switches")

        state.reset()
        _ = state.shiftFlagsChanged(keyCode: leftShift)
        _ = state.otherModifierChanged()
        expect(state.shiftFlagsChanged(keyCode: leftShift) == .pass, "modifier chord does not switch")

        state.reset()
        _ = state.shiftFlagsChanged(keyCode: leftShift, hasOtherModifiers: true)
        expect(state.shiftFlagsChanged(keyCode: leftShift, hasOtherModifiers: true) == .pass, "pre-held modifier chord does not switch")

        expect(PinyinInputSourceClassifier.isApplePinyin(
            id: "com.apple.inputmethod.TCIM.Pinyin",
            localizedName: "Pinyin – Traditional"
        ), "Traditional Pinyin is supported")
        expect(PinyinInputSourceClassifier.isApplePinyin(
            id: "com.apple.inputmethod.SCIM.ITABC",
            localizedName: "Pinyin – Simplified"
        ), "Simplified Pinyin is supported")
        expect(PinyinInputSourceClassifier.isApplePinyin(
            id: "com.apple.keylayout.TraditionalPinyinKeyboard",
            localizedName: "Pinyin – Traditional"
        ), "Traditional Pinyin keyboard layout activation is recognized")
        expect(!PinyinInputSourceClassifier.isApplePinyin(
            id: "com.apple.inputmethod.TCIM.Zhuyin",
            localizedName: "Zhuyin – Traditional"
        ), "Zhuyin is deliberately excluded")
        expect(!PinyinInputSourceClassifier.isApplePinyin(
            id: "com.apple.inputmethod.SCIM.Shuangpin",
            localizedName: "Shuangpin – Simplified"
        ), "Shuangpin is not mistaken for standard Pinyin")

        expect(ApplicationBypassPolicy.isAutomaticallyBypassed(
            bundleIdentifier: "com.parsecgaming.parsec",
            localizedName: "Parsec",
            bundlePath: "/Applications/Parsec.app",
            applicationCategory: nil
        ), "known remote desktop apps are automatically bypassed")
        expect(ApplicationBypassPolicy.isAutomaticallyBypassed(
            bundleIdentifier: "com.example.game",
            localizedName: "Example Game",
            bundlePath: "/Users/test/Library/Application Support/Steam/steamapps/common/Example/Example.app",
            applicationCategory: nil
        ), "Steam games are automatically bypassed by path")
        expect(ApplicationBypassPolicy.isAutomaticallyBypassed(
            bundleIdentifier: "com.example.arcade",
            localizedName: "Example Arcade",
            bundlePath: "/Applications/Example Arcade.app",
            applicationCategory: "public.app-category.games"
        ), "apps categorized as games are automatically bypassed")
        expect(!ApplicationBypassPolicy.isAutomaticallyBypassed(
            bundleIdentifier: "com.apple.Safari",
            localizedName: "Safari",
            bundlePath: "/Applications/Safari.app",
            applicationCategory: "public.app-category.productivity"
        ), "ordinary apps are not automatically bypassed")
        expect(ApplicationBypassPolicy.shouldBypass(
            bundleIdentifier: "com.example.custom",
            localizedName: "Custom App",
            bundlePath: "/Applications/Custom App.app",
            applicationCategory: nil,
            excludedBundleIdentifiers: ["com.example.custom"],
            automaticBypassEnabled: false
        ), "manual exclusions work when automatic bypass is disabled")
        expect(!ApplicationBypassPolicy.shouldBypass(
            bundleIdentifier: "com.parsecgaming.parsec",
            localizedName: "Parsec",
            bundlePath: "/Applications/Parsec.app",
            applicationCategory: nil,
            excludedBundleIdentifiers: [],
            automaticBypassEnabled: false
        ), "automatic bypass can be disabled")

        let defaultsName = "ShiftInputChecks.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: defaultsName) else {
            fputs("FAILED: could not create isolated defaults\n", stderr)
            exit(1)
        }
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let settings = SettingsStore(defaults: defaults)
        settings.addExcludedApplication(bundleIdentifier: "com.example.remote")
        expect(settings.shiftExcludedBundleIDs.contains("com.example.remote"), "new app bypasses Shift by default")
        expect(settings.pinyinWidthExcludedBundleIDs.contains("com.example.remote"), "new app bypasses Shift-Space by default")
        settings.setShiftExcluded(false, bundleIdentifier: "com.example.remote")
        expect(!settings.shiftExcludedBundleIDs.contains("com.example.remote"), "Shift bypass can be disabled independently")
        expect(settings.pinyinWidthExcludedBundleIDs.contains("com.example.remote"), "Shift-Space bypass remains enabled independently")
        expect(settings.excludedApplicationBundleIDs.contains("com.example.remote"), "partially enabled app remains in the list")
        settings.removeExcludedApplication(bundleIdentifier: "com.example.remote")
        expect(!settings.excludedApplicationBundleIDs.contains("com.example.remote"), "removing an app clears both bypass switches")

        let migrationDefaultsName = "ShiftInputMigrationChecks.\(UUID().uuidString)"
        guard let migrationDefaults = UserDefaults(suiteName: migrationDefaultsName) else {
            fputs("FAILED: could not create migration defaults\n", stderr)
            exit(1)
        }
        defer { migrationDefaults.removePersistentDomain(forName: migrationDefaultsName) }
        migrationDefaults.set(["com.example.old"], forKey: "pinyinWidthExcludedBundleIDs")
        let migratedSettings = SettingsStore(defaults: migrationDefaults)
        expect(migratedSettings.shiftExcludedBundleIDs.contains("com.example.old"), "old test-build exclusions migrate to bypass both shortcuts")

        print("State machine checks passed: \(checkCount)")
    }
}
