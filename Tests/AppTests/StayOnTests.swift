import Foundation
import AppKit

public enum StayOnTests {
    @MainActor
    public static func run(testRunner: @MainActor (String, @MainActor () throws -> Void) -> Void) {
        // MARK: - Duration & Formatting Suite
        testRunner("Duration definitions match spec exactly") {
            try expect(StayOnDuration.allCases.count == 8, "Must have exactly 8 predefined durations")
            try expect(StayOnDuration.fiveMinutes.rawValue == 300, "5 minutes = 300s")
            try expect(StayOnDuration.tenMinutes.rawValue == 600, "10 minutes = 600s")
            try expect(StayOnDuration.fifteenMinutes.rawValue == 900, "15 minutes = 900s")
            try expect(StayOnDuration.thirtyMinutes.rawValue == 1800, "30 minutes = 1800s")
            try expect(StayOnDuration.fortyFiveMinutes.rawValue == 2700, "45 minutes = 2700s")
            try expect(StayOnDuration.oneHour.rawValue == 3600, "1 hour = 3600s")
            try expect(StayOnDuration.twoHours.rawValue == 7200, "2 hours = 7200s")
            try expect(StayOnDuration.fourHours.rawValue == 14400, "4 hours = 14400s")

            try expect(StayOnDuration.fiveMinutes.title == "Activate for 5 minutes")
            try expect(StayOnDuration.oneHour.title == "Activate for 1 hour")
            try expect(StayOnDuration.fourHours.title == "Activate for 4 hours")
        }

        testRunner("Status text formatting conforms to spec table") {
            let baseDate = Date(timeIntervalSince1970: 1000000)

            // Inactive
            try expect(SleepState.inactive.statusText(at: baseDate) == "Inactive")

            // Active Indefinite
            try expect(SleepState.activeIndefinite.statusText(at: baseDate) == "Active")

            // Active with 23 minutes left
            let deadline23m = baseDate.addingTimeInterval(23 * 60)
            try expect(SleepState.activeTimed(deadline: deadline23m).statusText(at: baseDate) == "Active \u{2014} 23 minutes left")

            // Active with 5 minutes left
            let deadline5m = baseDate.addingTimeInterval(300)
            try expect(SleepState.activeTimed(deadline: deadline5m).statusText(at: baseDate) == "Active \u{2014} 5 minutes left")

            // Active with 65 seconds left (rounds up to 2 minutes)
            let deadline65s = baseDate.addingTimeInterval(65)
            try expect(SleepState.activeTimed(deadline: deadline65s).statusText(at: baseDate) == "Active \u{2014} 2 minutes left")

            // Active with exactly 60 seconds left (1 minute left)
            let deadline60s = baseDate.addingTimeInterval(60)
            try expect(SleepState.activeTimed(deadline: deadline60s).statusText(at: baseDate) == "Active \u{2014} 1 minute left")

            // Less than one minute remaining
            let deadline59s = baseDate.addingTimeInterval(59)
            try expect(SleepState.activeTimed(deadline: deadline59s).statusText(at: baseDate) == "Active \u{2014} Less than 1 minute left")

            let deadline1s = baseDate.addingTimeInterval(1)
            try expect(SleepState.activeTimed(deadline: deadline1s).statusText(at: baseDate) == "Active \u{2014} Less than 1 minute left")

            // Expired (0 or negative)
            let deadline0s = baseDate
            try expect(SleepState.activeTimed(deadline: deadline0s).statusText(at: baseDate) == "Inactive")

            let deadlinePast = baseDate.addingTimeInterval(-10)
            try expect(SleepState.activeTimed(deadline: deadlinePast).statusText(at: baseDate) == "Inactive")
        }

        // MARK: - State Transitions Suite
        testRunner("State transition: Inactive -> Indefinite on left-click") {
            let assertion = MockSleepAssertionManager()
            let model = StayOnModel(assertionManager: assertion)

            try expect(model.state == .inactive)
            try expect(!assertion.isAssertionActive)

            model.toggleLeftClick()

            try expect(model.state == .activeIndefinite)
            try expect(model.state.isActive)
            try expect(!model.state.isTimed)
            try expect(assertion.isAssertionActive)
            try expect(assertion.acquireCount == 1)
        }

        testRunner("State transition: Indefinite -> Inactive on left-click") {
            let assertion = MockSleepAssertionManager()
            let model = StayOnModel(assertionManager: assertion)
            model.activateIndefinitely()

            model.toggleLeftClick()

            try expect(model.state == .inactive)
            try expect(!assertion.isAssertionActive)
            try expect(assertion.releaseCount == 1)
        }

        testRunner("State transition: Timed -> Inactive on left-click") {
            let assertion = MockSleepAssertionManager()
            let timer = MockTimerScheduler()
            let model = StayOnModel(assertionManager: assertion, timerScheduler: timer)

            model.activateTimed(duration: .fifteenMinutes)
            try expect(model.state.isActive && model.state.isTimed)
            try expect(timer.scheduledTimers.count == 1)

            model.toggleLeftClick()

            try expect(model.state == .inactive)
            try expect(!assertion.isAssertionActive)
            try expect(timer.cancelledTimers.count == 1)
        }

        testRunner("State transition: Inactive -> Timed") {
            let assertion = MockSleepAssertionManager()
            let timer = MockTimerScheduler()
            let model = StayOnModel(assertionManager: assertion, timerScheduler: timer)

            let now = Date()
            model.activateTimed(duration: .thirtyMinutes, from: now)

            try expect(model.state.isActive)
            try expect(model.state.isTimed)
            try expect(assertion.isAssertionActive)
            try expect(timer.scheduledTimers.count == 1)
            try expect(timer.scheduledTimers[0].interval == 1800)

            if case .activeTimed(let deadline) = model.state {
                try expect(abs(deadline.timeIntervalSince(now) - 1800) < 0.01)
            } else {
                throw TestFailure("Expected activeTimed state")
            }
        }

        testRunner("State transition: Indefinite -> Timed reuses assertion") {
            let assertion = MockSleepAssertionManager()
            let timer = MockTimerScheduler()
            let model = StayOnModel(assertionManager: assertion, timerScheduler: timer)

            model.activateIndefinitely()
            try expect(assertion.acquireCount == 1)

            model.activateTimed(duration: .oneHour)
            try expect(model.state.isTimed)
            // Exactly one active assertion held and reused
            try expect(assertion.isAssertionActive)
            try expect(assertion.acquireCount == 1)
            try expect(assertion.releaseCount == 0)
        }

        testRunner("State transition: Timed -> Timed replaces deadline and resets timer") {
            let assertion = MockSleepAssertionManager()
            let timer = MockTimerScheduler()
            let model = StayOnModel(assertionManager: assertion, timerScheduler: timer)

            let now = Date()
            model.activateTimed(duration: .fiveMinutes, from: now)
            try expect(timer.scheduledTimers.count == 1)

            // Replace with 2 hours
            model.activateTimed(duration: .twoHours, from: now)
            try expect(timer.scheduledTimers.count == 2)
            try expect(timer.cancelledTimers.count == 1)
            try expect(timer.cancelledTimers[0] === timer.scheduledTimers[0])

            // Assertion remains continuously active
            try expect(assertion.isAssertionActive)
            try expect(assertion.acquireCount == 1)
            try expect(assertion.releaseCount == 0)

            if case .activeTimed(let deadline) = model.state {
                try expect(abs(deadline.timeIntervalSince(now) - 7200) < 0.01)
            } else {
                throw TestFailure("Expected activeTimed state")
            }
        }

        testRunner("State transition: Timed -> Inactive when timer expires") {
            let assertion = MockSleepAssertionManager()
            let timer = MockTimerScheduler()
            let model = StayOnModel(assertionManager: assertion, timerScheduler: timer)

            model.activateTimed(duration: .fiveMinutes)
            try expect(model.state.isActive)
            try expect(assertion.isAssertionActive)

            // Simulate timer firing
            timer.fireLastTimer()

            try expect(model.state == .inactive)
            try expect(!assertion.isAssertionActive)
            try expect(assertion.releaseCount == 1)
        }

        testRunner("checkExpiration automatically deactivates if past deadline") {
            let assertion = MockSleepAssertionManager()
            let timer = MockTimerScheduler()
            let model = StayOnModel(assertionManager: assertion, timerScheduler: timer)

            let startTime = Date(timeIntervalSince1970: 1000)
            model.activateTimed(seconds: 300, from: startTime)
            try expect(model.state.isActive)

            // Check before deadline
            model.checkExpiration(at: Date(timeIntervalSince1970: 1200))
            try expect(model.state.isActive)

            // Check after deadline
            model.checkExpiration(at: Date(timeIntervalSince1970: 1301))
            try expect(model.state == .inactive)
            try expect(!assertion.isAssertionActive)
        }

        testRunner("Wake before deadline reschedules expiration for the remaining wall-clock time") {
            let assertion = MockSleepAssertionManager()
            let timer = MockTimerScheduler()
            let model = StayOnModel(assertionManager: assertion, timerScheduler: timer)

            let startTime = Date(timeIntervalSince1970: 1000)
            model.activateTimed(seconds: 3600, from: startTime)
            let original = timer.scheduledTimers.last!

            // System slept for part of the window; the monotonic timer is now late.
            model.handleSystemTimeChange(at: Date(timeIntervalSince1970: 1000 + 1800))

            try expect(model.state == .activeTimed(deadline: Date(timeIntervalSince1970: 4600)), "Deadline must be preserved")
            try expect(original.isCancelled, "Stale timer must be cancelled")
            try expect(timer.scheduledTimers.count == 2, "A replacement timer must be scheduled")
            try expect(timer.scheduledTimers.last!.interval == 1800, "Replacement must fire at the original deadline")

            timer.fireLastTimer()
            try expect(model.state == .inactive)
            try expect(!assertion.isAssertionActive)
        }

        testRunner("Wake after deadline expires immediately") {
            let assertion = MockSleepAssertionManager()
            let timer = MockTimerScheduler()
            let model = StayOnModel(assertionManager: assertion, timerScheduler: timer)

            model.activateTimed(seconds: 300, from: Date(timeIntervalSince1970: 1000))
            model.handleSystemTimeChange(at: Date(timeIntervalSince1970: 5000))

            try expect(model.state == .inactive)
            try expect(!assertion.isAssertionActive)
            try expect(timer.scheduledTimers.count == 1, "No timer may be rescheduled after expiry")
        }

        testRunner("Wake while indefinite or inactive does not schedule timers") {
            let assertion = MockSleepAssertionManager()
            let timer = MockTimerScheduler()
            let model = StayOnModel(assertionManager: assertion, timerScheduler: timer)

            model.handleSystemTimeChange(at: Date())
            try expect(model.state == .inactive)
            model.activateIndefinitely()
            model.handleSystemTimeChange(at: Date())
            try expect(model.state == .activeIndefinite)
            try expect(timer.scheduledTimers.isEmpty)
        }

        testRunner("handleQuit deactivates and releases assertion immediately") {
            let assertion = MockSleepAssertionManager()
            let timer = MockTimerScheduler()
            let model = StayOnModel(assertionManager: assertion, timerScheduler: timer)

            model.activateTimed(duration: .tenMinutes)
            try expect(assertion.isAssertionActive)

            model.handleQuit()

            try expect(model.state == .inactive)
            try expect(!assertion.isAssertionActive)
            try expect(assertion.releaseCount == 1)
            try expect(timer.cancelledTimers.count == 1)
        }

        // MARK: - Preferences & Launch Suite
        testRunner("Launch behavior: activateOnLaunch disabled starts inactive") {
            let assertion = MockSleepAssertionManager()
            let prefs = MockPreferencesManager(activateOnLaunch: false)
            let loginItem = MockLoginItemManager(isRegisteredAtLogin: false)
            let model = StayOnModel(assertionManager: assertion, preferences: prefs, loginItemManager: loginItem)

            model.handleLaunch()

            try expect(model.state == .inactive)
            try expect(!assertion.isAssertionActive)
        }

        testRunner("Launch behavior: activateOnLaunch enabled activates indefinitely") {
            let assertion = MockSleepAssertionManager()
            let prefs = MockPreferencesManager(activateOnLaunch: true)
            let loginItem = MockLoginItemManager(isRegisteredAtLogin: false)
            let model = StayOnModel(assertionManager: assertion, preferences: prefs, loginItemManager: loginItem)

            model.handleLaunch()

            try expect(model.state == .activeIndefinite)
            try expect(assertion.isAssertionActive)
            try expect(assertion.acquireCount == 1)
        }

        testRunner("Launch reflects system login item registration") {
            let prefs = MockPreferencesManager()
            let loginItem = MockLoginItemManager(isRegisteredAtLogin: true)
            let model = StayOnModel(preferences: prefs, loginItemManager: loginItem)

            model.handleLaunch()

            try expect(model.isStartAtLoginEnabled == true, "Should reflect system login item state")
            try expect(loginItem.refreshCount == 1, "Launch must repair an existing login registration")
        }

        testRunner("setStartAtLogin updates system registration") {
            let prefs = MockPreferencesManager()
            let loginItem = MockLoginItemManager(isRegisteredAtLogin: false)
            let model = StayOnModel(preferences: prefs, loginItemManager: loginItem)

            let success = model.setStartAtLogin(true)
            try expect(success)
            try expect(loginItem.isRegisteredAtLogin == true)
            try expect(model.isStartAtLoginEnabled == true)

            let unregSuccess = model.setStartAtLogin(false)
            try expect(unregSuccess)
            try expect(loginItem.isRegisteredAtLogin == false)
            try expect(model.isStartAtLoginEnabled == false)
        }

        testRunner("setStartAtLogin handles errors gracefully") {
            let prefs = MockPreferencesManager()
            let loginItem = MockLoginItemManager(isRegisteredAtLogin: false)
            loginItem.shouldThrowOnRegister = true
            let model = StayOnModel(preferences: prefs, loginItemManager: loginItem)

            let success = model.setStartAtLogin(true)
            try expect(!success)
            try expect(model.isStartAtLoginEnabled == false, "Failed registration must not show as enabled")
        }

        testRunner("setActivateOnLaunch persists preference") {
            let prefs = MockPreferencesManager(activateOnLaunch: false)
            let model = StayOnModel(preferences: prefs)

            model.setActivateOnLaunch(true)
            try expect(prefs.activateOnLaunch == true)

            model.setActivateOnLaunch(false)
            try expect(prefs.activateOnLaunch == false)
        }

        testRunner("setPreventLogout persists preference and updates active assertion") {
            let prefs = MockPreferencesManager(preventLogout: true)
            let assertion = MockSleepAssertionManager()
            let model = StayOnModel(assertionManager: assertion, preferences: prefs)

            model.setPreventLogout(false)
            try expect(prefs.preventLogout == false)
            try expect(assertion.lastPreventLogout == nil)

            model.activateIndefinitely()
            try expect(assertion.lastPreventLogout == false)

            model.setPreventLogout(true)
            try expect(prefs.preventLogout == true)
            try expect(assertion.lastPreventLogout == true)
        }

        // MARK: - UI & Menu Specification Suite
        testRunner("Menu layout matches exact spec order and structure") {
            let model = StayOnModel()
            let controller = StatusBarController(model: model)
            let menu = controller.currentMenu

            // Order of items:
            // 0: Dynamic status item
            // 1: Separator
            // 2..9: 8 Duration items
            // 10: Separator
            // 11: Start at Login
            // 12: Activate on Launch
            // 13: Prevent Logout
            // 14: Separator
            // 15: Quit StayOn
            try expect(menu.items.count == 16, "Menu must have exactly 16 items including separators")

            // Status item
            try expect(menu.items[0] === controller.statusMenuItem)
            try expect(menu.items[0].isEnabled == false, "Status item must be disabled/informational per spec")
            try expect(menu.items[0].title == "Inactive")

            // Separator 1
            try expect(menu.items[1].isSeparatorItem)

            // Duration items
            try expect(controller.durationMenuItems.count == 8)
            for (idx, duration) in StayOnDuration.allCases.enumerated() {
                let menuItem = menu.items[2 + idx]
                try expect(menuItem === controller.durationMenuItems[idx])
                try expect(menuItem.title == duration.title)
                try expect(menuItem.tag == Int(duration.rawValue))
                try expect(menuItem.isEnabled == true)
            }

            // Separator 2
            try expect(menu.items[10].isSeparatorItem)

            // Preferences items
            try expect(menu.items[11] === controller.startAtLoginMenuItem)
            try expect(menu.items[11].title == "Start at Login")
            try expect(controller.startAtLoginMenuItem.onStateImage != nil, "Must have checked box image")
            try expect(controller.startAtLoginMenuItem.offStateImage != nil, "Must have unchecked box image")

            try expect(menu.items[12] === controller.activateOnLaunchMenuItem)
            try expect(menu.items[12].title == "Activate on Launch")
            try expect(controller.activateOnLaunchMenuItem.onStateImage != nil, "Must have checked box image")
            try expect(controller.activateOnLaunchMenuItem.offStateImage != nil, "Must have unchecked box image")

            try expect(menu.items[13] === controller.preventLogoutMenuItem)
            try expect(menu.items[13].title == "Prevent Logout")
            try expect(controller.preventLogoutMenuItem.onStateImage != nil, "Must have checked box image")
            try expect(controller.preventLogoutMenuItem.offStateImage != nil, "Must have unchecked box image")

            // Separator 3
            try expect(menu.items[14].isSeparatorItem)

            // Quit item
            try expect(menu.items[15] === controller.quitMenuItem)
            try expect(menu.items[15].title == "Quit StayOn")
            try expect(menu.items[15].keyEquivalent == "q")
            try expect(menu.items[15].keyEquivalentModifierMask == [.command])

            controller.teardown()
        }

        testRunner("Status bar icon provides distinct active and inactive images for light and dark modes") {
            let activeDark = StatusBarIcon.image(isActive: true, isDark: true)
            let activeLight = StatusBarIcon.image(isActive: true, isDark: false)
            let inactiveDark = StatusBarIcon.image(isActive: false, isDark: true)
            let inactiveLight = StatusBarIcon.image(isActive: false, isDark: false)

            try expect(activeDark.size.width == 18 && activeDark.size.height == 18)
            try expect(activeLight.size.width == 18 && activeLight.size.height == 18)
            try expect(inactiveDark.size.width == 18 && inactiveDark.size.height == 18)
            try expect(inactiveLight.size.width == 18 && inactiveLight.size.height == 18)

            try expect(activeDark.isTemplate == false, "Must preserve custom two-tone appearance")
            try expect(activeLight.isTemplate == false, "Must preserve custom two-tone appearance")

            let whiteColor = StatusBarIcon.iconWhiteColor
            let expected = CGFloat(0xe9) / 255.0
            try expect(abs(whiteColor.redComponent - expected) < 0.001, "White color red component must match #e9e9e9")
            try expect(abs(whiteColor.greenComponent - expected) < 0.001, "White color green component must match #e9e9e9")
            try expect(abs(whiteColor.blueComponent - expected) < 0.001, "White color blue component must match #e9e9e9")

            let blackColor = StatusBarIcon.iconBlackColor
            let expectedBlack = CGFloat(0x20) / 255.0
            try expect(abs(blackColor.redComponent - expectedBlack) < 0.001, "Black color red component must match #202020")
            try expect(abs(blackColor.greenComponent - expectedBlack) < 0.001, "Black color green component must match #202020")
            try expect(abs(blackColor.blueComponent - expectedBlack) < 0.001, "Black color blue component must match #202020")
        }

        testRunner("Menu updates status title dynamically on state changes") {
            let assertion = MockSleepAssertionManager()
            let timer = MockTimerScheduler()
            let model = StayOnModel(assertionManager: assertion, timerScheduler: timer)
            let controller = StatusBarController(model: model)

            try expect(controller.statusMenuItem.title == "Inactive")

            model.activateIndefinitely()
            controller.updateMenuContent()
            try expect(controller.statusMenuItem.title == "Active")

            model.activateTimed(duration: .tenMinutes)
            controller.updateMenuContent()
            try expect(controller.statusMenuItem.title == "Active \u{2014} 10 minutes left")

            model.deactivate()
            controller.updateMenuContent()
            try expect(controller.statusMenuItem.title == "Inactive")
            controller.teardown()
        }

        testRunner("Status menu item is informational and does not change state per spec Section 4.1") {
            let assertion = MockSleepAssertionManager()
            let timer = MockTimerScheduler()
            let model = StayOnModel(assertionManager: assertion, timerScheduler: timer)
            let controller = StatusBarController(model: model)

            // When inactive: status item is disabled and has no action
            try expect(!model.state.isActive)
            try expect(controller.statusMenuItem.title == "Inactive")
            try expect(controller.statusMenuItem.isEnabled == false, "Status item must be disabled/informational")
            try expect(controller.statusMenuItem.action == nil, "Status item must have no click action")

            // Status does not change state when attempting click
            try expect(!model.state.isActive)

            // When active timed: status item remains informational and disabled
            model.activateTimed(duration: .fifteenMinutes)
            controller.updateMenuContent()
            try expect(controller.statusMenuItem.title.contains("Active \u{2014}"))
            try expect(controller.statusMenuItem.isEnabled == false)
            try expect(controller.statusMenuItem.action == nil)
            try expect(model.state.isActive)

            controller.teardown()
        }

        testRunner("VoiceOver accessibility label and value are updated dynamically") {
            let assertion = MockSleepAssertionManager()
            let timer = MockTimerScheduler()
            let model = StayOnModel(assertionManager: assertion, timerScheduler: timer)
            let controller = StatusBarController(model: model)

            guard let button = controller.currentStatusItem?.button else {
                assertionFailure("Status button must exist")
                return
            }

            try expect(button.accessibilityLabel() == AppConfig.appName)
            try expect(button.accessibilityValue() as? String == "Inactive")
            try expect(button.toolTip == "\(AppConfig.appName): Inactive")

            model.activateTimed(duration: .thirtyMinutes)
            controller.updateMenuContent()

            try expect(button.accessibilityValue() as? String == "Active \u{2014} 30 minutes left")
            try expect(button.toolTip == "\(AppConfig.appName): Active \u{2014} 30 minutes left")

            controller.teardown()
        }

        testRunner("Launch shows startAtLogin off when not registered in system") {
            let prefs = MockPreferencesManager()
            let loginItem = MockLoginItemManager(isRegisteredAtLogin: false)
            let model = StayOnModel(preferences: prefs, loginItemManager: loginItem)

            model.handleLaunch()

            try expect(model.isStartAtLoginEnabled == false, "Must return false when system registration is false")
        }

        testRunner("Controller teardown removes status item cleanly") {
            let controller = StatusBarController()
            try expect(controller.currentStatusItem != nil)

            controller.teardown()
            try expect(controller.currentStatusItem == nil, "Status item must be removed from system and nil'd")
        }
    }
}
