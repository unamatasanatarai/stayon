import Cocoa

@MainActor
public final class StatusBarController: NSObject, NSMenuDelegate {
    public let model: StayOnModel
    private var statusItem: NSStatusItem?
    private var contextMenu: NSMenu!
    private var menuUpdateTimer: Timer?

    // Menu items
    public private(set) var statusMenuItem: NSMenuItem!
    public private(set) var durationMenuItems: [NSMenuItem] = []
    public private(set) var startAtLoginMenuItem: NSMenuItem!
    public private(set) var activateOnLaunchMenuItem: NSMenuItem!
    public private(set) var preventLogoutMenuItem: NSMenuItem!
    public private(set) var quitMenuItem: NSMenuItem!

    private var appearanceObservation: NSKeyValueObservation?
    private var themeObserverToken: NSObjectProtocol?
    private var wakeObserverToken: NSObjectProtocol?
    private var clockObserverToken: NSObjectProtocol?

    public init(model: StayOnModel = StayOnModel()) {
        self.model = model
        super.init()

        setupStatusItem()
        setupContextMenu()
        setupAppearanceAndSystemObservers()

        model.onStateChange = { [weak self] _ in
            if Thread.isMainThread {
                self?.updateIcon()
                self?.refreshStatusMenuItem()
            } else {
                DispatchQueue.main.async {
                    self?.updateIcon()
                    self?.refreshStatusMenuItem()
                }
            }
        }

        updateIcon()
    }

    deinit {
        menuUpdateTimer?.invalidate()
        appearanceObservation?.invalidate()
        if let token = themeObserverToken {
            DistributedNotificationCenter.default().removeObserver(token)
        }
        if let token = wakeObserverToken {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
        if let token = clockObserverToken {
            NotificationCenter.default.removeObserver(token)
        }
        if let item = statusItem {
            if Thread.isMainThread {
                NSStatusBar.system.removeStatusItem(item)
            }
        }
    }

    public func teardown() {
        stopMenuTimer()
        appearanceObservation?.invalidate()
        appearanceObservation = nil

        if let token = themeObserverToken {
            DistributedNotificationCenter.default().removeObserver(token)
            themeObserverToken = nil
        }
        if let token = wakeObserverToken {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
            wakeObserverToken = nil
        }
        if let token = clockObserverToken {
            NotificationCenter.default.removeObserver(token)
            clockObserverToken = nil
        }
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    public var currentMenu: NSMenu {
        return contextMenu
    }

    public var currentStatusItem: NSStatusItem? {
        return statusItem
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        guard let button = item.button else { return }

        button.target = self
        button.action = #selector(statusBarButtonClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "\(AppConfig.appName): \(model.statusText())"
        button.setAccessibilityElement(true)
        button.setAccessibilityLabel(AppConfig.appName)
        button.setAccessibilityValue(model.statusText())
    }

    private func setupContextMenu() {
        contextMenu = NSMenu()
        contextMenu.delegate = self
        contextMenu.autoenablesItems = false

        // 1. Dynamic status item (informational only per spec Section 4.1)
        statusMenuItem = NSMenuItem(
            title: model.statusText(),
            action: nil,
            keyEquivalent: ""
        )
        statusMenuItem.target = nil
        statusMenuItem.isEnabled = false
        contextMenu.addItem(statusMenuItem)

        contextMenu.addItem(NSMenuItem.separator())

        // 2. Duration shortcuts
        durationMenuItems = StayOnDuration.allCases.map { duration in
            let item = NSMenuItem(
                title: duration.title,
                action: #selector(durationSelected(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = Int(duration.rawValue)
            return item
        }
        for item in durationMenuItems {
            contextMenu.addItem(item)
        }

        contextMenu.addItem(NSMenuItem.separator())

        // 3. Start at Login
        startAtLoginMenuItem = NSMenuItem(
            title: "Start at Login",
            action: #selector(toggleStartAtLoginAction(_:)),
            keyEquivalent: ""
        )
        startAtLoginMenuItem.target = self
        startAtLoginMenuItem.onStateImage = StatusBarIcon.checkedCheckboxImage
        startAtLoginMenuItem.offStateImage = StatusBarIcon.uncheckedCheckboxImage
        contextMenu.addItem(startAtLoginMenuItem)

        // 4. Activate on Launch
        activateOnLaunchMenuItem = NSMenuItem(
            title: "Activate on Launch",
            action: #selector(toggleActivateOnLaunchAction(_:)),
            keyEquivalent: ""
        )
        activateOnLaunchMenuItem.target = self
        activateOnLaunchMenuItem.onStateImage = StatusBarIcon.checkedCheckboxImage
        activateOnLaunchMenuItem.offStateImage = StatusBarIcon.uncheckedCheckboxImage
        contextMenu.addItem(activateOnLaunchMenuItem)

        // 5. Prevent Logout
        preventLogoutMenuItem = NSMenuItem(
            title: "Prevent Logout",
            action: #selector(togglePreventLogoutAction(_:)),
            keyEquivalent: ""
        )
        preventLogoutMenuItem.target = self
        preventLogoutMenuItem.onStateImage = StatusBarIcon.checkedCheckboxImage
        preventLogoutMenuItem.offStateImage = StatusBarIcon.uncheckedCheckboxImage
        contextMenu.addItem(preventLogoutMenuItem)

        contextMenu.addItem(NSMenuItem.separator())

        // 6. Quit
        quitMenuItem = NSMenuItem(
            title: "Quit \(AppConfig.appName)",
            action: #selector(quitAction(_:)),
            keyEquivalent: "q"
        )
        quitMenuItem.keyEquivalentModifierMask = [.command]
        quitMenuItem.target = self
        contextMenu.addItem(quitMenuItem)

        updateMenuContent()
    }

    private func setupAppearanceAndSystemObservers() {
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { [weak self] in
                self?.updateIcon()
            }
        }

        themeObserverToken = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                self?.updateIcon()
            }
        }

        wakeObserverToken = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                self?.model.checkExpiration()
                self?.updateIcon()
                self?.updateMenuContent()
            }
        }

        clockObserverToken = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSSystemClockDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                self?.model.checkExpiration()
                self?.updateIcon()
                self?.updateMenuContent()
            }
        }
    }

    public func updateIcon() {
        guard let button = statusItem?.button else { return }
        let appearance = button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) ?? NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        let isDark = (appearance == .darkAqua)
        button.image = StatusBarIcon.image(isActive: model.state.isActive, isDark: isDark)
        button.toolTip = "\(AppConfig.appName): \(model.statusText())"
        button.setAccessibilityValue(model.statusText())
    }

    public func updateMenuContent() {
        refreshStatusMenuItem()
        startAtLoginMenuItem.state = model.isStartAtLoginEnabled ? .on : .off
        activateOnLaunchMenuItem.state = model.isActivateOnLaunchEnabled ? .on : .off
        preventLogoutMenuItem.state = model.isPreventLogoutEnabled ? .on : .off
    }

    public func refreshStatusMenuItem() {
        statusMenuItem.title = model.statusText()
        if let button = statusItem?.button {
            button.toolTip = "\(AppConfig.appName): \(model.statusText())"
            button.setAccessibilityValue(model.statusText())
        }
    }

    @objc public func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp ||
                           event?.type == .rightMouseDown ||
                           (event?.modifierFlags.contains(.control) == true)

        if isRightClick {
            openContextMenu()
        } else {
            model.toggleLeftClick()
        }
    }

    public func openContextMenu() {
        updateMenuContent()
        statusItem?.menu = contextMenu
        statusItem?.button?.performClick(nil)
    }

    // MARK: - NSMenuDelegate

    public func menuWillOpen(_ menu: NSMenu) {
        updateMenuContent()
        startMenuTimer()
    }

    public func menuDidClose(_ menu: NSMenu) {
        stopMenuTimer()
        statusItem?.menu = nil
    }

    private func startMenuTimer() {
        stopMenuTimer()
        menuUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                self?.refreshStatusMenuItem()
            }
        }
        if let timer = menuUpdateTimer {
            RunLoop.current.add(timer, forMode: .common)
            RunLoop.current.add(timer, forMode: .eventTracking)
        }
    }

    private func stopMenuTimer() {
        menuUpdateTimer?.invalidate()
        menuUpdateTimer = nil
    }

    // MARK: - Menu Actions

    @objc private func durationSelected(_ sender: NSMenuItem) {
        let seconds = TimeInterval(sender.tag)
        model.activateTimed(seconds: seconds)
    }

    @objc private func toggleStartAtLoginAction(_ sender: NSMenuItem) {
        let willEnable = (sender.state != .on)
        _ = model.setStartAtLogin(willEnable)
        updateMenuContent()
    }

    @objc private func toggleActivateOnLaunchAction(_ sender: NSMenuItem) {
        let willEnable = (sender.state != .on)
        model.setActivateOnLaunch(willEnable)
        updateMenuContent()
    }

    @objc private func togglePreventLogoutAction(_ sender: NSMenuItem) {
        let willEnable = (sender.state != .on)
        model.setPreventLogout(willEnable)
        updateMenuContent()
    }

    @objc private func quitAction(_ sender: NSMenuItem) {
        model.handleQuit()
        teardown()
        NSApp.terminate(nil)
    }
}

