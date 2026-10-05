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
        expect(state.shiftFlagsChanged(keyCode: leftShift, isDown: true) == .pass, "Shift down passes")
        expect(state.shiftFlagsChanged(keyCode: leftShift, isDown: false) == .toggleInputSource, "unused Shift toggles")

        state.reset()
        _ = state.shiftFlagsChanged(keyCode: leftShift, isDown: true)
        expect(state.keyDown(keyCode: 0, isPlainShiftSpace: false) == .pass, "typing passes")
        expect(state.shiftFlagsChanged(keyCode: leftShift, isDown: false) == .pass, "used Shift does not toggle")

        state.reset()
        _ = state.shiftFlagsChanged(keyCode: leftShift, isDown: true)
        expect(state.keyDown(keyCode: space, isPlainShiftSpace: true) == .requestWidthToggle, "Shift-Space requests width toggle")
        expect(state.widthToggleWasHandled() == .consume, "handled Space down is consumed")
        expect(state.keyUp(keyCode: space) == .consume, "handled Space up is consumed")
        expect(state.shiftFlagsChanged(keyCode: leftShift, isDown: false) == .pass, "Shift-Space does not also switch source")

        state.reset()
        _ = state.shiftFlagsChanged(keyCode: leftShift, isDown: true)
        _ = state.keyDown(keyCode: space, isPlainShiftSpace: true)
        expect(state.keyUp(keyCode: space) == .pass, "unsupported Shift-Space passes")
        expect(state.shiftFlagsChanged(keyCode: leftShift, isDown: false) == .pass, "unsupported Shift-Space still marks Shift used")

        state.reset()
        _ = state.shiftFlagsChanged(keyCode: leftShift, isDown: true)
        _ = state.pointerActivity()
        expect(state.shiftFlagsChanged(keyCode: leftShift, isDown: false) == .pass, "Shift-click does not switch")

        state.reset()
        _ = state.shiftFlagsChanged(keyCode: leftShift, isDown: true)
        _ = state.shiftFlagsChanged(keyCode: rightShift, isDown: true)
        expect(state.shiftFlagsChanged(keyCode: leftShift, isDown: false) == .pass, "first Shift release passes")
        expect(state.shiftFlagsChanged(keyCode: rightShift, isDown: false) == .toggleInputSource, "last unused Shift release switches")

        state.reset()
        _ = state.shiftFlagsChanged(keyCode: leftShift, isDown: true)
        state.reset()
        expect(state.shiftFlagsChanged(keyCode: leftShift, isDown: false) == .pass, "release without a seen press does not switch")
        expect(state.shiftFlagsChanged(keyCode: leftShift, isDown: true) == .pass, "Shift press after lost state does not switch")
        _ = state.keyDown(keyCode: 4, isPlainShiftSpace: false)
        expect(state.shiftFlagsChanged(keyCode: leftShift, isDown: false) == .pass, "capital letter after lost state does not switch")
        _ = state.shiftFlagsChanged(keyCode: leftShift, isDown: true)
        expect(state.shiftFlagsChanged(keyCode: leftShift, isDown: false) == .toggleInputSource, "Shift tap still switches after a missed event")

        state.reset()
        _ = state.shiftFlagsChanged(keyCode: leftShift, isDown: true)
        _ = state.keyDown(keyCode: 4, isPlainShiftSpace: false)
        _ = state.shiftFlagsChanged(keyCode: leftShift, isDown: true)
        expect(state.shiftFlagsChanged(keyCode: leftShift, isDown: false) == .toggleInputSource, "a repeated press recovers from its own missed release")

        state.reset()
        _ = state.shiftFlagsChanged(keyCode: leftShift, isDown: true)
        _ = state.otherModifierChanged()
        expect(state.shiftFlagsChanged(keyCode: leftShift, isDown: false) == .pass, "modifier chord does not switch")

        state.reset()
        _ = state.shiftFlagsChanged(keyCode: leftShift, isDown: true, hasOtherModifiers: true)
        expect(state.shiftFlagsChanged(keyCode: leftShift, isDown: false, hasOtherModifiers: true) == .pass, "pre-held modifier chord does not switch")

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

        expect(InputSourceSelectionPolicy.decision(
            expectedID: "com.apple.inputmethod.TCIM.Pinyin",
            currentID: "com.apple.inputmethod.TCIM.Pinyin",
            isSelected: true
        ) == .confirmed, "selected destination confirms without consulting the keyboard layout")
        expect(InputSourceSelectionPolicy.decision(
            expectedID: "com.apple.inputmethod.TCIM.Pinyin",
            currentID: "com.apple.inputmethod.TCIM.Pinyin",
            isSelected: false
        ) == .waitForSelection, "destination still activating is polled without being selected again")
        expect(InputSourceSelectionPolicy.decision(
            expectedID: "com.apple.inputmethod.TCIM.Pinyin",
            currentID: "com.apple.inputmethod.TCIM.Pinyin",
            isSelected: nil
        ) == .waitForSelection, "missing selected state is treated as transient")
        expect(InputSourceSelectionPolicy.decision(
            expectedID: "com.apple.inputmethod.TCIM.Pinyin",
            currentID: "com.apple.keylayout.ABC",
            isSelected: true
        ) == .retrySelection, "a different current source permits a bounded reselection")

        var deferredEvents = DeferredInputEventBuffer<Int>()
        expect(!deferredEvents.appendIfActive(1), "keyboard events pass while no source switch is active")
        expect(deferredEvents.begin(), "a source switch starts event deferral")
        expect(!deferredEvents.begin(), "an active event deferral cannot be started twice")
        expect(deferredEvents.appendIfActive(10), "the first event is deferred during a source switch")
        expect(deferredEvents.appendIfActive(11), "later events are deferred during a source switch")
        expect(deferredEvents.finish() == [10, 11], "deferred events are released in their original order")
        expect(!deferredEvents.isActive, "finishing a source switch disables event deferral")
        expect(deferredEvents.finish().isEmpty, "finishing twice cannot replay the same events again")
        expect(deferredEvents.begin(), "event deferral can start cleanly for a later source switch")
        expect(deferredEvents.appendIfActive(20), "the later source switch accepts new events")
        expect(deferredEvents.finish() == [20], "a later source switch contains no stale events")

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
