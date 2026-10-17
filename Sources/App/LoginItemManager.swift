import Foundation
import ServiceManagement

public protocol LoginItemManaging: AnyObject {
    var isRegisteredAtLogin: Bool { get }
    func register() throws
    func unregister() throws
}

public final class SMAppServiceLoginItemManager: LoginItemManaging {
    public init() {}

    public var isRegisteredAtLogin: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    public func register() throws {
        if #available(macOS 13.0, *) {
            try SMAppService.mainApp.register()
        } else {
            _ = SMLoginItemSetEnabled(AppConfig.bundleIdentifier as CFString, true)
        }
    }

    public func unregister() throws {
        if #available(macOS 13.0, *) {
            try SMAppService.mainApp.unregister()
        } else {
            _ = SMLoginItemSetEnabled(AppConfig.bundleIdentifier as CFString, false)
        }
    }
}
