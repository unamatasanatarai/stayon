import Foundation

public enum AppConfig {
    public static let appName = "StayOn"
    public static let bundleIdentifier = "com.stayon.app"
    
    public static var version: String {
        guard let url = Bundle.main.url(forResource: "VERSION", withExtension: nil),
              let versionStr = try? String(contentsOf: url, encoding: .utf8) else {
            return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        }
        return versionStr.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public static var buildNumber: String {
        guard let url = Bundle.main.url(forResource: "BUILD_NUMBER", withExtension: nil),
              let buildStr = try? String(contentsOf: url, encoding: .utf8) else {
            return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        }
        return buildStr.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
