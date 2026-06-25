import Foundation
import Observation
import PorterCore

/// User-tunable configuration, persisted as JSON at
/// `~/.porter*/config/settings.json` — in the user's home, **not** the app bundle,
/// so an app update (which replaces the bundle) never resets it. Each field
/// decodes with a default, so adding a new key later doesn't break an existing
/// file. Channels keep separate files (different `configDirectory`).
///
/// Nothing here is hardcoded into behaviour: the settle delay, the safety-sweep
/// heartbeat, and the event debounce are all read from this config, so they can be
/// tuned without a rebuild.
@MainActor
@Observable
final class PorterSettings {
    var sourcePath: String { didSet { save() } }
    var nasMountPath: String { didSet { save() } }
    var smbURL: String { didSet { save() } }
    /// Seconds a file must be untouched before Porter moves it (the old hardcoded 30).
    var settleSeconds: Double { didSet { save() } }
    /// How often the safety sweep runs regardless of fsevents.
    var heartbeatSeconds: Double { didSet { save() } }
    /// Debounce window after a filesystem event before sweeping.
    var debounceSeconds: Double { didSet { save() } }
    /// Whether the menu-bar status item is shown.
    var menuBarEnabled: Bool { didSet { save() } }
    /// Whether to check for updates automatically at launch.
    var autoCheckUpdates: Bool { didSet { save() } }

    private let fileURL: URL
    private let log = AppInfo.logger("settings")

    private struct Stored: Codable {
        var sourcePath: String?
        var nasMountPath: String?
        var smbURL: String?
        var settleSeconds: Double?
        var heartbeatSeconds: Double?
        var debounceSeconds: Double?
        var menuBarEnabled: Bool?
        var autoCheckUpdates: Bool?
    }

    init() {
        let dir = Channel.current.configDirectory
        fileURL = dir.appendingPathComponent("settings.json")

        let home = FileManager.default.homeDirectoryForCurrentUser
        let stored = Self.load(fileURL)

        sourcePath = stored?.sourcePath ?? home.appendingPathComponent("Downloads").path
        nasMountPath = stored?.nasMountPath ?? "/Volumes/media"
        smbURL = stored?.smbURL ?? ""
        settleSeconds = stored?.settleSeconds ?? 30
        heartbeatSeconds = stored?.heartbeatSeconds ?? 60
        debounceSeconds = stored?.debounceSeconds ?? 1
        menuBarEnabled = stored?.menuBarEnabled ?? true
        autoCheckUpdates = stored?.autoCheckUpdates ?? true
    }

    var sourceURL: URL { URL(fileURLWithPath: sourcePath) }
    var nasURL: URL { URL(fileURLWithPath: nasMountPath) }

    // MARK: - Persistence

    private static func load(_ url: URL) -> Stored? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Stored.self, from: data)
    }

    private func save() {
        let stored = Stored(
            sourcePath: sourcePath, nasMountPath: nasMountPath, smbURL: smbURL,
            settleSeconds: settleSeconds, heartbeatSeconds: heartbeatSeconds,
            debounceSeconds: debounceSeconds, menuBarEnabled: menuBarEnabled,
            autoCheckUpdates: autoCheckUpdates)
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(stored).write(to: fileURL, options: .atomic)
        } catch {
            log.error("could not save settings to \(fileURL.path): \(error.localizedDescription)")
        }
    }
}
