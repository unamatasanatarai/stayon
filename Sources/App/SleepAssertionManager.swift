import Foundation
import IOKit.pwr_mgt
import os

public protocol SleepAssertionManaging: AnyObject {
    var isAssertionActive: Bool { get }
    func acquireAssertion(preventLogout: Bool)
    func releaseAssertion()
}

public extension SleepAssertionManaging {
    func acquireAssertion() {
        acquireAssertion(preventLogout: true)
    }
}


public final class ProcessInfoSleepAssertionManager: SleepAssertionManaging {
    private var activityToken: NSObjectProtocol?
    private var userActivityAssertionID: IOPMAssertionID = 0
    private var heartbeatTimer: DispatchSourceTimer?
    private let heartbeatQueue = DispatchQueue(label: "com.stayon.heartbeat", qos: .utility)
    private var currentPreventLogout: Bool = false
    private var lock = os_unfair_lock_s()

    public init() {}

    deinit {
        releaseAssertion()
    }

    public var isAssertionActive: Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return activityToken != nil
    }

    public func acquireAssertion(preventLogout: Bool = true) {
        os_unfair_lock_lock(&lock)
        if activityToken != nil {
            if currentPreventLogout == preventLogout {
                os_unfair_lock_unlock(&lock)
                return
            }
            // Configuration changed while active - internal release before re-acquiring
            internalReleaseAssertion()
        }

        currentPreventLogout = preventLogout
        let options: ProcessInfo.ActivityOptions = preventLogout
            ? [.idleSystemSleepDisabled, .idleDisplaySleepDisabled]
            : .idleSystemSleepDisabled

        let reason = preventLogout
            ? "StayOn preventing idle system and display sleep"
            : "StayOn preventing idle system sleep"

        activityToken = ProcessInfo.processInfo.beginActivity(
            options: options,
            reason: reason
        )

        if preventLogout {
            internalStartHeartbeat()
        } else {
            internalStopHeartbeat()
        }
        os_unfair_lock_unlock(&lock)
    }

    public func releaseAssertion() {
        os_unfair_lock_lock(&lock)
        internalReleaseAssertion()
        os_unfair_lock_unlock(&lock)
    }

    // Must be called with lock held
    private func internalReleaseAssertion() {
        internalStopHeartbeat()
        if userActivityAssertionID != 0 {
            IOPMAssertionRelease(userActivityAssertionID)
            userActivityAssertionID = 0
        }
        if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
            activityToken = nil
        }
    }

    // Must be called with lock held
    private func internalStartHeartbeat() {
        internalStopHeartbeat()
        internalDeclareUserActivity()

        let timer = DispatchSource.makeTimerSource(queue: heartbeatQueue)
        timer.schedule(deadline: .now() + 30.0, repeating: 30.0)
        timer.setEventHandler { [weak self] in
            self?.performHeartbeat()
        }
        timer.resume()
        heartbeatTimer = timer
    }

    // Must be called with lock held
    private func internalStopHeartbeat() {
        heartbeatTimer?.cancel()
        heartbeatTimer = nil
    }

    private func performHeartbeat() {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        guard activityToken != nil, currentPreventLogout else { return }
        internalDeclareUserActivity()
    }

    // Must be called with lock held
    private func internalDeclareUserActivity() {
        _ = IOPMAssertionDeclareUserActivity(
            "StayOn User Active Heartbeat" as CFString,
            kIOPMUserActiveLocal,
            &userActivityAssertionID
        )
    }
}


