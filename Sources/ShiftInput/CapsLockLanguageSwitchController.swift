import Darwin
import Foundation

/// Reads and updates the same system-wide Roman/non-Roman Caps Lock switch
/// used by Keyboard Settings. The symbols are resolved at runtime so the app
/// continues to launch if Apple removes them in a future macOS release.
final class CapsLockLanguageSwitchController {
    private typealias BooleanGetter = @convention(c) () -> Int32
    private typealias StateSetter = @convention(c) (Int32) -> Void

    private let frameworkHandle: UnsafeMutableRawPointer?
    private let isAllowedFunction: BooleanGetter?
    private let isEnabledFunction: BooleanGetter?
    private let setStateFunction: StateSetter?

    init() {
        let path = "/System/Library/Frameworks/Carbon.framework/Frameworks/HIToolbox.framework/HIToolbox"
        let handle = dlopen(path, RTLD_LAZY | RTLD_LOCAL)
        frameworkHandle = handle
        isAllowedFunction = Self.loadSymbol("TISIsRomanSwitchAllowed", from: handle)
        isEnabledFunction = Self.loadSymbol("TISIsRomanSwitchEnabled", from: handle)
        setStateFunction = Self.loadSymbol("TISSetRomanSwitchState", from: handle)
    }

    deinit {
        if let frameworkHandle {
            dlclose(frameworkHandle)
        }
    }

    var isAvailable: Bool {
        guard let isAllowedFunction, isEnabledFunction != nil, setStateFunction != nil else {
            return false
        }
        return isAllowedFunction() != 0
    }

    var isSystemLanguageSwitchEnabled: Bool {
        isEnabledFunction?() != 0
    }

    /// Returns whether the system accepted the requested state.
    @discardableResult
    func setSystemLanguageSwitchEnabled(_ enabled: Bool) -> Bool {
        guard isAvailable, let setStateFunction else { return false }
        setStateFunction(enabled ? 1 : 0)
        return isSystemLanguageSwitchEnabled == enabled
    }

    private static func loadSymbol<T>(_ name: String, from handle: UnsafeMutableRawPointer?) -> T? {
        guard let handle, let symbol = dlsym(handle, name) else { return nil }
        return unsafeBitCast(symbol, to: T.self)
    }
}
