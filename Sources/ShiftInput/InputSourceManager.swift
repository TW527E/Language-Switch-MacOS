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
        case switched(InputSourceDescriptor)
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
    /// Latin-only state.
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
        let sources = TISCreateInputSourceList(filter as CFDictionary, false).takeRetainedValue() as! [TISInputSource]
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
        let sources = TISCreateInputSourceList(filter as CFDictionary, false).takeRetainedValue() as! [TISInputSource]
        return sources.first
    }

    private func beginConfirmedSelection(
        of source: TISInputSource,
        completion: @escaping (ToggleResult) -> Void
    ) {
        switchInProgress = true
        let expectedID = stringProperty(source, key: kTISPropertyInputSourceID) ?? ""
        let descriptor = descriptor(for: source)
        let expectsPinyin = PinyinInputSourceClassifier.isApplePinyin(
            id: descriptor.id,
            localizedName: descriptor.name
        )

        // The event tap callback runs before the Shift-up reaches the active
        // app and input method. A short delay keeps that release associated
        // with the old source without adding perceptible switching latency.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) { [weak self] in
            self?.selectAndConfirm(
                source,
                expectedID: expectedID,
                expectsPinyin: expectsPinyin,
                retriesRemaining: 3,
                completion: completion
            )
        }
    }

    private func selectAndConfirm(
        _ source: TISInputSource,
        expectedID: String,
        expectsPinyin: Bool,
        retriesRemaining: Int,
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.035) { [weak self] in
            guard let self else { return }
            if self.selectionIsConfirmed(expectedID: expectedID, expectsPinyin: expectsPinyin) {
                self.finishSwitch(with: .switched(self.currentDescriptor), completion: completion)
            } else if retriesRemaining > 0 {
                self.selectAndConfirm(
                    source,
                    expectedID: expectedID,
                    expectsPinyin: expectsPinyin,
                    retriesRemaining: retriesRemaining - 1,
                    completion: completion
                )
            } else {
                self.finishSwitch(
                    with: .unavailable("輸入法未完成切換，請再試一次"),
                    completion: completion
                )
            }
        }
    }

    private func selectionIsConfirmed(expectedID: String, expectsPinyin: Bool) -> Bool {
        let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        guard stringProperty(current, key: kTISPropertyInputSourceID) == expectedID else {
            return false
        }
        guard expectsPinyin else { return true }

        // For Apple Pinyin, the input source ID may change before its Pinyin
        // keyboard layout is ready. Waiting for both prevents the UI from
        // claiming success while keystrokes are still handled as Latin text.
        let layout = TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue()
        let layoutID = stringProperty(layout, key: kTISPropertyInputSourceID) ?? ""
        let layoutName = stringProperty(layout, key: kTISPropertyLocalizedName) ?? ""
        return PinyinInputSourceClassifier.isApplePinyin(id: layoutID, localizedName: layoutName)
    }

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

    private func arrayProperty(_ source: TISInputSource, key: CFString) -> [String]? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue() as? [String]
    }
}
