import Foundation

public protocol SleepAssertionManaging: AnyObject {
    var isAssertionActive: Bool { get }
    func acquireAssertion()
    func releaseAssertion()
}

public final class ProcessInfoSleepAssertionManager: SleepAssertionManaging {
    private var activityToken: NSObjectProtocol?

    public init() {}

    deinit {
        releaseAssertion()
    }

    public var isAssertionActive: Bool {
        return activityToken != nil
    }

    public func acquireAssertion() {
        guard activityToken == nil else {
            // Already holding exactly one active assertion, reuse it
            return
        }
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: .idleSystemSleepDisabled,
            reason: "StayOn preventing idle system sleep"
        )
    }

    public func releaseAssertion() {
        guard let token = activityToken else { return }
        ProcessInfo.processInfo.endActivity(token)
        activityToken = nil
    }
}
