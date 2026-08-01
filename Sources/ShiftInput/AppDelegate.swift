import AppKit
import ShiftInputCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore.shared
    private lazy var inputSources = InputSourceManager(settings: settings)
    private let keyboardMonitor = GlobalKeyboardMonitor()
    private let hud = InputSourceHUDController()
    private lazy var statusBar = StatusBarController(settings: settings, initialSource: inputSources.currentDescriptor)
    private lazy var preferences = PreferencesWindowController(settings: settings)
    private var settingsObserver: NSObjectProtocol?
    private var workspaceObserver: NSObjectProtocol?
    private var foregroundApplication: ForegroundApplicationInfo?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let isFirstLaunch = settings.consumeFirstLaunch()
        rememberForegroundApplication(NSWorkspace.shared.frontmostApplication)
        configureApplicationMenu()
        applyDockVisibility()
        configureCallbacks()

        _ = statusBar
        _ = preferences
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .shiftInputSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.settingsDidChange()
        }
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.rememberForegroundApplication(application)
            self?.refreshKeyboardMonitor()
            self?.refreshPermissionUI()
            self?.preferences.refresh()
        }

        if settings.hasEnabledKeyboardFeature {
            _ = AccessibilityPermission.requestIfNeeded()
            refreshKeyboardMonitor()
        }
        refreshPermissionUI()
        if isFirstLaunch || !AccessibilityPermission.isGranted {
            DispatchQueue.main.async { [weak self] in
                self?.preferences.showAndActivate()
            }
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        refreshKeyboardMonitor()
        refreshPermissionUI()
        preferences.refresh()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        preferences.showAndActivate()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        keyboardMonitor.stop()
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
        }
    }

    private func configureCallbacks() {
        inputSources.onInputSourceChanged = { [weak self] source in
            self?.statusBar.update(source: source)
        }
        keyboardMonitor.onShiftTap = { [weak self] in
            guard let self, self.settings.shiftToggleEnabled else { return }
            self.inputSources.toggleEnglishAndPrevious { [weak self] result in
                guard let self else { return }
                switch result {
                case .switched(let source):
                    self.statusBar.update(source: source)
                    self.hud.show(source: source)
                case .unavailable:
                    NSSound.beep()
                }
            }
        }
        keyboardMonitor.shouldHandleShiftTap = { [weak self] in
            guard let self, self.settings.shiftToggleEnabled else { return false }
            return !self.shouldBypassShortcut(manualBundleIDs: self.settings.shiftExcludedBundleIDs)
        }
        keyboardMonitor.shouldHandleWidthToggle = { [weak self] in
            guard let self, self.settings.pinyinWidthToggleEnabled else { return false }
            guard self.inputSources.currentSourceSupportsPinyinWidthToggle else { return false }
            return !self.shouldBypassShortcut(manualBundleIDs: self.settings.pinyinWidthExcludedBundleIDs)
        }
        keyboardMonitor.onWidthToggle = {
            GlobalKeyboardMonitor.postNativeChineseWidthShortcut()
        }
        keyboardMonitor.onTapDisabled = { [weak self] in
            DispatchQueue.main.async {
                self?.refreshKeyboardMonitor()
                self?.refreshPermissionUI()
            }
        }
        statusBar.onOpenPreferences = { [weak self] in self?.preferences.showAndActivate() }
        statusBar.onRetryPermission = { [weak self] in self?.requestAndRefreshPermission() }
        statusBar.foregroundApplicationProvider = { [weak self] in self?.foregroundApplication }
        preferences.onRetryPermission = { [weak self] in self?.requestAndRefreshPermission() }
    }

    private func shouldBypassShortcut(manualBundleIDs: Set<String>) -> Bool {
        guard let application = foregroundApplication else { return false }
        return ApplicationBypassPolicy.shouldBypass(
            bundleIdentifier: application.bundleIdentifier,
            localizedName: application.localizedName,
            bundlePath: application.bundlePath,
            applicationCategory: application.applicationCategory,
            excludedBundleIdentifiers: manualBundleIDs,
            automaticBypassEnabled: settings.automaticallyBypassRemoteAppsAndGames
        )
    }

    private func rememberForegroundApplication(_ application: NSRunningApplication?) {
        guard let application,
              let info = ForegroundApplicationInfo(runningApplication: application) else { return }
        foregroundApplication = info
    }

    private func settingsDidChange() {
        applyDockVisibility()
        statusBar.applyVisibility()
        refreshKeyboardMonitor()
        refreshPermissionUI()
        preferences.refresh()
    }

    private func refreshKeyboardMonitor() {
        guard settings.hasEnabledKeyboardFeature else {
            keyboardMonitor.stop()
            return
        }
        guard AccessibilityPermission.isGranted else {
            keyboardMonitor.stop()
            return
        }
        let configuration = GlobalKeyboardMonitor.Configuration(
            shiftToggleEnabled: settings.shiftToggleEnabled,
            pinyinWidthToggleEnabled: settings.pinyinWidthToggleEnabled
        )
        if !keyboardMonitor.isRunning || keyboardMonitor.configuration != configuration {
            _ = keyboardMonitor.start(configuration: configuration)
        }
    }

    private func requestAndRefreshPermission() {
        if !AccessibilityPermission.requestIfNeeded() {
            AccessibilityPermission.openMissingSystemSettings()
        }
        refreshKeyboardMonitor()
        refreshPermissionUI()
        preferences.refresh()
    }

    private func refreshPermissionUI() {
        statusBar.updatePermission(granted: AccessibilityPermission.isGranted)
    }

    private func applyDockVisibility() {
        let policy: NSApplication.ActivationPolicy = settings.showDockIcon ? .regular : .accessory
        NSApp.setActivationPolicy(policy)
        if settings.showDockIcon {
            configureApplicationMenu()
        }
    }

    private func configureApplicationMenu() {
        let mainMenu = NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu()
        applicationMenu.addItem(withTitle: "關於 ShiftInput", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        applicationMenu.addItem(.separator())
        let preferencesItem = NSMenuItem(title: "設定…", action: #selector(openPreferencesFromMenu), keyEquivalent: ",")
        preferencesItem.target = self
        applicationMenu.addItem(preferencesItem)
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(withTitle: "隱藏 ShiftInput", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        applicationMenu.addItem(withTitle: "結束 ShiftInput", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        applicationItem.submenu = applicationMenu
        mainMenu.addItem(applicationItem)
        NSApp.mainMenu = mainMenu
    }

    @objc private func openPreferencesFromMenu() {
        preferences.showAndActivate()
    }
}
