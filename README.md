# Swift Starter App Boilerplate

<p align="center">
  <img src="Resources/AppIcon.png" width="128" height="128" alt="App Icon" />
</p>

A minimal, zero-dependency macOS starter boilerplate written in native Swift and AppKit. Designed to be stripped clean, quickly configured, and used as the foundation for building lightweight menu bar (status bar) or desktop macOS applications.

## Quick Start

```bash
# Build the application bundle
make build

# Launch the application
make run

# Terminate running instances
make kill

# Run the test suite
make test

# Build the release DMG
make dmg

# Reset permissions and macOS caches
make revoke

# Clean build artifacts
make clean
```

## Makefile Targets

| Target | Description |
|---|---|
| `make help` | Display available targets and descriptions |
| `make build` | Compile the `.app` bundle into `build/` |
| `make run` | Terminate existing instances, rebuild, and launch the app |
| `make kill` | Terminate running instances of the application |
| `make test` | Run the native Swift test suite |
| `make dmg` | Build a styled DMG package for distribution |
| `make release <version>` | Bump version, execute tests, build DMG, tag, and publish |
| `make revoke` | Reset TCC permissions and flush macOS QuickLook & LaunchServices caches |
| `make clean` | Remove `build/` artifacts and temporary test binaries |

## Project Structure

```text
swift-boilerplate/
├── Makefile                # Build orchestration and lifecycle targets
├── Package.swift           # Swift Package Manager manifest
├── VERSION                 # Current semantic version
├── BUILD_NUMBER            # Auto-incrementing build counter
├── Resources/
│   ├── AppIcon.icns        # Application icon (macOS icns)
│   ├── AppIcon.png         # Generic black square with white "sa"
│   ├── StatusBarIcon.png   # 18x18 status bar icon ("sa")
│   ├── StatusBarIcon@2x.png# 36x36 retina status bar icon ("sa")
│   └── dmg_background*.png # DMG distribution styling
├── Sources/
│   └── App/
│       ├── Main.swift                # Application entry point (@main)
│       ├── AppDelegate.swift         # NSApplicationDelegate lifecycle
│       ├── AppConfig.swift           # App metadata and version resolution
│       └── StatusBarController.swift # Menu bar status item & menu
├── Tests/
│   └── AppTests/
│       ├── AppTests.swift  # Minimal test suite
│       └── TestMain.swift  # Test runner entry point
└── scripts/
    ├── config.sh           # App name, bundle ID, and build settings
    ├── build.sh            # Direct swiftc compilation & code signing
    ├── test.sh             # Native test compilation & execution
    ├── build_dmg.sh        # DMG packaging script
    └── release.sh          # Version bump & automated release workflow
```

## Customizing

Edit [scripts/config.sh](file:///Users/citizen/dev/swift-boilerplate/scripts/config.sh) to set your app name and bundle identifier:

```bash
export APP_NAME="MyApp"
export BUNDLE_ID="com.example.MyApp"
export LS_UI_ELEMENT="true" # Set to false if you want a regular Dock icon
```
