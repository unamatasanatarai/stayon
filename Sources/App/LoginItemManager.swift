import Foundation
import ServiceManagement

public protocol LoginItemManaging: AnyObject {
    var isRegisteredAtLogin: Bool { get }
    func register() throws
    func unregister() throws
}

public final class SMAppServiceLoginItemManager: LoginItemManaging {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public var isRegisteredAtLogin: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return fileManager.fileExists(atPath: launchAgentURL.path)
    }

    public func register() throws {
        if #available(macOS 13.0, *) {
            try SMAppService.mainApp.register()
        } else {
            try writeLaunchAgent()
        }
    }

    public func unregister() throws {
        if #available(macOS 13.0, *) {
            try SMAppService.mainApp.unregister()
        } else if fileManager.fileExists(atPath: launchAgentURL.path) {
            try fileManager.removeItem(at: launchAgentURL)
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

    private func writeLaunchAgent() throws {
        let plist: [String: Any] = [
            "Label": AppConfig.bundleIdentifier,
            "ProgramArguments": ["/usr/bin/open", Bundle.main.bundlePath],
            "RunAtLoad": true,
            "ProcessType": "Interactive"
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try fileManager.createDirectory(
            at: launchAgentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: launchAgentURL, options: .atomic)
    }
}
