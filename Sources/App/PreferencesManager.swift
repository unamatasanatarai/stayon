import Foundation

public protocol PreferencesManaging: AnyObject {
    var activateOnLaunch: Bool { get set }
    var preventLogout: Bool { get set }
}

public final class UserDefaultsPreferencesManager: PreferencesManaging {
    private let defaults: UserDefaults
    private let activateOnLaunchKey = "activateOnLaunch"
    private let preventLogoutKey = "preventLogout"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var activateOnLaunch: Bool {
        get {
            return defaults.bool(forKey: activateOnLaunchKey)
        }
        set {
            defaults.set(newValue, forKey: activateOnLaunchKey)
        }
    }

    public var preventLogout: Bool {
        get {
            if defaults.object(forKey: preventLogoutKey) == nil {
                return true
            }
            return defaults.bool(forKey: preventLogoutKey)
        }
        set {
            defaults.set(newValue, forKey: preventLogoutKey)
        }
    }
}
