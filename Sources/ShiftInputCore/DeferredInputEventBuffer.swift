/// Holds keystrokes typed while an input-source switch is being confirmed so
/// they reach the destination input method instead of the outgoing one.
public struct DeferredInputEventBuffer<Element> {
    private var events: [Element] = []
    public private(set) var isActive = false

    public init() {}

    /// Starts deferral. Returns false when a deferral is already active.
    @discardableResult
    public mutating func begin() -> Bool {
        guard !isActive else { return false }
        isActive = true
        events.removeAll(keepingCapacity: true)
        return true
    }

    /// Stores the event and returns true only while deferral is active.
    public mutating func appendIfActive(_ event: Element) -> Bool {
        guard isActive else { return false }
        events.append(event)
        return true
    }

    /// Ends deferral and returns the stored events in their original order.
    public mutating func finish() -> [Element] {
        isActive = false
        let released = events
        events.removeAll(keepingCapacity: true)
        return released
    }
}
