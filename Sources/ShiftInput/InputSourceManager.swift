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
        rememberCurrentSourceIfNeeded()
        updatePinyinWidthSupport()
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    var currentDescriptor: InputSourceDescriptor {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        return descriptor(for: source)
    }

    func toggleEnglishAndPrevious() -> ToggleResult {
        let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        let english = TISCopyCurrentASCIICapableKeyboardInputSource().takeRetainedValue()
        let currentID = stringProperty(current, key: kTISPropertyInputSourceID) ?? ""
        let englishID = stringProperty(english, key: kTISPropertyInputSourceID) ?? ""

        if currentID == englishID {
            guard let previous = previousNonEnglishSource(excluding: englishID) else {
                return .unavailable("尚未記錄可返回的輸入法")
            }
            return select(previous)
        }

        if !currentID.isEmpty {
            settings.lastNonEnglishSourceID = currentID
        }
        return select(english)
    }

    @objc private func inputSourceDidChange(_ notification: Notification) {
        rememberCurrentSourceIfNeeded()
        updatePinyinWidthSupport()
        let descriptor = currentDescriptor
        DispatchQueue.main.async { [weak self] in
            self?.onInputSourceChanged?(descriptor)
        }
    }

    private func updatePinyinWidthSupport() {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        let id = (stringProperty(source, key: kTISPropertyInputSourceID) ?? "").lowercased()
        let name = (stringProperty(source, key: kTISPropertyLocalizedName) ?? "").lowercased()
        currentSourceSupportsPinyinWidthToggle = PinyinInputSourceClassifier.isApplePinyin(
            id: id,
            localizedName: name
        )
    }

    private func rememberCurrentSourceIfNeeded() {
        let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
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

    private func select(_ source: TISInputSource) -> ToggleResult {
        let status = TISSelectInputSource(source)
        guard status == noErr else {
            return .unavailable("輸入法切換失敗（錯誤 \(status)）")
        }
        return .switched(descriptor(for: source))
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
