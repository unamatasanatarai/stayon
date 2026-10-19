import Foundation
import ServiceManagement

public protocol LoginItemManaging: AnyObject {
    var isRegisteredAtLogin: Bool { get }
    func register() throws
    func unregister() throws
    /// Repairs an existing registration (e.g. after the app bundle moved).
    func refreshRegistration()
}

public extension LoginItemManaging {
    func refreshRegistration() {}
}

public final class SMAppServiceLoginItemManager: LoginItemManaging {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public var isRegisteredAtLogin: Bool {
        if #available(macOS 13.0, *) {
            // A LaunchAgent left over from running on macOS 12 still launches the app.
            return SMAppService.mainApp.status == .enabled || hasLaunchAgent
        }
        return hasLaunchAgent
    }

    public func register() throws {
        if #available(macOS 13.0, *) {
            try SMAppService.mainApp.register()
            try removeLaunchAgent()
            if SMAppService.mainApp.status == .requiresApproval {
                // Registration is pending until the user allows it; send them there
                // rather than leaving the toggle silently unchecked.
                SMAppService.openSystemSettingsLoginItems()
            }
        } else {
            try writeLaunchAgent()
        }
    }

    public func unregister() throws {
        if #available(macOS 13.0, *) {
            if SMAppService.mainApp.status != .notRegistered {
                try SMAppService.mainApp.unregister()
            }
        }
        try removeLaunchAgent()
    }

    public func refreshRegistration() {
        if #available(macOS 13.0, *) { return }
        guard hasLaunchAgent else { return }
        do {
            try writeLaunchAgent()
        } catch {
            NSLog("Failed to refresh login LaunchAgent: %@", error.localizedDescription)
        }
    }

    // MARK: - macOS 12 fallback

    // SMLoginItemSetEnabled only works with an embedded helper bundle, so on
    // macOS 12 we install a per-user LaunchAgent that opens the app at login.
    private var launchAgentURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(AppConfig.bundleIdentifier).plist")
    }

    private var hasLaunchAgent: Bool {
        fileManager.fileExists(atPath: launchAgentURL.path)
    }

    private func writeLaunchAgent() throws {
        let plist: [String: Any] = [
            "Label": AppConfig.bundleIdentifier,
            "ProgramArguments": ["/usr/bin/open", Bundle.main.bundlePath],
            "RunAtLoad": true,
            "ProcessType": "Interactive"
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        if let existing = try? Data(contentsOf: launchAgentURL), existing == data { return }
        try fileManager.createDirectory(
            at: launchAgentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: launchAgentURL, options: .atomic)
    }

    private func removeLaunchAgent() throws {
        if hasLaunchAgent {
            try fileManager.removeItem(at: launchAgentURL)
        }
    }
}
