import Foundation

public enum StayOnDuration: TimeInterval, CaseIterable, Equatable {
    case fiveMinutes = 300
    case tenMinutes = 600
    case fifteenMinutes = 900
    case thirtyMinutes = 1800
    case fortyFiveMinutes = 2700
    case oneHour = 3600
    case twoHours = 7200
    case fourHours = 14400

    public var title: String {
        switch self {
        case .fiveMinutes:
            return "Activate for 5 minutes"
        case .tenMinutes:
            return "Activate for 10 minutes"
        case .fifteenMinutes:
            return "Activate for 15 minutes"
        case .thirtyMinutes:
            return "Activate for 30 minutes"
        case .fortyFiveMinutes:
            return "Activate for 45 minutes"
        case .oneHour:
            return "Activate for 1 hour"
        case .twoHours:
            return "Activate for 2 hours"
        case .fourHours:
            return "Activate for 4 hours"
        }
    }
}
