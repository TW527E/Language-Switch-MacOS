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
        state.widthToggleWasHandled()
        expect(state.keyUp(keyCode: space) == .consume, "handled Space up is consumed")
        expect(state.shiftFlagsChanged(keyCode: leftShift, isDown: false) == .pass, "Shift-Space does not also switch source")

        state.reset()
        _ = state.shiftFlagsChanged(keyCode: leftShift, isDown: true)
        _ = state.keyDown(keyCode: space, isPlainShiftSpace: true)
        expect(state.keyUp(keyCode: space) == .pass, "unsupported Shift-Space passes")
        expect(state.shiftFlagsChanged(keyCode: leftShift, isDown: false) == .pass, "unsupported Shift-Space still marks Shift used")

        state.reset()
        _ = state.shiftFlagsChanged(keyCode: leftShift, isDown: true, pointerEventCount: 7)
        expect(state.shiftFlagsChanged(keyCode: leftShift, isDown: false, pointerEventCount: 8) == .pass, "Shift-click does not switch")
        _ = state.shiftFlagsChanged(keyCode: leftShift, isDown: true, pointerEventCount: 8)
        expect(state.shiftFlagsChanged(keyCode: leftShift, isDown: false, pointerEventCount: 8) == .toggleInputSource, "earlier clicks do not block a later tap")

        state.reset()
        _ = state.shiftFlagsChanged(keyCode: leftShift, isDown: true, pointerEventCount: 1)
        _ = state.shiftFlagsChanged(keyCode: rightShift, isDown: true, pointerEventCount: 2)
        _ = state.shiftFlagsChanged(keyCode: rightShift, isDown: false, pointerEventCount: 2)
        expect(state.shiftFlagsChanged(keyCode: leftShift, isDown: false, pointerEventCount: 2) == .pass, "a click before the second Shift press still counts")

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
        state.otherModifierChanged()
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

        let defaultsName = "ShiftIMEChecks.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: defaultsName) else {
            fputs("FAILED: could not create isolated defaults\n", stderr)
            exit(1)
        }
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let settings = SettingsStore(defaults: defaults)
        expect(settings.shiftToggleEnabled && settings.automaticallyBypassRemoteAppsAndGames, "shortcuts and automatic bypass default to on")
        expect(!settings.showDockIcon && settings.excludedApplicationBundleIDs.isEmpty, "unregistered settings default to off and empty")
        settings.setBypassed(true, bundleIdentifier: "com.example.remote")
        expect(settings.shiftExcludedBundleIDs.contains("com.example.remote"), "new app bypasses Shift by default")
        expect(settings.pinyinWidthExcludedBundleIDs.contains("com.example.remote"), "new app bypasses Shift-Space by default")
        settings.shiftExcludedBundleIDs.remove("com.example.remote")
        expect(!settings.shiftExcludedBundleIDs.contains("com.example.remote"), "Shift bypass can be disabled independently")
        expect(settings.pinyinWidthExcludedBundleIDs.contains("com.example.remote"), "Shift-Space bypass remains enabled independently")
        expect(settings.excludedApplicationBundleIDs.contains("com.example.remote"), "partially enabled app remains in the list")
        settings.setBypassed(false, bundleIdentifier: "com.example.remote")
        expect(!settings.excludedApplicationBundleIDs.contains("com.example.remote"), "removing an app clears both bypass switches")

        print("State machine checks passed: \(checkCount)")
    }
}
