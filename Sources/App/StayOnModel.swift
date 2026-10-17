import Foundation

public protocol TimerScheduling: AnyObject {
    func schedule(after interval: TimeInterval, action: @escaping () -> Void) -> AnyObject
    func cancel(_ token: AnyObject)
}

public final class DispatchTimerScheduler: TimerScheduling {
    public init() {}

    public func schedule(after interval: TimeInterval, action: @escaping () -> Void) -> AnyObject {
        let item = DispatchWorkItem(block: action)
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: item)
        return item
    }

    public func cancel(_ token: AnyObject) {
        if let item = token as? DispatchWorkItem {
            item.cancel()
        }
    }
}

public final class StayOnModel {
    public private(set) var state: SleepState = .inactive {
        didSet {
            onStateChange?(state)
        }
    }

    public var onStateChange: ((SleepState) -> Void)?

    public let assertionManager: SleepAssertionManaging
    public let preferences: PreferencesManaging
    public let loginItemManager: LoginItemManaging
    public let timerScheduler: TimerScheduling

    private var activeTimerToken: AnyObject?

    public init(
        assertionManager: SleepAssertionManaging = ProcessInfoSleepAssertionManager(),
        preferences: PreferencesManaging = UserDefaultsPreferencesManager(),
        loginItemManager: LoginItemManaging = SMAppServiceLoginItemManager(),
        timerScheduler: TimerScheduling = DispatchTimerScheduler()
    ) {
        self.assertionManager = assertionManager
        self.preferences = preferences
        self.loginItemManager = loginItemManager
        self.timerScheduler = timerScheduler
    }

    public func handleLaunch() {
        if loginItemManager.isRegisteredAtLogin {
            preferences.startAtLogin = true
        }

        if preferences.activateOnLaunch {
            activateIndefinitely()
        } else {
            deactivate()
        }
    }

    public func toggleLeftClick() {
        if state.isActive {
            deactivate()
        } else {
            activateIndefinitely()
        }
    }

    public func activateIndefinitely() {
        cancelExistingTimer()
        assertionManager.acquireAssertion()
        state = .activeIndefinite
    }

    public func activateTimed(duration: StayOnDuration, from now: Date = Date()) {
        activateTimed(seconds: duration.rawValue, from: now)
    }

    public func activateTimed(seconds: TimeInterval, from now: Date = Date()) {
        cancelExistingTimer()
        assertionManager.acquireAssertion()

        let deadline = now.addingTimeInterval(seconds)
        state = .activeTimed(deadline: deadline)

        activeTimerToken = timerScheduler.schedule(after: seconds) { [weak self] in
            self?.handleTimerExpiration()
        }
    }

    public func deactivate() {
        cancelExistingTimer()
        assertionManager.releaseAssertion()
        state = .inactive
    }

    public func checkExpiration(at date: Date = Date()) {
        guard case .activeTimed(let deadline) = state else { return }
        if date >= deadline {
            handleTimerExpiration()
        }
    }

    public func statusText(at date: Date = Date()) -> String {
        checkExpiration(at: date)
        return state.statusText(at: date)
    }

    public var isStartAtLoginEnabled: Bool {
        return preferences.startAtLogin || loginItemManager.isRegisteredAtLogin
    }

    public func setStartAtLogin(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try loginItemManager.register()
            } else {
                try loginItemManager.unregister()
            }
            preferences.startAtLogin = enabled
            return true
        } catch {
            NSLog("Failed to set startAtLogin to %@: %@", enabled ? "true" : "false", error.localizedDescription)
            return false
        }
    }

    public var isActivateOnLaunchEnabled: Bool {
        return preferences.activateOnLaunch
    }

    public func setActivateOnLaunch(_ enabled: Bool) {
        preferences.activateOnLaunch = enabled
    }

    public func handleQuit() {
        deactivate()
    }

    private func cancelExistingTimer() {
        if let token = activeTimerToken {
            timerScheduler.cancel(token)
            activeTimerToken = nil
        }
    }

    private func handleTimerExpiration() {
        cancelExistingTimer()
        assertionManager.releaseAssertion()
        state = .inactive
    }
}
