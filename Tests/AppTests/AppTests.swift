import Foundation

public enum AppTests {
    @MainActor
    public static func run(testRunner: @MainActor (String, @MainActor () throws -> Void) -> Void) {
        testRunner("AppConfig returns valid non-empty application name") {
            assert(!AppConfig.appName.isEmpty, "App name should not be empty")
        }

        testRunner("AppConfig returns valid bundle identifier") {
            assert(!AppConfig.bundleIdentifier.isEmpty, "Bundle identifier should not be empty")
            assert(AppConfig.bundleIdentifier.contains("."), "Bundle identifier should be reverse-DNS style")
        }

        testRunner("AppConfig provides version string") {
            assert(!AppConfig.version.isEmpty, "Version should not be empty")
        }

        testRunner("AppConfig provides build number") {
            assert(!AppConfig.buildNumber.isEmpty, "Build number should not be empty")
        }

        testRunner("StatusBarController initializes menu correctly") {
            let controller = StatusBarController()
            assert(controller.currentMenu.items.count >= 2, "Menu should have items")
            assert(controller.currentMenu.items.contains { $0.title.contains("Quit") }, "Menu should contain quit item")
            controller.teardown()
        }

        testRunner("ProcessInfoSleepAssertionManager acquires and releases assertion correctly") {
            let manager = ProcessInfoSleepAssertionManager()
            assert(!manager.isAssertionActive, "Initial state should be inactive")
            manager.acquireAssertion(preventLogout: true)
            assert(manager.isAssertionActive, "Assertion should be active after acquire")
            manager.acquireAssertion(preventLogout: false)
            assert(manager.isAssertionActive, "Assertion should remain active after reconfiguration")
            manager.acquireAssertion(preventLogout: false)
            assert(manager.isAssertionActive, "Assertion should remain active on redundant acquire")
            manager.releaseAssertion()
            assert(!manager.isAssertionActive, "Assertion should be inactive after release")
            manager.releaseAssertion()
            assert(!manager.isAssertionActive, "Assertion should remain inactive on redundant release")
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
            assert(!manager.isAssertionActive)
        }
    }
}

