# StayOn — macOS App Specification

Product requirements · macOS menu bar utility · v1.0

## 1. Overview

StayOn is a lightweight macOS menu bar utility that prevents the computer from going to sleep for a user-defined duration or indefinitely.

The app runs exclusively in the macOS menu bar. It has no Dock icon, no main window, and no unnecessary interface.

The user can activate or deactivate sleep prevention with a single left-click or choose a specific duration from the right-click menu.

## 2. Core requirements

- Menu bar only: No Dock icon or standard application window.
- Two visual states: Distinct active and inactive menu bar icons.
- Instant activation: Left-click toggles indefinite sleep prevention.
- Timed activation: Right-click offers predefined durations.
- Automatic expiration: Timed activation ends automatically when its duration expires.
- Persistent preferences: Remember user settings across launches.
- Native macOS behavior: Use system-supported APIs rather than simulating user activity.

## 3. Menu bar behavior

Inactive state

Sleep prevention is disabled. macOS manages sleep normally.

Active state

Sleep prevention is enabled, either indefinitely or for a limited time.

The icons above illustrate the two states; the final icon designs should be custom, recognizable at standard macOS menu bar sizes, and legible in both light and dark appearances.

### Left-click

- If inactive, activate sleep prevention indefinitely.
- If active, deactivate sleep prevention immediately, regardless of whether it was activated indefinitely or with a timer.
- Update the menu bar icon immediately after the state changes.

### Right-click

Open a native context menu containing the current status, duration shortcuts, preferences, and quit command.

Right-clicking must not change the current activation state.

## 4. Context menu specification

The menu must display the following items in the specified order.

Active — 23 minutes left

Dynamic status item; example only.

Activate for 5 minutes

Activate for 10 minutes

Activate for 15 minutes

Activate for 30 minutes

Activate for 45 minutes

Activate for 1 hour

Activate for 2 hours

Activate for 4 hours

Start at Login

Activate on Launch

Quit StayOn

Illustrative menu layout. The checkmarks represent enabled toggle settings, not fixed defaults.

### 4.1 Dynamic status item

The first item communicates the current activation state.

| State                          | Display                            |
| ------------------------------ | ---------------------------------- |
| Inactive                       | `Inactive`                         |
| Active indefinitely            | `Active`                           |
| Active with a timer            | `Active — N minutes left`          |
| Less than one minute remaining | `Active — Less than 1 minute left` |

The remaining time must be calculated from the actual expiration timestamp, not by decrementing a counter. The display should update whenever the menu opens and while it remains open, where practical.

The status item is informational and does not change the activation state when clicked.

### 4.2 Duration shortcuts

Selecting a duration activates sleep prevention for that duration, measured from the moment of selection.

| Menu item               | Duration       |
| ----------------------- | -------------- |
| Activate for 5 minutes  | 300 seconds    |
| Activate for 10 minutes | 600 seconds    |
| Activate for 15 minutes | 900 seconds    |
| Activate for 30 minutes | 1,800 seconds  |
| Activate for 45 minutes | 2,700 seconds  |
| Activate for 1 hour     | 3,600 seconds  |
| Activate for 2 hours    | 7,200 seconds  |
| Activate for 4 hours    | 14,400 seconds |

Rules:

- Selecting a duration activates sleep prevention immediately.
- Selecting a new duration replaces the previous activation mode and resets the expiration time.
- Selecting a duration while already active starts a fresh timer; it does not add to the existing remaining time.
- When the timer expires, sleep prevention is disabled automatically and the icon changes to inactive.
- No notification is required when a timer expires in v1.0.

### 4.3 Start at Login

A persistent toggle that controls whether StayOn launches automatically when the user logs into macOS.

- Checked: register the app to launch at login.
- Unchecked: remove the login item registration.
- Reflect the actual registration state in the menu.
- Use the supported macOS login item mechanism, such as `SMAppService` on compatible macOS versions.

This setting controls app launch, not sleep prevention itself.

### 4.4 Activate on Launch

A persistent toggle that determines whether StayOn automatically enables sleep prevention when the app launches.

- Checked: activate sleep prevention indefinitely on launch.
- Unchecked: launch in the inactive state.
- The setting applies on every launch, including launches at login.
- It must work independently of the Start at Login setting.

Important: In v1.0, this setting always activates indefinitely. It does not restore a previous timer or its remaining duration.

### 4.5 Quit

Selecting Quit must:

- Disable sleep prevention immediately.
- Release any active system assertion.
- Remove the menu bar item.
- Terminate the application cleanly.

Quitting overrides Activate on Launch until the next launch.

## 5. State model

StayOn has three internal runtime states:

### Inactive

No active sleep-prevention assertion. Inactive icon.

Left-click or select a duration

### Active — Indefinite

Sleep prevention remains active until manually disabled or the app quits. Active icon.

Choose a duration to start or replace a timer

### Active — Timed

Sleep prevention remains active until the deadline or manual deactivation. Active icon.

### State transitions

- Inactive → Indefinite: left-click, or launch with Activate on Launch enabled.
- Indefinite → Inactive: left-click.
- Timed → Inactive: left-click.
- Inactive → Timed: select any duration.
- Indefinite → Timed: select any duration.
- Timed → Timed: select a different duration, replacing the previous deadline.
- Timed → Inactive: timer expires.
- Any state → Inactive: quit.

The active icon is identical for indefinite and timed activation. The remaining duration is communicated through the menu.

## 6. Technical implementation

### Platform and architecture

- Language: Swift.
- UI: AppKit, using `NSStatusItem` and `NSMenu`.
- App lifecycle: menu-bar-only application, configured as an accessory app (`LSUIElement = YES`).
- Minimum OS: macOS 13 Ventura or later.
- Preferences: `UserDefaults`.
- Login item: `SMAppService`, available on the specified minimum OS.
- Sleep prevention: `ProcessInfo.processInfo.beginActivity(options:reason:)` or another appropriate native system assertion, with correct lifecycle management.

### Preventing sleep

Use a system-supported assertion with the appropriate options to prevent system idle sleep while StayOn is active.

Implementation requirements:

- Hold exactly one active assertion at a time.
- Reuse the assertion when changing from indefinite to timed activation or replacing one timer with another.
- Invalidate the assertion immediately on deactivation, timer expiration, or quit.
- Do not generate artificial mouse or keyboard events.
- Do not disable the display's ability to sleep unless explicitly required in a future version.
- Do not attempt to prevent forced shutdown, battery depletion, or shutdown initiated by the user or operating system.

The app prevents automatic idle sleep; it does not guarantee that the Mac can never shut down.

### Timer implementation

Use an absolute expiration date for timed activation.

- Store the deadline as a `Date`.
- Calculate remaining time using the current time minus the deadline.
- Schedule an expiration callback.
- Cancel and replace the previous scheduled callback when a new duration is selected.
- Recheck the deadline when the app becomes active and when the menu opens.
- Ensure that a delayed callback cannot leave sleep prevention active past the deadline.

System clock changes and sleep/wake transitions should be handled by checking the deadline against the current system time.

### Left-click and right-click handling

The menu bar interaction must distinguish a normal left-click from a right-click without requiring a separate Dock icon or window.

Use an AppKit status item with appropriate event handling to toggle activation on left-click and display the context menu on right-click. Verify that both interactions work reliably across supported macOS versions.

## 7. Persistence and launch behavior

Persist these preferences:

- `startAtLogin`: Boolean.
- `activateOnLaunch`: Boolean.

Do not persist active runtime state as a promise that sleep prevention remains enabled across launches.

On app launch:

1. Initialize the menu bar item.
2. Read and apply saved preferences.
3. Synchronize the Start at Login toggle with the system's actual login-item registration.
4. If Activate on Launch is enabled, activate indefinite sleep prevention.
5. Otherwise, start inactive.
6. Render the correct menu bar icon.

On quit, release the system assertion and terminate.

If the app crashes or is force-terminated, the operating system must release the process-associated assertion when the process exits.

## 8. Non-functional requirements

- Minimal CPU and memory usage while idle.
- No network access or account required.
- No analytics or telemetry.
- No Dock icon, main window, or unnecessary dialogs.
- Native menu behavior and keyboard accessibility.
- Support macOS light and dark appearances.
- Correct handling of app relaunches and timer expiration.
- No duplicated assertions or competing timers.
- Clear active/inactive state at a glance.

## 9. Acceptance criteria

- StayOn appears only in the menu bar.
- Two distinct icons represent active and inactive states.
- Left-click toggles indefinite sleep prevention.
- Right-click opens the menu without changing the state.
- All seven timed durations plus the 5-minute option work as specified.
- Selecting a new duration replaces the previous timer.
- The menu shows accurate remaining time or simply `Active` for indefinite mode.
- Expiration automatically disables sleep prevention.
- Start at Login persists and accurately reflects system registration.
- Activate on Launch persists and activates indefinitely on each launch when enabled.
- Quit releases the assertion and terminates the app.
- No artificial input events are generated.
- Sleep prevention does not unnecessarily keep the display awake.
- No lingering assertions remain after deactivation or termination.

## 10. Out of scope for v1.0

- Custom durations.
- Pause and resume.
- Multiple simultaneous timers.
- Automatic activation based on applications or focus modes.
- Notifications when timers expire.
- Preventing explicit user-initiated shutdown or restart.
- Preventing display sleep.
- A settings window, Dock icon, or onboarding flow.

Definition of done: StayOn is a small, reliable macOS menu bar utility that lets a user prevent idle system sleep indefinitely or for a predefined duration with one click, without interfering with normal macOS operation beyond the selected behavior.