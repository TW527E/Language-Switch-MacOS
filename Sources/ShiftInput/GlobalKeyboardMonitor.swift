import ApplicationServices
import Carbon
import ShiftInputCore

final class GlobalKeyboardMonitor {
    var onShiftTap: (() -> Void)?
    var shouldHandleShiftTap: (() -> Bool)?
    var shouldHandleWidthToggle: (() -> Bool)?
    var onTapDisabled: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var state = ShiftGestureStateMachine()
    /// Keystrokes held while a source switch is confirmed; nil when idle.
    private var deferredEvents: [CGEvent]?
    private var deferredKeyCodes: Set<UInt16> = []
    private var deferralGeneration = 0

    private static let leftShiftKeyCode: UInt16 = 56
    private static let rightShiftKeyCode: UInt16 = 60
    private static let syntheticMarker: Int64 = 0x5348494654494E50 // "SHIFTINP"

    var isRunning: Bool {
        eventTap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false
    }

    /// Keyboard events only: an active tap on pointer events would route
    /// every click and scroll in the system through this process.
    func start() {
        guard !isRunning else { return }
        stop()

        let types: [CGEventType] = [.flagsChanged, .keyDown, .keyUp]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<GlobalKeyboardMonitor>.fromOpaque(userInfo).takeUnretainedValue()
            return monitor.handle(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
        state.reset()
        finishDeferringInput()
    }

    /// Releases keystrokes held while an input-source switch was confirmed,
    /// in their original order, so they reach the destination input method.
    func finishDeferringInput() {
        let events = deferredEvents ?? []
        deferredEvents = nil
        deferredKeyCodes.removeAll(keepingCapacity: true)
        for event in events {
            event.setIntegerValueField(.eventSourceUserData, value: Self.syntheticMarker)
            event.post(tap: .cgSessionEventTap)
        }
    }

    private func beginDeferringInput() {
        guard deferredEvents == nil else { return }
        deferredEvents = []
        deferralGeneration += 1
        let generation = deferralGeneration
        // Input must never stay held if a switch fails to report completion.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self, self.deferralGeneration == generation else { return }
            self.finishDeferringInput()
        }
    }

    /// Holds plain text keys and Shift; shortcuts pass so they are never
    /// delayed. Shift is held with its letter because a Shift that arrives
    /// alone looks like a bare tap, which Pinyin uses for its own
    /// Chinese/English toggle.
    private func deferIfSwitching(event: CGEvent, keyCode: UInt16, isRelease: Bool) -> Bool {
        guard deferredEvents != nil else { return false }
        if isRelease {
            guard deferredKeyCodes.contains(keyCode) else { return false }
        } else if !event.flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty {
            return false
        }
        guard let copy = event.copy() else { return false }
        deferredEvents?.append(copy)
        deferredKeyCodes.insert(keyCode)
        return true
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            state.reset()
            if type == .tapDisabledByTimeout, let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            } else {
                onTapDisabled?()
            }
            return Unmanaged.passUnretained(event)
        }

        if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticMarker {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        switch type {
        case .flagsChanged where keyCode != Self.leftShiftKeyCode && keyCode != Self.rightShiftKeyCode:
            state.otherModifierChanged()

        case .flagsChanged:
            let otherFlags = event.flags.intersection([.maskCommand, .maskControl, .maskAlternate])
            // Device-dependent flag bits tell which Shift key is down; events
            // from tools that omit them fall back to the combined Shift flag.
            let deviceShiftBits = event.flags.rawValue & 0x6
            let shiftBit: UInt64 = keyCode == Self.leftShiftKeyCode ? 0x2 : 0x4
            let isShiftDown = deviceShiftBits == 0
                ? event.flags.contains(.maskShift)
                : deviceShiftBits & shiftBit != 0
            let action = state.shiftFlagsChanged(
                keyCode: keyCode,
                isDown: isShiftDown,
                hasOtherModifiers: !otherFlags.isEmpty,
                pointerEventCount: Self.pointerEventCount
            )
            // Secure input (password fields) hides letter keys from event
            // taps, so a capital letter would be indistinguishable from a tap.
            if action == .toggleInputSource, !IsSecureEventInputEnabled(), shouldHandleShiftTap?() ?? true {
                beginDeferringInput()
                DispatchQueue.main.async { [weak self] in self?.onShiftTap?() }
            }
            if deferIfSwitching(event: event, keyCode: keyCode, isRelease: !isShiftDown) {
                return nil
            }

        case .keyDown:
            let relevantFlags = event.flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift])
            let plainShiftSpace = keyCode == 49 && relevantFlags == [.maskShift]
            let action = state.keyDown(keyCode: keyCode, isPlainShiftSpace: plainShiftSpace)
            if action == .requestWidthToggle, shouldHandleWidthToggle?() == true {
                state.widthToggleWasHandled()
                DispatchQueue.main.async { Self.postNativeChineseWidthShortcut() }
                return nil
            }
            if deferIfSwitching(event: event, keyCode: keyCode, isRelease: false) {
                return nil
            }

        case .keyUp:
            if state.keyUp(keyCode: keyCode) == .consume {
                return nil
            }
            if deferIfSwitching(event: event, keyCode: keyCode, isRelease: true) {
                return nil
            }

        default:
            break
        }

        return Unmanaged.passUnretained(event)
    }

    /// Clicks and scrolls in this login session, including ones posted by
    /// mouse utilities. Wrapping addition is fine: the state machine only
    /// compares for a change.
    private static var pointerEventCount: UInt32 {
        [CGEventType.leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel].reduce(0) {
            $0 &+ CGEventSource.counterForEventType(.combinedSessionState, eventType: $1)
        }
    }

    /// Option-Shift-H is Apple Pinyin's own full/half-width punctuation toggle.
    private static func postNativeChineseWidthShortcut() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        for isDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: 4, keyDown: isDown) else { continue }
            event.flags = [.maskAlternate, .maskShift]
            event.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
            event.post(tap: .cgSessionEventTap)
        }
    }
}
