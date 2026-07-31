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

        print("State machine checks passed: \(checkCount)")
    }
}
