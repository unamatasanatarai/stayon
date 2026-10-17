import Foundation

public enum SleepState: Equatable {
    case inactive
    case activeIndefinite
    case activeTimed(deadline: Date)

    public var isActive: Bool {
        switch self {
        case .inactive:
            return false
        case .activeIndefinite, .activeTimed:
            return true
        }
    }

    public var isTimed: Bool {
        switch self {
        case .activeTimed:
            return true
        case .inactive, .activeIndefinite:
            return false
        }
    }

    public var deadline: Date? {
        switch self {
        case .activeTimed(let date):
            return date
        case .inactive, .activeIndefinite:
            return nil
        }
    }

    public func remainingSeconds(at date: Date = Date()) -> TimeInterval? {
        guard let deadline = deadline else { return nil }
        return max(0, deadline.timeIntervalSince(date))
    }

    public func statusText(at date: Date = Date()) -> String {
        switch self {
        case .inactive:
            return "Inactive"
        case .activeIndefinite:
            return "Active"
        case .activeTimed(let deadline):
            let remaining = deadline.timeIntervalSince(date)
            if remaining <= 0 {
                return "Inactive"
            }
            if remaining < 60 {
                return "Active \u{2014} Less than 1 minute left"
            }
            let minutes = Int(ceil(remaining / 60.0))
            if minutes == 1 {
                return "Active \u{2014} 1 minute left"
            }
            return "Active \u{2014} \(minutes) minutes left"
        }
    }
}
