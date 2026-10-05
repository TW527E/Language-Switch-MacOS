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
    private var pointerEventCountAtPress: UInt32 = 0
    private var consumeNextSpaceKeyUp = false

    public init() {}

    /// `isDown` comes from the event's flags rather than from alternating
    /// presses, so one missed event cannot invert the state and make every
    /// Shift press look like a release. `pointerEventCount` is any counter
    /// that grows with each click or scroll; a change while Shift is held
    /// means Shift-click or Shift-scroll, which is not a tap.
    public mutating func shiftFlagsChanged(
        keyCode: UInt16,
        isDown: Bool,
        hasOtherModifiers: Bool = false,
        pointerEventCount: UInt32 = 0
    ) -> Action {
        guard isDown else {
            // A release whose press was never seen is not a tap.
            guard pressedShiftKeys.remove(keyCode) != nil else { return .pass }
            if hasOtherModifiers || pointerEventCount != pointerEventCountAtPress {
                shiftWasUsed = true
            }
            guard pressedShiftKeys.isEmpty else { return .pass }

            let shouldToggle = !shiftWasUsed
            shiftWasUsed = false
            return shouldToggle ? .toggleInputSource : .pass
        }

        // Ignoring this key also recovers from its own missed release.
        if pressedShiftKeys.subtracting([keyCode]).isEmpty {
            shiftWasUsed = false
            pointerEventCountAtPress = pointerEventCount
        }
        pressedShiftKeys.insert(keyCode)
        if hasOtherModifiers {
            shiftWasUsed = true
        }
        return .pass
    }

    public mutating func otherModifierChanged() {
        if !pressedShiftKeys.isEmpty {
            shiftWasUsed = true
        }
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

    public mutating func widthToggleWasHandled() {
        consumeNextSpaceKeyUp = true
    }

    public mutating func keyUp(keyCode: UInt16) -> Action {
        if keyCode == 49, consumeNextSpaceKeyUp {
            consumeNextSpaceKeyUp = false
            return .consume
        }
        return .pass
    }

    public mutating func reset() {
        pressedShiftKeys.removeAll(keepingCapacity: true)
        shiftWasUsed = false
        consumeNextSpaceKeyUp = false
    }
}
