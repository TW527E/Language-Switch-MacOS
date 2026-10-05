import AppKit

final class StatusBarController: NSObject, NSMenuDelegate {
    var onOpenPreferences: (() -> Void)?
    var onRetryPermission: (() -> Void)?
    var foregroundApplicationProvider: (() -> ForegroundApplicationInfo?)?

    private let settings: SettingsStore
    private var statusItem: NSStatusItem?
    private var currentSource: InputSourceDescriptor

    init(settings: SettingsStore, initialSource: InputSourceDescriptor) {
        self.settings = settings
        self.currentSource = initialSource
        super.init()
        applyVisibility()
    }

    func applyVisibility() {
        if settings.showStatusItem, statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            let menu = NSMenu()
            menu.delegate = self
            menuNeedsUpdate(menu)
            item.menu = menu
            statusItem = item
            updateButton()
        } else if !settings.showStatusItem, let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    func update(source: InputSourceDescriptor) {
        currentSource = source
        updateButton()
    }

    private func updateButton() {
        guard let button = statusItem?.button else { return }
        let description = "ShiftIME，目前輸入法：\(currentSource.name)"
        let icon = NSImage(systemSymbolName: "character.cursor.ibeam", accessibilityDescription: description)
            ?? NSImage(systemSymbolName: "keyboard", accessibilityDescription: description)
        icon?.isTemplate = true
        button.image = icon
        button.imagePosition = .imageLeading
        button.title = " \(currentSource.shortLabel)"
        button.font = .systemFont(ofSize: 13, weight: .semibold)
        button.toolTip = "ShiftIME · \(currentSource.name)"
        button.setAccessibilityLabel(description)
    }

    /// Rebuilt on every open, so it always shows current settings and
    /// permission state. Items without an action are disabled by NSMenu.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(withTitle: "目前：\(currentSource.name)", action: nil, keyEquivalent: "")
        menu.addItem(toggle("啟用 Shift 輸入法切換", \.shiftToggleEnabled))
        menu.addItem(toggle("啟用 Shift + Space 拼音全／半形", \.pinyinWidthToggleEnabled))
        menu.addItem(toggle("在遠端軟體與遊戲中自動放行兩項快捷鍵", \.automaticallyBypassRemoteAppsAndGames))
        menu.addItem(currentAppBypassItem())
        if !AccessibilityPermission.isGranted {
            menu.addItem(item("完成鍵盤監聽權限設定…", #selector(retryPermission)))
        }
        menu.addItem(.separator())
        menu.addItem(item("設定…", #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(withTitle: "結束 ShiftIME", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    private func currentAppBypassItem() -> NSMenuItem {
        guard let application = foregroundApplicationProvider?() else {
            return NSMenuItem(title: "在目前 App 中放行兩項快捷鍵", action: nil, keyEquivalent: "")
        }
        if settings.automaticallyBypassRemoteAppsAndGames, application.isRemoteOrGame {
            let item = NSMenuItem(title: "已自動放行兩項快捷鍵：\(application.localizedName)", action: nil, keyEquivalent: "")
            item.state = .on
            return item
        }
        let item = item("在「\(application.localizedName)」中放行兩項快捷鍵", #selector(toggleCurrentAppBypass))
        let shiftIsExcluded = settings.shiftExcludedBundleIDs.contains(application.bundleIdentifier)
        let widthIsExcluded = settings.pinyinWidthExcludedBundleIDs.contains(application.bundleIdentifier)
        if shiftIsExcluded && widthIsExcluded {
            item.state = .on
        } else if shiftIsExcluded || widthIsExcluded {
            item.state = .mixed
        }
        return item
    }

    private func toggle(_ title: String, _ keyPath: ReferenceWritableKeyPath<SettingsStore, Bool>) -> NSMenuItem {
        let item = item(title, #selector(toggleSetting(_:)))
        item.representedObject = keyPath
        item.state = settings[keyPath: keyPath] ? .on : .off
        return item
    }

    private func item(_ title: String, _ action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    @objc private func toggleSetting(_ sender: NSMenuItem) {
        guard let keyPath = sender.representedObject as? ReferenceWritableKeyPath<SettingsStore, Bool> else { return }
        settings[keyPath: keyPath].toggle()
    }

    @objc private func toggleCurrentAppBypass() {
        guard let application = foregroundApplicationProvider?() else { return }
        let isFullyBypassed = settings.shiftExcludedBundleIDs.contains(application.bundleIdentifier)
            && settings.pinyinWidthExcludedBundleIDs.contains(application.bundleIdentifier)
        settings.setBypassed(!isFullyBypassed, bundleIdentifier: application.bundleIdentifier)
    }

    @objc private func retryPermission() {
        onRetryPermission?()
    }

    @objc private func openPreferences() {
        onOpenPreferences?()
    }
}
