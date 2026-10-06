/// Decides what to do after `TISSelectInputSource` returns. Only the source ID
/// and its selected state are consulted: Apple Pinyin runs on top of the ABC
/// keyboard layout, so the active layout never identifies it as Pinyin.
public enum InputSourceSelectionPolicy {
    public enum Decision: Equatable, Sendable {
        case confirmed
        /// The destination is current but still activating. Selecting it
        /// again at this point can leave the input method in a Latin-only
        /// state, so the caller should only wait.
        case waitForSelection
        /// Another source is current; a bounded reselection is permitted.
        case retrySelection
    }

    public static func decision(expectedID: String, currentID: String?, isSelected: Bool?) -> Decision {
        guard let currentID else { return .waitForSelection }
        guard currentID == expectedID else { return .retrySelection }
        return isSelected == true ? .confirmed : .waitForSelection
    }
}
