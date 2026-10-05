import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore()
    private lazy var inputSources = InputSourceManager(settings: settings)
    private let keyboardMonitor = GlobalKeyboardMonitor()
    private let hud = InputSourceHUDController()
    private lazy var statusBar = StatusBarController(settings: settings, initialSource: inputSources.currentDescriptor)
    private lazy var preferences = PreferencesWindowController(settings: settings)
    private var foregroundApplication: ForegroundApplicationInfo?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let isFirstLaunch = settings.consumeFirstLaunch()
        rememberForegroundApplication(NSWorkspace.shared.frontmostApplication)
        configureApplicationMenu()
        configureCallbacks()

        NotificationCenter.default.addObserver(
            forName: .shiftIMESettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.settingsDidChange()
        }
        // Also fires for this app; permission may have been granted meanwhile.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.rememberForegroundApplication(notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)
            self?.refreshKeyboardMonitor()
        }

        if settings.hasEnabledKeyboardFeature {
            AccessibilityPermission.requestIfNeeded()
        }
        settingsDidChange()
        if isFirstLaunch || !AccessibilityPermission.isGranted {
            DispatchQueue.main.async { [weak self] in
                self?.preferences.showAndActivate()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        preferences.showAndActivate()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        keyboardMonitor.stop()
    }

    private func configureCallbacks() {
        inputSources.onInputSourceChanged = { [weak self] source in
            self?.statusBar.update(source: source)
        }
        keyboardMonitor.shouldHandleShiftTap = { [weak self] in
            guard let self else { return false }
            return self.settings.shiftToggleEnabled && !self.isBypassed(self.settings.shiftExcludedBundleIDs)
        }
        keyboardMonitor.shouldHandleWidthToggle = { [weak self] in
            guard let self else { return false }
            return self.settings.pinyinWidthToggleEnabled
                && self.inputSources.currentSourceSupportsPinyinWidthToggle
                && !self.isBypassed(self.settings.pinyinWidthExcludedBundleIDs)
        }
        keyboardMonitor.onShiftTap = { [weak self] in
            // A switch already in progress keeps the active deferral and
            // releases it from its own completion.
            self?.inputSources.toggleEnglishAndPrevious { [weak self] result in
                guard let self else { return }
                self.keyboardMonitor.finishDeferringInput()
                switch result {
                case .switched(let source, let nativeIndicatorShown):
                    self.statusBar.update(source: source)
                    if !nativeIndicatorShown, self.settings.showCenterHUDAsFallback {
                        self.hud.show(source: source)
                    }
                case .unavailable:
                    NSSound.beep()
                }
            }
        }
        keyboardMonitor.onTapDisabled = { [weak self] in
            DispatchQueue.main.async { self?.refreshKeyboardMonitor() }
        }
        statusBar.onOpenPreferences = { [weak self] in self?.preferences.showAndActivate() }
        statusBar.onRetryPermission = { [weak self] in self?.requestAndRefreshPermission() }
        statusBar.foregroundApplicationProvider = { [weak self] in self?.foregroundApplication }
        preferences.onRetryPermission = { [weak self] in self?.requestAndRefreshPermission() }
    }

    private func isBypassed(_ excludedBundleIDs: Set<String>) -> Bool {
        guard let application = foregroundApplication else { return false }
        return excludedBundleIDs.contains(application.bundleIdentifier)
            || (settings.automaticallyBypassRemoteAppsAndGames && application.isRemoteOrGame)
    }

    private func rememberForegroundApplication(_ application: NSRunningApplication?) {
        guard let application,
              let info = ForegroundApplicationInfo(runningApplication: application) else { return }
        foregroundApplication = info
    }

    private func settingsDidChange() {
        NSApp.setActivationPolicy(settings.showDockIcon ? .regular : .accessory)
        statusBar.applyVisibility()
        refreshKeyboardMonitor()
        preferences.refresh()
    }

    private func refreshKeyboardMonitor() {
        if settings.hasEnabledKeyboardFeature, AccessibilityPermission.isGranted {
            keyboardMonitor.start()
        } else {
            keyboardMonitor.stop()
        }
    }

    private func requestAndRefreshPermission() {
        if !AccessibilityPermission.requestIfNeeded() {
            AccessibilityPermission.openMissingSystemSettings()
        }
        refreshKeyboardMonitor()
        preferences.refresh()
    }

    private func configureApplicationMenu() {
        let mainMenu = NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu()
        applicationMenu.addItem(withTitle: "關於 ShiftIME", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        applicationMenu.addItem(.separator())
        let preferencesItem = NSMenuItem(title: "設定…", action: #selector(openPreferencesFromMenu), keyEquivalent: ",")
        preferencesItem.target = self
        applicationMenu.addItem(preferencesItem)
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(withTitle: "隱藏 ShiftIME", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        applicationMenu.addItem(withTitle: "結束 ShiftIME", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        applicationItem.submenu = applicationMenu
        mainMenu.addItem(applicationItem)
        NSApp.mainMenu = mainMenu
    }

    @objc private func openPreferencesFromMenu() {
        preferences.showAndActivate()
    }
}
