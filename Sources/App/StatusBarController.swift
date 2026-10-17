import Cocoa

public final class StatusBarController: NSObject, NSMenuDelegate {
    public let model: StayOnModel
    private var statusItem: NSStatusItem!
    private var contextMenu: NSMenu!
    private var menuUpdateTimer: Timer?

    // Menu items
    public private(set) var statusMenuItem: NSMenuItem!
    public private(set) var durationMenuItems: [NSMenuItem] = []
    public private(set) var startAtLoginMenuItem: NSMenuItem!
    public private(set) var activateOnLaunchMenuItem: NSMenuItem!
    public private(set) var quitMenuItem: NSMenuItem!

    private var appearanceObservation: NSKeyValueObservation?

    public init(model: StayOnModel = StayOnModel()) {
        self.model = model
        super.init()

        setupStatusItem()
        setupContextMenu()
        setupAppearanceObserver()

        model.onStateChange = { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateIcon()
                self?.refreshStatusMenuItem()
            }
        }

        updateIcon()
    }

    public var currentMenu: NSMenu {
        return contextMenu
    }

    public var currentStatusItem: NSStatusItem {
        return statusItem
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }

        button.target = self
        button.action = #selector(statusBarButtonClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = AppConfig.appName
    }

    private func setupContextMenu() {
        contextMenu = NSMenu()
        contextMenu.delegate = self
        contextMenu.autoenablesItems = false

        // 1. Dynamic status item
        statusMenuItem = NSMenuItem(
            title: model.statusText(),
            action: #selector(statusMenuItemClicked(_:)),
            keyEquivalent: ""
        )
        statusMenuItem.target = self
        statusMenuItem.isEnabled = true
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

        contextMenu.addItem(NSMenuItem.separator())

        // 5. Quit
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

    private func setupAppearanceObserver() {
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.updateIcon()
            }
        }

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateIcon()
        }
    }

    public func updateIcon() {
        guard let button = statusItem.button else { return }
        let appearance = button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) ?? NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        let isDark = (appearance == .darkAqua)
        button.image = StatusBarIcon.image(isActive: model.state.isActive, isDark: isDark)
    }

    public func updateMenuContent() {
        refreshStatusMenuItem()
        startAtLoginMenuItem.state = model.isStartAtLoginEnabled ? .on : .off
        activateOnLaunchMenuItem.state = model.isActivateOnLaunchEnabled ? .on : .off
    }

    public func refreshStatusMenuItem() {
        statusMenuItem.title = model.statusText()
    }

    @objc public func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp || (event?.modifierFlags.contains(.control) == true)

        if isRightClick {
            openContextMenu()
        } else {
            model.toggleLeftClick()
        }
    }

    public func openContextMenu() {
        updateMenuContent()
        statusItem.menu = contextMenu
        statusItem.button?.performClick(nil)
    }

    // MARK: - NSMenuDelegate

    public func menuWillOpen(_ menu: NSMenu) {
        updateMenuContent()
        startMenuTimer()
    }

    public func menuDidClose(_ menu: NSMenu) {
        stopMenuTimer()
        statusItem.menu = nil
    }

    private func startMenuTimer() {
        stopMenuTimer()
        menuUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshStatusMenuItem()
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

    @objc private func statusMenuItemClicked(_ sender: NSMenuItem) {
        if model.state.isActive {
            model.deactivate()
        } else {
            model.activateIndefinitely()
        }
    }

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

    @objc private func quitAction(_ sender: NSMenuItem) {
        model.handleQuit()
        NSApp.terminate(nil)
    }
}
