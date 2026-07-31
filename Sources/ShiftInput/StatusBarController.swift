import AppKit

final class StatusBarController: NSObject, NSMenuDelegate {
    var onOpenPreferences: (() -> Void)?
    var onRetryPermission: (() -> Void)?

    private let settings: SettingsStore
    private var statusItem: NSStatusItem?
    private var currentSource: InputSourceDescriptor
    private var accessibilityGranted = false
    private static let currentSourceItemIdentifier = NSUserInterfaceItemIdentifier("ShiftInput.currentSource")

    init(settings: SettingsStore, initialSource: InputSourceDescriptor) {
        self.settings = settings
        self.currentSource = initialSource
        super.init()
        applyVisibility()
    }

    func applyVisibility() {
        if settings.showStatusItem, statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.menu = makeMenu()
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

    func updatePermission(granted: Bool) {
        accessibilityGranted = granted
        statusItem?.menu = makeMenu()
    }

    private func updateButton() {
        guard let button = statusItem?.button else { return }
        let description = "ShiftInput，目前輸入法：\(currentSource.name)"
        let icon = NSImage(systemSymbolName: "character.cursor.ibeam", accessibilityDescription: description)
            ?? NSImage(systemSymbolName: "keyboard", accessibilityDescription: description)
        icon?.isTemplate = true
        button.image = icon
        button.imagePosition = .imageLeading
        button.title = " \(currentSource.shortLabel)"
        button.font = .systemFont(ofSize: 13, weight: .semibold)
        button.toolTip = "ShiftInput · \(currentSource.name)"
        button.setAccessibilityLabel(description)
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        let sourceItem = NSMenuItem(title: "目前：\(currentSource.name)", action: nil, keyEquivalent: "")
        sourceItem.identifier = Self.currentSourceItemIdentifier
        sourceItem.isEnabled = false
        menu.addItem(sourceItem)

        let shiftToggle = NSMenuItem(title: "啟用 Shift 輸入法切換", action: #selector(toggleShift(_:)), keyEquivalent: "")
        shiftToggle.target = self
        shiftToggle.state = settings.shiftToggleEnabled ? .on : .off
        menu.addItem(shiftToggle)

        let widthToggle = NSMenuItem(title: "啟用 Shift + Space 拼音全／半形", action: #selector(togglePinyinWidth(_:)), keyEquivalent: "")
        widthToggle.target = self
        widthToggle.state = settings.pinyinWidthToggleEnabled ? .on : .off
        menu.addItem(widthToggle)

        if !accessibilityGranted {
            let permission = NSMenuItem(title: "完成鍵盤監聽權限設定…", action: #selector(retryPermission), keyEquivalent: "")
            permission.target = self
            menu.addItem(permission)
        }

        menu.addItem(.separator())
        let preferences = NSMenuItem(title: "設定…", action: #selector(openPreferences), keyEquivalent: ",")
        preferences.target = self
        menu.addItem(preferences)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "結束 ShiftInput", action: #selector(quitApplication), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        return menu
    }

    @objc private func toggleShift(_ sender: NSMenuItem) {
        settings.shiftToggleEnabled.toggle()
    }

    @objc private func togglePinyinWidth(_ sender: NSMenuItem) {
        settings.pinyinWidthToggleEnabled.toggle()
    }

    func menuWillOpen(_ menu: NSMenu) {
        for item in menu.items {
            if item.identifier == Self.currentSourceItemIdentifier {
                item.title = "目前：\(currentSource.name)"
            }
            switch item.action {
            case #selector(toggleShift(_:)):
                item.state = settings.shiftToggleEnabled ? .on : .off
            case #selector(togglePinyinWidth(_:)):
                item.state = settings.pinyinWidthToggleEnabled ? .on : .off
            default:
                break
            }
        }
    }

    @objc private func retryPermission() {
        onRetryPermission?()
    }

    @objc private func openPreferences() {
        onOpenPreferences?()
    }

    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }
}
