import Foundation
import AppKit

public enum StayOnTests {
    public static func run(testRunner: (String, () throws -> Void) -> Void) {
        // MARK: - Duration & Formatting Suite
        testRunner("Duration definitions match spec exactly") {
            assert(StayOnDuration.allCases.count == 8, "Must have exactly 8 predefined durations")
            assert(StayOnDuration.fiveMinutes.rawValue == 300, "5 minutes = 300s")
            assert(StayOnDuration.tenMinutes.rawValue == 600, "10 minutes = 600s")
            assert(StayOnDuration.fifteenMinutes.rawValue == 900, "15 minutes = 900s")
            assert(StayOnDuration.thirtyMinutes.rawValue == 1800, "30 minutes = 1800s")
            assert(StayOnDuration.fortyFiveMinutes.rawValue == 2700, "45 minutes = 2700s")
            assert(StayOnDuration.oneHour.rawValue == 3600, "1 hour = 3600s")
            assert(StayOnDuration.twoHours.rawValue == 7200, "2 hours = 7200s")
            assert(StayOnDuration.fourHours.rawValue == 14400, "4 hours = 14400s")

            assert(StayOnDuration.fiveMinutes.title == "Activate for 5 minutes")
            assert(StayOnDuration.oneHour.title == "Activate for 1 hour")
            assert(StayOnDuration.fourHours.title == "Activate for 4 hours")
        }

        testRunner("Status text formatting conforms to spec table") {
            let baseDate = Date(timeIntervalSince1970: 1000000)

            // Inactive
            assert(SleepState.inactive.statusText(at: baseDate) == "Activate Indefinitely")

            // Active Indefinite
            assert(SleepState.activeIndefinite.statusText(at: baseDate) == "Active")

            // Active with 23 minutes left
            let deadline23m = baseDate.addingTimeInterval(23 * 60)
            assert(SleepState.activeTimed(deadline: deadline23m).statusText(at: baseDate) == "Active \u{2014} 23 minutes left")

            // Active with 5 minutes left
            let deadline5m = baseDate.addingTimeInterval(300)
            assert(SleepState.activeTimed(deadline: deadline5m).statusText(at: baseDate) == "Active \u{2014} 5 minutes left")

            // Active with 65 seconds left (rounds up to 2 minutes)
            let deadline65s = baseDate.addingTimeInterval(65)
            assert(SleepState.activeTimed(deadline: deadline65s).statusText(at: baseDate) == "Active \u{2014} 2 minutes left")

            // Active with exactly 60 seconds left (1 minute left)
            let deadline60s = baseDate.addingTimeInterval(60)
            assert(SleepState.activeTimed(deadline: deadline60s).statusText(at: baseDate) == "Active \u{2014} 1 minute left")

            // Less than one minute remaining
            let deadline59s = baseDate.addingTimeInterval(59)
            assert(SleepState.activeTimed(deadline: deadline59s).statusText(at: baseDate) == "Active \u{2014} Less than 1 minute left")

            let deadline1s = baseDate.addingTimeInterval(1)
            assert(SleepState.activeTimed(deadline: deadline1s).statusText(at: baseDate) == "Active \u{2014} Less than 1 minute left")

            // Expired (0 or negative)
            let deadline0s = baseDate
            assert(SleepState.activeTimed(deadline: deadline0s).statusText(at: baseDate) == "Activate Indefinitely")

            let deadlinePast = baseDate.addingTimeInterval(-10)
            assert(SleepState.activeTimed(deadline: deadlinePast).statusText(at: baseDate) == "Activate Indefinitely")
        }

        // MARK: - State Transitions Suite
        testRunner("State transition: Inactive -> Indefinite on left-click") {
            let assertion = MockSleepAssertionManager()
            let model = StayOnModel(assertionManager: assertion)

            assert(model.state == .inactive)
            assert(!assertion.isAssertionActive)

            model.toggleLeftClick()

            assert(model.state == .activeIndefinite)
            assert(model.state.isActive)
            assert(!model.state.isTimed)
            assert(assertion.isAssertionActive)
            assert(assertion.acquireCount == 1)
        }

        testRunner("State transition: Indefinite -> Inactive on left-click") {
            let assertion = MockSleepAssertionManager()
            let model = StayOnModel(assertionManager: assertion)
            model.activateIndefinitely()

            model.toggleLeftClick()

            assert(model.state == .inactive)
            assert(!assertion.isAssertionActive)
            assert(assertion.releaseCount == 1)
        }

        testRunner("State transition: Timed -> Inactive on left-click") {
            let assertion = MockSleepAssertionManager()
            let timer = MockTimerScheduler()
            let model = StayOnModel(assertionManager: assertion, timerScheduler: timer)

            model.activateTimed(duration: .fifteenMinutes)
            assert(model.state.isActive && model.state.isTimed)
            assert(timer.scheduledTimers.count == 1)

            model.toggleLeftClick()

            assert(model.state == .inactive)
            assert(!assertion.isAssertionActive)
            assert(timer.cancelledTimers.count == 1)
        }

        testRunner("State transition: Inactive -> Timed") {
            let assertion = MockSleepAssertionManager()
            let timer = MockTimerScheduler()
            let model = StayOnModel(assertionManager: assertion, timerScheduler: timer)

            let now = Date()
            model.activateTimed(duration: .thirtyMinutes, from: now)

            assert(model.state.isActive)
            assert(model.state.isTimed)
            assert(assertion.isAssertionActive)
            assert(timer.scheduledTimers.count == 1)
            assert(timer.scheduledTimers[0].interval == 1800)

            if case .activeTimed(let deadline) = model.state {
                assert(abs(deadline.timeIntervalSince(now) - 1800) < 0.01)
            } else {
                fatalError("Expected activeTimed state")
            }
        }

        testRunner("State transition: Indefinite -> Timed reuses assertion") {
            let assertion = MockSleepAssertionManager()
            let timer = MockTimerScheduler()
            let model = StayOnModel(assertionManager: assertion, timerScheduler: timer)

            model.activateIndefinitely()
            assert(assertion.acquireCount == 1)

            model.activateTimed(duration: .oneHour)
            assert(model.state.isTimed)
            // Exactly one active assertion held and reused
            assert(assertion.isAssertionActive)
            assert(assertion.acquireCount == 1)
            assert(assertion.releaseCount == 0)
        }

        testRunner("State transition: Timed -> Timed replaces deadline and resets timer") {
            let assertion = MockSleepAssertionManager()
            let timer = MockTimerScheduler()
            let model = StayOnModel(assertionManager: assertion, timerScheduler: timer)

            let now = Date()
            model.activateTimed(duration: .fiveMinutes, from: now)
            assert(timer.scheduledTimers.count == 1)

            // Replace with 2 hours
            model.activateTimed(duration: .twoHours, from: now)
            assert(timer.scheduledTimers.count == 2)
            assert(timer.cancelledTimers.count == 1)
            assert(timer.cancelledTimers[0] === timer.scheduledTimers[0])

            // Assertion remains continuously active
            assert(assertion.isAssertionActive)
            assert(assertion.acquireCount == 1)
            assert(assertion.releaseCount == 0)

            if case .activeTimed(let deadline) = model.state {
                assert(abs(deadline.timeIntervalSince(now) - 7200) < 0.01)
            } else {
                fatalError("Expected activeTimed state")
            }
        }

        testRunner("State transition: Timed -> Inactive when timer expires") {
            let assertion = MockSleepAssertionManager()
            let timer = MockTimerScheduler()
            let model = StayOnModel(assertionManager: assertion, timerScheduler: timer)

            model.activateTimed(duration: .fiveMinutes)
            assert(model.state.isActive)
            assert(assertion.isAssertionActive)

            // Simulate timer firing
            timer.fireLastTimer()

            assert(model.state == .inactive)
            assert(!assertion.isAssertionActive)
            assert(assertion.releaseCount == 1)
        }

        testRunner("checkExpiration automatically deactivates if past deadline") {
            let assertion = MockSleepAssertionManager()
            let timer = MockTimerScheduler()
            let model = StayOnModel(assertionManager: assertion, timerScheduler: timer)

            let startTime = Date(timeIntervalSince1970: 1000)
            model.activateTimed(seconds: 300, from: startTime)
            assert(model.state.isActive)

            // Check before deadline
            model.checkExpiration(at: Date(timeIntervalSince1970: 1200))
            assert(model.state.isActive)

            // Check after deadline
            model.checkExpiration(at: Date(timeIntervalSince1970: 1301))
            assert(model.state == .inactive)
            assert(!assertion.isAssertionActive)
        }

        testRunner("handleQuit deactivates and releases assertion immediately") {
            let assertion = MockSleepAssertionManager()
            let timer = MockTimerScheduler()
            let model = StayOnModel(assertionManager: assertion, timerScheduler: timer)

            model.activateTimed(duration: .tenMinutes)
            assert(assertion.isAssertionActive)

            model.handleQuit()

            assert(model.state == .inactive)
            assert(!assertion.isAssertionActive)
            assert(assertion.releaseCount == 1)
            assert(timer.cancelledTimers.count == 1)
        }

        // MARK: - Preferences & Launch Suite
        testRunner("Launch behavior: activateOnLaunch disabled starts inactive") {
            let assertion = MockSleepAssertionManager()
            let prefs = MockPreferencesManager(startAtLogin: false, activateOnLaunch: false)
            let loginItem = MockLoginItemManager(isRegisteredAtLogin: false)
            let model = StayOnModel(assertionManager: assertion, preferences: prefs, loginItemManager: loginItem)

            model.handleLaunch()

            assert(model.state == .inactive)
            assert(!assertion.isAssertionActive)
        }

        testRunner("Launch behavior: activateOnLaunch enabled activates indefinitely") {
            let assertion = MockSleepAssertionManager()
            let prefs = MockPreferencesManager(startAtLogin: false, activateOnLaunch: true)
            let loginItem = MockLoginItemManager(isRegisteredAtLogin: false)
            let model = StayOnModel(assertionManager: assertion, preferences: prefs, loginItemManager: loginItem)

            model.handleLaunch()

            assert(model.state == .activeIndefinite)
            assert(assertion.isAssertionActive)
            assert(assertion.acquireCount == 1)
        }

        testRunner("Launch synchronizes startAtLogin preference with system registration") {
            let prefs = MockPreferencesManager(startAtLogin: false)
            let loginItem = MockLoginItemManager(isRegisteredAtLogin: true)
            let model = StayOnModel(preferences: prefs, loginItemManager: loginItem)

            model.handleLaunch()

            assert(prefs.startAtLogin == true, "Should reflect system login item state")
        }

        testRunner("setStartAtLogin updates registration and preferences") {
            let prefs = MockPreferencesManager(startAtLogin: false)
            let loginItem = MockLoginItemManager(isRegisteredAtLogin: false)
            let model = StayOnModel(preferences: prefs, loginItemManager: loginItem)

            let success = model.setStartAtLogin(true)
            assert(success)
            assert(loginItem.isRegisteredAtLogin == true)
            assert(prefs.startAtLogin == true)

            let unregSuccess = model.setStartAtLogin(false)
            assert(unregSuccess)
            assert(loginItem.isRegisteredAtLogin == false)
            assert(prefs.startAtLogin == false)
        }

        testRunner("setStartAtLogin handles errors gracefully") {
            let prefs = MockPreferencesManager(startAtLogin: false)
            let loginItem = MockLoginItemManager(isRegisteredAtLogin: false)
            loginItem.shouldThrowOnRegister = true
            let model = StayOnModel(preferences: prefs, loginItemManager: loginItem)

            let success = model.setStartAtLogin(true)
            assert(!success)
            assert(prefs.startAtLogin == false)
        }

        testRunner("setActivateOnLaunch persists preference") {
            let prefs = MockPreferencesManager(activateOnLaunch: false)
            let model = StayOnModel(preferences: prefs)

            model.setActivateOnLaunch(true)
            assert(prefs.activateOnLaunch == true)

            model.setActivateOnLaunch(false)
            assert(prefs.activateOnLaunch == false)
        }

        testRunner("setPreventLogout persists preference and updates active assertion") {
            let prefs = MockPreferencesManager(preventLogout: true)
            let assertion = MockSleepAssertionManager()
            let model = StayOnModel(assertionManager: assertion, preferences: prefs)

            model.setPreventLogout(false)
            assert(prefs.preventLogout == false)
            assert(assertion.lastPreventLogout == nil)

            model.activateIndefinitely()
            assert(assertion.lastPreventLogout == false)

            model.setPreventLogout(true)
            assert(prefs.preventLogout == true)
            assert(assertion.lastPreventLogout == true)
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
            assert(menu.items.count == 16, "Menu must have exactly 16 items including separators")

            // Status item
            assert(menu.items[0] === controller.statusMenuItem)
            assert(menu.items[0].isEnabled == true, "Status item must be enabled to activate/deactivate")
            assert(menu.items[0].title == "Activate Indefinitely")

            // Separator 1
            assert(menu.items[1].isSeparatorItem)

            // Duration items
            assert(controller.durationMenuItems.count == 8)
            for (idx, duration) in StayOnDuration.allCases.enumerated() {
                let menuItem = menu.items[2 + idx]
                assert(menuItem === controller.durationMenuItems[idx])
                assert(menuItem.title == duration.title)
                assert(menuItem.tag == Int(duration.rawValue))
                assert(menuItem.isEnabled == true)
            }

            // Separator 2
            assert(menu.items[10].isSeparatorItem)

            // Preferences items
            assert(menu.items[11] === controller.startAtLoginMenuItem)
            assert(menu.items[11].title == "Start at Login")
            assert(controller.startAtLoginMenuItem.onStateImage != nil, "Must have checked box image")
            assert(controller.startAtLoginMenuItem.offStateImage != nil, "Must have unchecked box image")

            assert(menu.items[12] === controller.activateOnLaunchMenuItem)
            assert(menu.items[12].title == "Activate on Launch")
            assert(controller.activateOnLaunchMenuItem.onStateImage != nil, "Must have checked box image")
            assert(controller.activateOnLaunchMenuItem.offStateImage != nil, "Must have unchecked box image")

            assert(menu.items[13] === controller.preventLogoutMenuItem)
            assert(menu.items[13].title == "Prevent Logout")
            assert(controller.preventLogoutMenuItem.onStateImage != nil, "Must have checked box image")
            assert(controller.preventLogoutMenuItem.offStateImage != nil, "Must have unchecked box image")

            // Separator 3
            assert(menu.items[14].isSeparatorItem)

            // Quit item
            assert(menu.items[15] === controller.quitMenuItem)
            assert(menu.items[15].title == "Quit StayOn")
            assert(menu.items[15].keyEquivalent == "q")
            assert(menu.items[15].keyEquivalentModifierMask == [.command])
        }

        testRunner("Status bar icon provides distinct active and inactive images for light and dark modes") {
            let activeDark = StatusBarIcon.image(isActive: true, isDark: true)
            let activeLight = StatusBarIcon.image(isActive: true, isDark: false)
            let inactiveDark = StatusBarIcon.image(isActive: false, isDark: true)
            let inactiveLight = StatusBarIcon.image(isActive: false, isDark: false)

            assert(activeDark.size.width == 18 && activeDark.size.height == 18)
            assert(activeLight.size.width == 18 && activeLight.size.height == 18)
            assert(inactiveDark.size.width == 18 && inactiveDark.size.height == 18)
            assert(inactiveLight.size.width == 18 && inactiveLight.size.height == 18)

            assert(activeDark.isTemplate == false, "Must preserve custom two-tone appearance")
            assert(activeLight.isTemplate == false, "Must preserve custom two-tone appearance")

            let whiteColor = StatusBarIcon.iconWhiteColor
            let expected = CGFloat(0xe9) / 255.0
            assert(abs(whiteColor.redComponent - expected) < 0.001, "White color red component must match #e9e9e9")
            assert(abs(whiteColor.greenComponent - expected) < 0.001, "White color green component must match #e9e9e9")
            assert(abs(whiteColor.blueComponent - expected) < 0.001, "White color blue component must match #e9e9e9")

            let blackColor = StatusBarIcon.iconBlackColor
            let expectedBlack = CGFloat(0x20) / 255.0
            assert(abs(blackColor.redComponent - expectedBlack) < 0.001, "Black color red component must match #202020")
            assert(abs(blackColor.greenComponent - expectedBlack) < 0.001, "Black color green component must match #202020")
            assert(abs(blackColor.blueComponent - expectedBlack) < 0.001, "Black color blue component must match #202020")
        }

        testRunner("Menu updates status title dynamically on state changes") {
            let assertion = MockSleepAssertionManager()
            let timer = MockTimerScheduler()
            let model = StayOnModel(assertionManager: assertion, timerScheduler: timer)
            let controller = StatusBarController(model: model)

            assert(controller.statusMenuItem.title == "Activate Indefinitely")

            model.activateIndefinitely()
            controller.updateMenuContent()
            assert(controller.statusMenuItem.title == "Active")

            model.activateTimed(duration: .tenMinutes)
            controller.updateMenuContent()
            assert(controller.statusMenuItem.title == "Active \u{2014} 10 minutes left")

            model.deactivate()
            controller.updateMenuContent()
            assert(controller.statusMenuItem.title == "Activate Indefinitely")
        }

        testRunner("Clicking statusMenuItem activates when inactive and deactivates when active") {
            let assertion = MockSleepAssertionManager()
            let timer = MockTimerScheduler()
            let model = StayOnModel(assertionManager: assertion, timerScheduler: timer)
            let controller = StatusBarController(model: model)

            // When inactive: clicking activates indefinitely
            assert(!model.state.isActive)
            assert(controller.statusMenuItem.title == "Activate Indefinitely")
            _ = controller.statusMenuItem.target?.perform(controller.statusMenuItem.action, with: controller.statusMenuItem)
            assert(model.state.isActive)
            assert(model.state == .activeIndefinite)

            // When active timed: clicking deactivates
            model.activateTimed(duration: .fifteenMinutes)
            controller.updateMenuContent()
            assert(controller.statusMenuItem.title.contains("Active \u{2014}"))
            _ = controller.statusMenuItem.target?.perform(controller.statusMenuItem.action, with: controller.statusMenuItem)
            assert(!model.state.isActive)
            assert(model.state == .inactive)
            controller.updateMenuContent()
            assert(controller.statusMenuItem.title == "Activate Indefinitely")
        }
    }
}
