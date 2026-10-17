import Foundation
import IOKit.pwr_mgt

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

    public init() {}

    deinit {
        releaseAssertion()
    }

    public var isAssertionActive: Bool {
        return activityToken != nil
    }

    public func acquireAssertion(preventLogout: Bool = true) {
        if activityToken != nil {
            if currentPreventLogout == preventLogout {
                // Already holding matching active assertion, reuse it
                return
            }
            // Configuration changed while active - release previous token and re-acquire
            releaseAssertion()
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
            startHeartbeat()
        } else {
            stopHeartbeat()
        }
    }

    public func releaseAssertion() {
        stopHeartbeat()
        if userActivityAssertionID != 0 {
            IOPMAssertionRelease(userActivityAssertionID)
            userActivityAssertionID = 0
        }
        guard let token = activityToken else { return }
        ProcessInfo.processInfo.endActivity(token)
        activityToken = nil
    }

    private func startHeartbeat() {
        stopHeartbeat()
        declareUserActivity()

        let timer = DispatchSource.makeTimerSource(queue: heartbeatQueue)
        timer.schedule(deadline: .now() + 30.0, repeating: 30.0)
        timer.setEventHandler { [weak self] in
            self?.declareUserActivity()
        }
        timer.resume()
        heartbeatTimer = timer
    }

    private func stopHeartbeat() {
        heartbeatTimer?.cancel()
        heartbeatTimer = nil
    }

    private func declareUserActivity() {
        _ = IOPMAssertionDeclareUserActivity(
            "StayOn User Active Heartbeat" as CFString,
            kIOPMUserActiveLocal,
            &userActivityAssertionID
        )
    }
}

