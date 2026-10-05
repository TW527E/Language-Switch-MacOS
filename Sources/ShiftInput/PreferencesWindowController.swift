import AppKit
import UniformTypeIdentifiers

final class PreferencesWindowController: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {
    var onRetryPermission: (() -> Void)?

    private let settings: SettingsStore
    private let shiftToggleButton = NSButton(checkboxWithTitle: "啟用 Shift 輸入法切換", target: nil, action: nil)
    private let pinyinWidthToggleButton = NSButton(checkboxWithTitle: "啟用 Shift + Space 拼音全形／半形切換", target: nil, action: nil)
    private let automaticBypassButton = NSButton(checkboxWithTitle: "在遠端軟體與遊戲中自動放行兩項快捷鍵", target: nil, action: nil)
    private let excludedAppsTable = NSTableView()
    private var excludedBundleIDs: [String] = []
    private let addExcludedAppButton = NSButton(title: "加入 App…", target: nil, action: nil)
    private let removeExcludedAppButton = NSButton(title: "移除", target: nil, action: nil)
    private let centerHUDFallbackButton = NSButton(checkboxWithTitle: "macOS 未在游標旁顯示輸入法提示時，改在螢幕中央顯示", target: nil, action: nil)
    private let statusItemButton = NSButton(checkboxWithTitle: "在選單列顯示圖標", target: nil, action: nil)
    private let dockIconButton = NSButton(checkboxWithTitle: "在 Dock 顯示圖標", target: nil, action: nil)
    private let permissionStatus = NSTextField(labelWithString: "")
    private let permissionButton = NSButton(title: "授予／重新檢查權限", target: nil, action: nil)
    private lazy var toggles: [(button: NSButton, keyPath: ReferenceWritableKeyPath<SettingsStore, Bool>)] = [
        (shiftToggleButton, \.shiftToggleEnabled),
        (pinyinWidthToggleButton, \.pinyinWidthToggleEnabled),
        (automaticBypassButton, \.automaticallyBypassRemoteAppsAndGames),
        (centerHUDFallbackButton, \.showCenterHUDAsFallback),
        (statusItemButton, \.showStatusItem),
        (dockIconButton, \.showDockIcon)
    ]

    init(settings: SettingsStore) {
        self.settings = settings
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 680),
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
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Permissions change in System Settings, so the window rechecks them
    /// whenever the user comes back to it.
    func windowDidBecomeKey(_ notification: Notification) {
        refresh()
    }

    func refresh() {
        for toggle in toggles {
            toggle.button.state = settings[keyPath: toggle.keyPath] ? .on : .off
        }
        refreshExcludedApps()
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

        for toggle in toggles {
            toggle.button.target = self
            toggle.button.action = #selector(settingChanged(_:))
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

        let bypassTitle = NSTextField(labelWithString: "應用程式快捷鍵放行")
        bypassTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        let bypassNote = NSTextField(wrappingLabelWithString: "可分別決定每個 App 是否略過 Shift 輸入法切換及 Shift + Space 全／半形切換。新加入的 App 預設兩項都放行。自動模式會對常見遠端軟體及遊戲放行兩項快捷鍵。")
        bypassNote.font = .systemFont(ofSize: 12)
        bypassNote.textColor = .secondaryLabelColor
        let excludedAppsTitle = NSTextField(labelWithString: "應用程式列表")
        excludedAppsTitle.font = .systemFont(ofSize: 12, weight: .medium)
        for (identifier, title, width) in [("application", "應用程式", 230.0), ("shift", "Shift", 90), ("shiftSpace", "Shift + Space", 125)] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
            column.title = title
            column.width = width
            excludedAppsTable.addTableColumn(column)
        }
        excludedAppsTable.delegate = self
        excludedAppsTable.dataSource = self
        excludedAppsTable.usesAlternatingRowBackgroundColors = true
        excludedAppsTable.allowsMultipleSelection = false
        excludedAppsTable.rowHeight = 28
        let excludedAppsScrollView = NSScrollView()
        excludedAppsScrollView.hasVerticalScroller = true
        excludedAppsScrollView.autohidesScrollers = true
        excludedAppsScrollView.borderType = .bezelBorder
        excludedAppsScrollView.documentView = excludedAppsTable
        excludedAppsScrollView.widthAnchor.constraint(equalToConstant: 456).isActive = true
        excludedAppsScrollView.heightAnchor.constraint(equalToConstant: 106).isActive = true
        addExcludedAppButton.target = self
        addExcludedAppButton.action = #selector(addExcludedApp)
        removeExcludedAppButton.target = self
        removeExcludedAppButton.action = #selector(removeExcludedApp)
        let excludedAppControls = NSStackView(views: [addExcludedAppButton, removeExcludedAppButton])
        excludedAppControls.orientation = .horizontal
        excludedAppControls.alignment = .centerY
        excludedAppControls.spacing = 8

        let stack = NSStackView(views: [
            title, subtitle, separator(), shiftToggleButton, pinyinWidthToggleButton,
            shortcutTitle, shortcuts, centerHUDFallbackButton, separator(), bypassTitle, automaticBypassButton,
            bypassNote, excludedAppsTitle, excludedAppsScrollView, excludedAppControls, separator(), statusItemButton,
            dockIconButton, visibilityNote, separator(), permissionStatus,
            permissionButton
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        for view in [subtitle, visibilityNote, bypassNote] + stack.arrangedSubviews.filter({ $0 is NSBox }) {
            view.widthAnchor.constraint(equalToConstant: 456).isActive = true
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
        guard let keyPath = toggles.first(where: { $0.button === sender })?.keyPath else { return }
        settings[keyPath: keyPath] = sender.state == .on
    }

    @objc private func retryPermission() {
        onRetryPermission?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.refresh() }
    }

    @objc private func addExcludedApp() {
        guard let window else { return }
        let panel = NSOpenPanel()
        panel.title = "選擇要放行快捷鍵的 App"
        panel.prompt = "加入"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK,
                  let url = panel.url,
                  let bundleIdentifier = Bundle(url: url)?.bundleIdentifier else { return }
            self?.settings.setBypassed(true, bundleIdentifier: bundleIdentifier)
            self?.refresh()
            if let row = self?.excludedBundleIDs.firstIndex(of: bundleIdentifier) {
                self?.excludedAppsTable.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            }
        }
    }

    @objc private func removeExcludedApp() {
        let row = excludedAppsTable.selectedRow
        guard excludedBundleIDs.indices.contains(row) else { return }
        settings.setBypassed(false, bundleIdentifier: excludedBundleIDs[row])
    }

    private func refreshExcludedApps() {
        excludedBundleIDs = settings.excludedApplicationBundleIDs.sorted {
            displayName(for: $0).localizedCaseInsensitiveCompare(displayName(for: $1)) == .orderedAscending
        }
        excludedAppsTable.reloadData()
        removeExcludedAppButton.isEnabled = excludedAppsTable.selectedRow >= 0
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        excludedBundleIDs.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard excludedBundleIDs.indices.contains(row) else { return nil }
        let bundleIdentifier = excludedBundleIDs[row]
        guard let keyPath = bypassKeyPath(for: tableColumn) else {
            let label = NSTextField(labelWithString: displayName(for: bundleIdentifier))
            label.lineBreakMode = .byTruncatingTail
            label.toolTip = bundleIdentifier
            return label
        }
        let button = NSButton(checkboxWithTitle: "放行", target: self, action: #selector(shortcutBypassChanged(_:)))
        button.state = settings[keyPath: keyPath].contains(bundleIdentifier) ? .on : .off
        return button
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        removeExcludedAppButton.isEnabled = excludedAppsTable.selectedRow >= 0
    }

    private func bypassKeyPath(for column: NSTableColumn?) -> ReferenceWritableKeyPath<SettingsStore, Set<String>>? {
        switch column?.identifier.rawValue {
        case "shift": return \.shiftExcludedBundleIDs
        case "shiftSpace": return \.pinyinWidthExcludedBundleIDs
        default: return nil
        }
    }

    @objc private func shortcutBypassChanged(_ sender: NSButton) {
        let row = excludedAppsTable.row(for: sender)
        let column = excludedAppsTable.column(for: sender)
        guard excludedBundleIDs.indices.contains(row),
              excludedAppsTable.tableColumns.indices.contains(column),
              let keyPath = bypassKeyPath(for: excludedAppsTable.tableColumns[column]) else { return }
        if sender.state == .on {
            settings[keyPath: keyPath].insert(excludedBundleIDs[row])
        } else {
            settings[keyPath: keyPath].remove(excludedBundleIDs[row])
        }
    }

    private func displayName(for bundleIdentifier: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier),
              let bundle = Bundle(url: url) else { return bundleIdentifier }
        return bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? bundleIdentifier
    }
}
