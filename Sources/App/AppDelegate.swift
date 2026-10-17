import Cocoa

public final class AppDelegate: NSObject, NSApplicationDelegate {
    public private(set) var statusBarController: StatusBarController?
    public let model = StayOnModel()

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusBarController = StatusBarController(model: model)
        model.handleLaunch()
        statusBarController?.updateIcon()
        statusBarController?.updateMenuContent()
        NSLog("%@ started successfully.", AppConfig.appName)
    }

    public func applicationWillTerminate(_ notification: Notification) {
        model.handleQuit()
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
