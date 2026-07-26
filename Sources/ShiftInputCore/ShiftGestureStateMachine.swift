import Foundation

/// Pure state machine for recognizing an otherwise-unused Shift tap and
/// Shift-Space. Keeping this independent of AppKit makes edge cases testable.
public struct ShiftGestureStateMachine: Sendable {
    public enum Action: Equatable, Sendable {
        case pass
        case consume
        case toggleInputSource
        case requestWidthToggle
    }

    private var pressedShiftKeys: Set<UInt16> = []
    private var shiftWasUsed = false
    private var consumeNextSpaceKeyUp = false

    public init() {}

    public mutating func shiftFlagsChanged(keyCode: UInt16, hasOtherModifiers: Bool = false) -> Action {
        if pressedShiftKeys.contains(keyCode) {
            if hasOtherModifiers {
                shiftWasUsed = true
            }
            pressedShiftKeys.remove(keyCode)
            guard pressedShiftKeys.isEmpty else { return .pass }

            let shouldToggle = !shiftWasUsed
            shiftWasUsed = false
            return shouldToggle ? .toggleInputSource : .pass
        }

        if pressedShiftKeys.isEmpty {
            shiftWasUsed = false
        }
        pressedShiftKeys.insert(keyCode)
        if hasOtherModifiers {
            shiftWasUsed = true
        }
        return .pass
    }

    public mutating func otherModifierChanged() -> Action {
        if !pressedShiftKeys.isEmpty {
            shiftWasUsed = true
        }
        return .pass
    }

    public mutating func keyDown(keyCode: UInt16, isPlainShiftSpace: Bool) -> Action {
        if keyCode == 49, !pressedShiftKeys.isEmpty, isPlainShiftSpace {
            shiftWasUsed = true
            return .requestWidthToggle
        }

        if !pressedShiftKeys.isEmpty {
            shiftWasUsed = true
        }
        return .pass
    }

    public mutating func widthToggleWasHandled() -> Action {
        consumeNextSpaceKeyUp = true
        return .consume
    }

    public mutating func keyUp(keyCode: UInt16) -> Action {
        if keyCode == 49, consumeNextSpaceKeyUp {
            consumeNextSpaceKeyUp = false
            return .consume
        }
        return .pass
    }

    public mutating func pointerActivity() -> Action {
        if !pressedShiftKeys.isEmpty {
            shiftWasUsed = true
        }
        return .pass
    }

    public mutating func reset() {
        pressedShiftKeys.removeAll(keepingCapacity: true)
        shiftWasUsed = false
        consumeNextSpaceKeyUp = false
    }
}
