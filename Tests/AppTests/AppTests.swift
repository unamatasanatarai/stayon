import Foundation

public enum AppTests {
    @MainActor
    public static func run(testRunner: @MainActor (String, @MainActor () throws -> Void) -> Void) {
        testRunner("AppConfig returns valid non-empty application name") {
            try expect(!AppConfig.appName.isEmpty, "App name should not be empty")
        }

        testRunner("AppConfig returns valid bundle identifier") {
            try expect(!AppConfig.bundleIdentifier.isEmpty, "Bundle identifier should not be empty")
            try expect(AppConfig.bundleIdentifier.contains("."), "Bundle identifier should be reverse-DNS style")
        }

        testRunner("AppConfig provides version string") {
            try expect(!AppConfig.version.isEmpty, "Version should not be empty")
        }

        testRunner("AppConfig provides build number") {
            try expect(!AppConfig.buildNumber.isEmpty, "Build number should not be empty")
        }

        testRunner("StatusBarController initializes menu correctly") {
            let controller = StatusBarController()
            try expect(controller.currentMenu.items.count >= 2, "Menu should have items")
            try expect(controller.currentMenu.items.contains { $0.title.contains("Quit") }, "Menu should contain quit item")
            controller.teardown()
        }

        testRunner("ProcessInfoSleepAssertionManager acquires and releases assertion correctly") {
            let manager = ProcessInfoSleepAssertionManager()
            try expect(!manager.isAssertionActive, "Initial state should be inactive")
            manager.acquireAssertion(preventLogout: true)
            try expect(manager.isAssertionActive, "Assertion should be active after acquire")
            manager.acquireAssertion(preventLogout: false)
            try expect(manager.isAssertionActive, "Assertion should remain active after reconfiguration")
            manager.acquireAssertion(preventLogout: false)
            try expect(manager.isAssertionActive, "Assertion should remain active on redundant acquire")
            manager.releaseAssertion()
            try expect(!manager.isAssertionActive, "Assertion should be inactive after release")
            manager.releaseAssertion()
            try expect(!manager.isAssertionActive, "Assertion should remain inactive on redundant release")
        }

        testRunner("ProcessInfoSleepAssertionManager handles concurrent acquire and release safely") {
            let manager = ProcessInfoSleepAssertionManager()
            let group = DispatchGroup()
            let queue = DispatchQueue(label: "com.stayon.test.concurrent", attributes: .concurrent)

            for i in 0..<50 {
                group.enter()
                queue.async {
                    if i % 2 == 0 {
                        manager.acquireAssertion(preventLogout: i % 4 == 0)
                    } else {
                        manager.releaseAssertion()
                    }
                    group.leave()
                }
            }
            _ = group.wait(timeout: .now() + 5.0)
            manager.releaseAssertion()
            try expect(!manager.isAssertionActive)
        }
    }
}

