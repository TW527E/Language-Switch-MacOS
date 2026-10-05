import AppKit
import Carbon
import ShiftInputCore

struct InputSourceDescriptor: Equatable {
    let id: String
    let name: String
    let languages: [String]
    let icon: NSImage?

    var shortLabel: String {
        if languages.contains(where: { $0.lowercased().hasPrefix("zh") }) {
            return "中"
        }
        if languages.contains(where: { $0.lowercased().hasPrefix("en") }) {
            return "英"
        }
        return String(name.prefix(1)).uppercased()
    }
}

final class InputSourceManager: NSObject {
    enum ToggleResult {
        case switched(InputSourceDescriptor, nativeIndicatorShown: Bool)
        case unavailable(String)
    }

    var onInputSourceChanged: ((InputSourceDescriptor) -> Void)?

    private let settings: SettingsStore
    private let notificationName = Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String)
    private var switchInProgress = false
    private(set) var currentSourceSupportsPinyinWidthToggle = false

    init(settings: SettingsStore) {
        self.settings = settings
        super.init()
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(inputSourceDidChange),
            name: notificationName,
            object: nil
        )
        let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        rememberCurrentSourceIfNeeded(current)
        updatePinyinWidthSupport(for: current)
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    var currentDescriptor: InputSourceDescriptor {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        return descriptor(for: source)
    }

    /// Delays selection until the Shift-up event has propagated to the old
    /// input method, then confirms that macOS has activated the destination.
    /// This prevents Apple Pinyin from occasionally receiving an unmatched
    /// Shift-up while it is still finishing activation and remaining in a
    /// Latin-only state. Returns false when a switch is already in progress.
    @discardableResult
    func toggleEnglishAndPrevious(completion: @escaping (ToggleResult) -> Void) -> Bool {
        guard !switchInProgress else { return false }

        let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        let english = TISCopyCurrentASCIICapableKeyboardInputSource().takeRetainedValue()
        let currentID = stringProperty(current, key: kTISPropertyInputSourceID) ?? ""
        let englishID = stringProperty(english, key: kTISPropertyInputSourceID) ?? ""

        if currentID == englishID {
            guard let previous = previousNonEnglishSource(excluding: englishID) else {
                completion(.unavailable("尚未記錄可返回的輸入法"))
                return true
            }
            beginConfirmedSelection(of: previous, completion: completion)
            return true
        }

        if !currentID.isEmpty {
            settings.lastNonEnglishSourceID = currentID
        }
        beginConfirmedSelection(of: english, completion: completion)
        return true
    }

    @objc private func inputSourceDidChange(_ notification: Notification) {
        // Use one snapshot for persistence, feature detection, and UI updates.
        // Besides avoiding repeated TIS queries, this prevents a rapid external
        // source change from producing a descriptor and capability mismatch.
        let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        rememberCurrentSourceIfNeeded(current)
        updatePinyinWidthSupport(for: current)
        let descriptor = descriptor(for: current)
        DispatchQueue.main.async { [weak self] in
            self?.onInputSourceChanged?(descriptor)
        }
    }

    private func updatePinyinWidthSupport(for source: TISInputSource) {
        let id = (stringProperty(source, key: kTISPropertyInputSourceID) ?? "").lowercased()
        let name = (stringProperty(source, key: kTISPropertyLocalizedName) ?? "").lowercased()
        currentSourceSupportsPinyinWidthToggle = PinyinInputSourceClassifier.isApplePinyin(
            id: id,
            localizedName: name
        )
    }

    private func rememberCurrentSourceIfNeeded(_ current: TISInputSource) {
        let english = TISCopyCurrentASCIICapableKeyboardInputSource().takeRetainedValue()
        guard let currentID = stringProperty(current, key: kTISPropertyInputSourceID),
              let englishID = stringProperty(english, key: kTISPropertyInputSourceID),
              currentID != englishID else { return }
        settings.lastNonEnglishSourceID = currentID
    }

    private func previousNonEnglishSource(excluding englishID: String) -> TISInputSource? {
        if let savedID = settings.lastNonEnglishSourceID,
           savedID != englishID,
           let saved = enabledSource(withID: savedID) {
            return saved
        }

        let filter: [CFString: Any] = [
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource!,
            kTISPropertyInputSourceIsEnabled: kCFBooleanTrue as Any,
            kTISPropertyInputSourceIsSelectCapable: kCFBooleanTrue as Any
        ]
        let sources = TISCreateInputSourceList(filter as CFDictionary, false)?.takeRetainedValue() as? [TISInputSource] ?? []
        return sources.first { source in
            guard stringProperty(source, key: kTISPropertyInputSourceID) != englishID else { return false }
            return arrayProperty(source, key: kTISPropertyInputSourceLanguages)?.contains {
                $0.lowercased().hasPrefix("zh")
            } ?? false
        }
    }

    private func enabledSource(withID id: String) -> TISInputSource? {
        let filter: [CFString: Any] = [
            kTISPropertyInputSourceID: id,
            kTISPropertyInputSourceIsEnabled: kCFBooleanTrue as Any,
            kTISPropertyInputSourceIsSelectCapable: kCFBooleanTrue as Any
        ]
        let sources = TISCreateInputSourceList(filter as CFDictionary, false)?.takeRetainedValue() as? [TISInputSource] ?? []
        return sources.first
    }

    private func beginConfirmedSelection(
        of source: TISInputSource,
        completion: @escaping (ToggleResult) -> Void
    ) {
        switchInProgress = true
        let expectedID = stringProperty(source, key: kTISPropertyInputSourceID) ?? ""

        // The event tap callback runs before the Shift-up reaches the active
        // app and input method. Delaying selection keeps that release with
        // the old source; keystrokes typed meanwhile are deferred by the
        // keyboard monitor, so the delay costs no input.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.select(source, expectedID: expectedID, reselectionsRemaining: 2, completion: completion)
        }
    }

    private func select(
        _ source: TISInputSource,
        expectedID: String,
        reselectionsRemaining: Int,
        completion: @escaping (ToggleResult) -> Void
    ) {
        let status = TISSelectInputSource(source)
        guard status == noErr else {
            finishSwitch(
                with: .unavailable("輸入法切換失敗（錯誤 \(status)）"),
                completion: completion
            )
            return
        }
        confirmSelection(
            of: source,
            expectedID: expectedID,
            pollsRemaining: 10,
            reselectionsRemaining: reselectionsRemaining,
            completion: completion
        )
    }

    /// Polls until the destination is current and selected. A source that is
    /// already current but still activating is never selected again, since
    /// repeated selection is what leaves Apple Pinyin showing its icon while
    /// producing Latin text.
    private func confirmSelection(
        of source: TISInputSource,
        expectedID: String,
        pollsRemaining: Int,
        reselectionsRemaining: Int,
        completion: @escaping (ToggleResult) -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
            guard let self else { return }
            let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
            let decision = InputSourceSelectionPolicy.decision(
                expectedID: expectedID,
                currentID: self.stringProperty(current, key: kTISPropertyInputSourceID),
                isSelected: self.boolProperty(source, key: kTISPropertyInputSourceIsSelected)
            )
            switch decision {
            case .confirmed:
                let descriptor = self.descriptor(for: current)
                let isCJKV = self.boolProperty(source, key: kTISPropertyInputSourceIsASCIICapable) == false
                self.waitForNativeIndicator(pollsRemaining: 6) { shown in
                    // The focused app draws the indicator once it has adopted
                    // the new source. The focus hand-off would dismiss it and
                    // flickers the window, so it only runs for a text input
                    // that never showed the indicator.
                    guard isCJKV, !shown, self.focusedElementAcceptsText() else {
                        self.finishSwitch(with: .switched(descriptor, nativeIndicatorShown: shown), completion: completion)
                        return
                    }
                    self.refreshFocusedInputContext {
                        self.finishSwitch(with: .switched(descriptor, nativeIndicatorShown: false), completion: completion)
                    }
                }
            case .waitForSelection where pollsRemaining > 0:
                self.confirmSelection(
                    of: source,
                    expectedID: expectedID,
                    pollsRemaining: pollsRemaining - 1,
                    reselectionsRemaining: reselectionsRemaining,
                    completion: completion
                )
            case .retrySelection where reselectionsRemaining > 0:
                self.select(
                    source,
                    expectedID: expectedID,
                    reselectionsRemaining: reselectionsRemaining - 1,
                    completion: completion
                )
            default:
                self.finishSwitch(
                    with: .unavailable("輸入法未完成切換，請再試一次"),
                    completion: completion
                )
            }
        }
    }

    /// macOS 14+ shows its input source indicator as a small floating window
    /// owned by the focused app, about 50 ms after a switch.
    private func waitForNativeIndicator(pollsRemaining: Int, completion: @escaping (Bool) -> Void) {
        if nativeIndicatorIsVisible() { return completion(true) }
        guard pollsRemaining > 0 else { return completion(false) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
            self?.waitForNativeIndicator(pollsRemaining: pollsRemaining - 1, completion: completion)
        }
    }

    private func nativeIndicatorIsVisible() -> Bool {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        let floatingLevel = Int(CGWindowLevelForKey(.floatingWindow))
        return windows.contains { window in
            guard window[kCGWindowOwnerPID as String] as? pid_t == pid,
                  window[kCGWindowLayer as String] as? Int == floatingLevel,
                  let boundsInfo = window[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsInfo as CFDictionary) else { return false }
            return bounds.width < 160 && bounds.height < 160
        }
    }

    private func focusedElementAcceptsText() -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        // Applies to every element; a busy app must not stall the switch.
        AXUIElementSetMessagingTimeout(systemWide, 0.1)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused,
              CFGetTypeID(focused) == AXUIElementGetTypeID() else { return false }
        var range: CFTypeRef?
        return AXUIElementCopyAttributeValue(
            focused as! AXUIElement,
            kAXSelectedTextRangeAttribute as CFString,
            &range
        ) == .success
    }

    /// A CJKV input method selected from a background process updates the
    /// menu bar but not the focused text field, which keeps producing Latin
    /// text until focus changes. Briefly taking focus and handing it back
    /// makes the field adopt the new source (the same fix macism uses).
    private func refreshFocusedInputContext(then done: @escaping () -> Void) {
        guard let previous = NSWorkspace.shared.frontmostApplication,
              previous != NSRunningApplication.current else { return done() }
        focusWindow.setFrameOrigin(NSEvent.mouseLocation)
        // Key and main before activating, so activation raises only this
        // window rather than an open Settings window.
        focusWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
            self?.focusWindow.orderOut(nil)
            previous.activate(options: [])
            // Let the app regain key focus before deferred keys are replayed.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03, execute: done)
        }
    }

    private lazy var focusWindow: NSWindow = {
        let window = FocusWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: .borderless,
            backing: .buffered,
            defer: true
        )
        window.alphaValue = 0
        window.level = .statusBar
        window.isReleasedWhenClosed = false
        return window
    }()

    private func finishSwitch(
        with result: ToggleResult,
        completion: @escaping (ToggleResult) -> Void
    ) {
        switchInProgress = false
        completion(result)
    }

    private func descriptor(for source: TISInputSource) -> InputSourceDescriptor {
        let id = stringProperty(source, key: kTISPropertyInputSourceID) ?? "unknown"
        let name = stringProperty(source, key: kTISPropertyLocalizedName) ?? id
        let languages = arrayProperty(source, key: kTISPropertyInputSourceLanguages) ?? []
        return InputSourceDescriptor(id: id, name: name, languages: languages, icon: icon(for: source))
    }

    private func icon(for source: TISInputSource) -> NSImage? {
        guard let pointer = TISGetInputSourceProperty(source, kTISPropertyIconImageURL) else { return nil }
        let value = Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue()
        guard let url = value as? URL else { return nil }
        return NSImage(contentsOf: url)
    }

    private func stringProperty(_ source: TISInputSource, key: CFString) -> String? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue() as? String
    }

    private func boolProperty(_ source: TISInputSource, key: CFString) -> Bool? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        let value = Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue()
        guard CFGetTypeID(value) == CFBooleanGetTypeID() else { return nil }
        return CFBooleanGetValue((value as! CFBoolean))
    }

    private func arrayProperty(_ source: TISInputSource, key: CFString) -> [String]? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue() as? [String]
    }
}

private final class FocusWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
