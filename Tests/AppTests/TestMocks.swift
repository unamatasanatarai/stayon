import Foundation

public final class MockSleepAssertionManager: SleepAssertionManaging {
    public var acquireCount: Int = 0
    public var releaseCount: Int = 0
    public var isAssertionActive: Bool = false
    public var lastPreventLogout: Bool?

    public init() {}

    public func acquireAssertion(preventLogout: Bool = true) {
        lastPreventLogout = preventLogout
        guard !isAssertionActive else { return }
        isAssertionActive = true
        acquireCount += 1
    }

    public func releaseAssertion() {
        guard isAssertionActive else { return }
        isAssertionActive = false
        releaseCount += 1
    }
}

public final class MockPreferencesManager: PreferencesManaging {
    public var activateOnLaunch: Bool = false
    public var preventLogout: Bool = true

    public init(activateOnLaunch: Bool = false, preventLogout: Bool = true) {
        self.activateOnLaunch = activateOnLaunch
        self.preventLogout = preventLogout
    }
}

public final class MockLoginItemManager: LoginItemManaging {
    public var isRegisteredAtLogin: Bool = false
    public var shouldThrowOnRegister: Bool = false
    public var shouldThrowOnUnregister: Bool = false
    public var refreshCount: Int = 0

    public init(isRegisteredAtLogin: Bool = false) {
        self.isRegisteredAtLogin = isRegisteredAtLogin
    }

    public func register() throws {
        if shouldThrowOnRegister {
            throw NSError(domain: "MockLoginItemError", code: 1, userInfo: nil)
        }
        isRegisteredAtLogin = true
    }

    public func unregister() throws {
        if shouldThrowOnUnregister {
            throw NSError(domain: "MockLoginItemError", code: 2, userInfo: nil)
        }
        isRegisteredAtLogin = false
    }

    public func refreshRegistration() {
        refreshCount += 1
    }
}

public final class MockTimerToken {
    public let interval: TimeInterval
    public let action: () -> Void
    public var isCancelled: Bool = false

    public init(interval: TimeInterval, action: @escaping () -> Void) {
        self.interval = interval
        self.action = action
    }

    public func fire() {
        if !isCancelled {
            action()
        }
    }
}

public final class MockTimerScheduler: TimerScheduling {
    public var scheduledTimers: [MockTimerToken] = []
    public var cancelledTimers: [MockTimerToken] = []

    public init() {}

    public func schedule(after interval: TimeInterval, action: @escaping () -> Void) -> AnyObject {
        let token = MockTimerToken(interval: interval, action: action)
        scheduledTimers.append(token)
        return token
    }

    public func cancel(_ token: AnyObject) {
        if let mockToken = token as? MockTimerToken {
            mockToken.isCancelled = true
            cancelledTimers.append(mockToken)
        }
    }

    public func fireLastTimer() {
        scheduledTimers.last?.fire()
    }
}
