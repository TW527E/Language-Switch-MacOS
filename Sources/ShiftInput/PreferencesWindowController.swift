import AppKit

final class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    var onRetryPermission: (() -> Void)?

    private let settings: SettingsStore
    private let shiftToggleButton = NSButton(checkboxWithTitle: "啟用 Shift 輸入法切換", target: nil, action: nil)
    private let pinyinWidthToggleButton = NSButton(checkboxWithTitle: "啟用 Shift + Space 拼音全形／半形切換", target: nil, action: nil)
    private let statusItemButton = NSButton(checkboxWithTitle: "在選單列顯示圖標", target: nil, action: nil)
    private let dockIconButton = NSButton(checkboxWithTitle: "在 Dock 顯示圖標", target: nil, action: nil)
    private let permissionStatus = NSTextField(labelWithString: "")
    private let permissionButton = NSButton(title: "授予／重新檢查權限", target: nil, action: nil)

    init(settings: SettingsStore) {
        self.settings = settings
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ShiftInput 設定"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.delegate = self
        buildUI(in: window)
        refresh()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showAndActivate() {
        refresh()
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func refresh() {
        shiftToggleButton.state = settings.shiftToggleEnabled ? .on : .off
        pinyinWidthToggleButton.state = settings.pinyinWidthToggleEnabled ? .on : .off
        statusItemButton.state = settings.showStatusItem ? .on : .off
        dockIconButton.state = settings.showDockIcon ? .on : .off
        let status = AccessibilityPermission.status
        let granted = status.isFullyGranted
        permissionStatus.stringValue = granted
            ? "鍵盤權限：已授予（輔助使用、輸入監控）"
            : "尚缺權限：\(status.missingDescription)"
        permissionStatus.textColor = granted ? .systemGreen : .systemOrange
    }

    private func buildUI(in window: NSWindow) {
        guard let content = window.contentView else { return }

        let title = NSTextField(labelWithString: "ShiftInput")
        title.font = .systemFont(ofSize: 24, weight: .semibold)
        let subtitle = NSTextField(wrappingLabelWithString: "兩項快捷鍵可獨立啟用。Shift 用於輸入法切換；Shift + Space 僅用於 Apple 拼音輸入法的全形／半形切換。")
        subtitle.textColor = .secondaryLabelColor

        [shiftToggleButton, pinyinWidthToggleButton, statusItemButton, dockIconButton].forEach {
            $0.target = self
            $0.action = #selector(settingChanged(_:))
        }
        permissionStatus.font = .systemFont(ofSize: 13, weight: .medium)
        permissionButton.target = self
        permissionButton.action = #selector(retryPermission)
        permissionButton.bezelStyle = .rounded

        let visibilityNote = NSTextField(wrappingLabelWithString: "若同時隱藏選單列與 Dock 圖標，可再次從 Finder 開啟 ShiftInput 以回到設定。")
        visibilityNote.font = .systemFont(ofSize: 12)
        visibilityNote.textColor = .tertiaryLabelColor

        let shortcutTitle = NSTextField(labelWithString: "快捷鍵")
        shortcutTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        let shortcuts = NSTextField(wrappingLabelWithString: "Shift（單獨點按）　英文 ⇄ 上次輸入法\nShift + Space　　　Apple 拼音輸入法全形／半形")
        shortcuts.font = .monospacedSystemFont(ofSize: 13, weight: .regular)

        let stack = NSStackView(views: [
            title, subtitle, separator(), shiftToggleButton, pinyinWidthToggleButton,
            shortcutTitle, shortcuts, separator(), statusItemButton,
            dockIconButton, visibilityNote, separator(), permissionStatus,
            permissionButton
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        subtitle.widthAnchor.constraint(equalToConstant: 456).isActive = true
        visibilityNote.widthAnchor.constraint(equalToConstant: 456).isActive = true
        stack.arrangedSubviews.compactMap { $0 as? NSBox }.forEach {
            $0.widthAnchor.constraint(equalToConstant: 456).isActive = true
        }
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -32),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 26)
        ])
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    @objc private func settingChanged(_ sender: NSButton) {
        switch sender {
        case shiftToggleButton:
            settings.shiftToggleEnabled = sender.state == .on
        case pinyinWidthToggleButton:
            settings.pinyinWidthToggleEnabled = sender.state == .on
        case statusItemButton:
            settings.showStatusItem = sender.state == .on
        case dockIconButton:
            settings.showDockIcon = sender.state == .on
        default:
            break
        }
    }

    @objc private func retryPermission() {
        onRetryPermission?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.refresh() }
    }
}
