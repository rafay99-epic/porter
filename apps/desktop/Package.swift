// swift-tools-version: 6.0
import PackageDescription

// Porter — a menu-bar app that watches ~/Downloads and files each download into
// the matching folder on the NAS. Two targets:
//   • PorterCore — all the logic (classify / move / watch / mount-state), with no
//     SwiftUI. It's where the unit tests point, so the hard-won move rules can be
//     pinned without spinning up a UI.
//   • Porter — the SwiftUI menu-bar app. Runs the watcher IN-PROCESS (not as a
//     separate LaunchAgent): the app is launched at login as a login-item *app*
//     (SMAppService.mainApp), so it lives in the full Aqua GUI session and its
//     writes to the Finder-mounted SMB share actually succeed — the whole reason
//     this app exists instead of a launchd job.
let package = Package(
    name: "Porter",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "PorterCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "Porter",
            dependencies: ["PorterCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "PorterCoreTests",
            dependencies: ["PorterCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
