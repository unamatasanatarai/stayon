import Foundation

public protocol TimerScheduling: AnyObject {
    func schedule(after interval: TimeInterval, action: @escaping () -> Void) -> AnyObject
    func cancel(_ token: AnyObject)
}

public final class DispatchTimerScheduler: TimerScheduling {
    public init() {}

    public func schedule(after interval: TimeInterval, action: @escaping () -> Void) -> AnyObject {
        let item = DispatchWorkItem(block: action)
        // Wall-clock deadline keeps counting while the Mac sleeps; a monotonic
        // DispatchTime would fire late by the time spent asleep.
        DispatchQueue.main.asyncAfter(wallDeadline: .now() + interval, execute: item)
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
        // Login-item state lives in the system; isStartAtLoginEnabled reads it directly.
        loginItemManager.refreshRegistration()

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
        assertionManager.acquireAssertion(preventLogout: preferences.preventLogout)
        state = .activeIndefinite
    }

    public func activateTimed(duration: StayOnDuration, from now: Date = Date()) {
        activateTimed(seconds: duration.rawValue, from: now)
    }

    public func activateTimed(seconds: TimeInterval, from now: Date = Date()) {
        cancelExistingTimer()
        assertionManager.acquireAssertion(preventLogout: preferences.preventLogout)

        let deadline = now.addingTimeInterval(seconds)
        state = .activeTimed(deadline: deadline)
        scheduleExpiration(after: seconds)
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

    /// Call after wake or a system clock change: expires a passed deadline, or
    /// re-arms the expiration timer for the remaining wall-clock time.
    public func handleSystemTimeChange(at date: Date = Date()) {
        guard case .activeTimed(let deadline) = state else { return }
        let remaining = deadline.timeIntervalSince(date)
        if remaining <= 0 {
            handleTimerExpiration()
        } else {
            cancelExistingTimer()
            scheduleExpiration(after: remaining)
        }
    }

    public func statusText(at date: Date = Date()) -> String {
        checkExpiration(at: date)
        return state.statusText(at: date)
    }

    public var isStartAtLoginEnabled: Bool {
        return loginItemManager.isRegisteredAtLogin
    }

    public func setStartAtLogin(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try loginItemManager.register()
            } else {
                try loginItemManager.unregister()
            }
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

    public var isPreventLogoutEnabled: Bool {
        return preferences.preventLogout
    }

    public func setPreventLogout(_ enabled: Bool) {
        preferences.preventLogout = enabled
        if state.isActive {
            assertionManager.acquireAssertion(preventLogout: enabled)
        }
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

    private func scheduleExpiration(after seconds: TimeInterval) {
        activeTimerToken = timerScheduler.schedule(after: seconds) { [weak self] in
            self?.handleTimerExpiration()
        }
    }

    private func handleTimerExpiration() {
        cancelExistingTimer()
        assertionManager.releaseAssertion()
        state = .inactive
    }
}
