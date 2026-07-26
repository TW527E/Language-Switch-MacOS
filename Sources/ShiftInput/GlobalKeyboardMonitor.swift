import ApplicationServices
import ShiftInputCore

final class GlobalKeyboardMonitor {
    var onShiftTap: (() -> Void)?
    var shouldHandleWidthToggle: (() -> Bool)?
    var onWidthToggle: (() -> Void)?
    var onTapDisabled: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var state = ShiftGestureStateMachine()

    private static let leftShiftKeyCode: UInt16 = 56
    private static let rightShiftKeyCode: UInt16 = 60
    private static let syntheticMarker: Int64 = 0x5348494654494E50 // "SHIFTINP"

    var isRunning: Bool {
        guard let eventTap else { return false }
        return CGEvent.tapIsEnabled(tap: eventTap)
    }

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return isRunning }

        let types: [CGEventType] = [
            .flagsChanged, .keyDown, .keyUp,
            .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel
        ]
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
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
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
        case .flagsChanged:
            let isShiftKey = keyCode == Self.leftShiftKeyCode || keyCode == Self.rightShiftKeyCode
            let otherFlags = event.flags.intersection([.maskCommand, .maskControl, .maskAlternate])
            let action = isShiftKey
                ? state.shiftFlagsChanged(keyCode: keyCode, hasOtherModifiers: !otherFlags.isEmpty)
                : state.otherModifierChanged()
            if action == .toggleInputSource {
                DispatchQueue.main.async { [weak self] in self?.onShiftTap?() }
            }

        case .keyDown:
            let relevantFlags = event.flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift])
            let plainShiftSpace = keyCode == 49 && relevantFlags == [.maskShift]
            let action = state.keyDown(keyCode: keyCode, isPlainShiftSpace: plainShiftSpace)
            if action == .requestWidthToggle,
               shouldHandleWidthToggle?() == true {
                _ = state.widthToggleWasHandled()
                DispatchQueue.main.async { [weak self] in self?.onWidthToggle?() }
                return nil
            }

        case .keyUp:
            if state.keyUp(keyCode: keyCode) == .consume {
                return nil
            }

        case .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel:
            _ = state.pointerActivity()

        default:
            break
        }

        return Unmanaged.passUnretained(event)
    }

    static func postNativeChineseWidthShortcut() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        for isDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: 4, keyDown: isDown) else { continue }
            event.flags = [.maskAlternate, .maskShift]
            event.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
            event.post(tap: .cgSessionEventTap)
        }
    }
}
