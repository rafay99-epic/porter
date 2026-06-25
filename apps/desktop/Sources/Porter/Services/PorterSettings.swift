import Foundation
import Observation
import PorterCore

/// User-tunable configuration, persisted as JSON at
/// `~/.porter*/config/settings.json` — in the user's home, **not** the app bundle,
/// so an app update (which replaces the bundle) never resets it. Each field
/// decodes with a default, so adding a new key later doesn't break an existing
/// file. Channels keep separate files (different `configDirectory`).
///
/// Nothing here is hardcoded into behaviour: the watched folders, the sort rules,
/// the settle delay, the safety-sweep heartbeat, and the event debounce are all
/// read from this config, so they can be tuned without a rebuild.
@MainActor
@Observable
final class PorterSettings {
    /// Folders Porter watches, each with its own routing.
    var sources: [WatchSource] { didSet { save() } }
    /// Ordered sort rules (first enabled match wins). Editable in Settings.
    var rules: [SortRule] { didSet { save() } }

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
    /// Whether to post a native notification after each sweep (sorted / failed).
    var notificationsEnabled: Bool { didSet { save() } }
    /// Global pause — when true, no sweeps run until the user resumes.
    var paused: Bool { didSet { save() } }
    /// A daily window during which sorting is suspended.
    var quietHours: QuietHours { didSet { save() } }

    private let fileURL: URL
    private let log = AppInfo.logger("settings")

    private struct Stored: Codable {
        var sources: [WatchSource]?
        var rules: [SortRule]?
        /// Legacy single-folder key, migrated into `sources` on load.
        var sourcePath: String?
        var nasMountPath: String?
        var smbURL: String?
        var settleSeconds: Double?
        var heartbeatSeconds: Double?
        var debounceSeconds: Double?
        var menuBarEnabled: Bool?
        var autoCheckUpdates: Bool?
        var notificationsEnabled: Bool?
        var paused: Bool?
        var quietHours: QuietHours?
    }

    init() {
        let dir = Channel.current.configDirectory
        fileURL = dir.appendingPathComponent("settings.json")
        let stored = Self.load(fileURL)

        // Migrate: prefer an explicit sources list; else a legacy single sourcePath;
        // else the defaults (watch Downloads).
        if let saved = stored?.sources, !saved.isEmpty {
            sources = saved
        } else if let legacy = stored?.sourcePath {
            sources = [WatchSource(path: legacy, routing: .classify)]
        } else {
            sources = WatchSource.defaults
        }
        rules = stored?.rules ?? SortRule.defaults

        nasMountPath = stored?.nasMountPath ?? "/Volumes/media"
        smbURL = stored?.smbURL ?? ""
        settleSeconds = stored?.settleSeconds ?? 30
        heartbeatSeconds = stored?.heartbeatSeconds ?? 60
        debounceSeconds = stored?.debounceSeconds ?? 1
        menuBarEnabled = stored?.menuBarEnabled ?? true
        autoCheckUpdates = stored?.autoCheckUpdates ?? true
        notificationsEnabled = stored?.notificationsEnabled ?? true
        paused = stored?.paused ?? false
        quietHours = stored?.quietHours ?? QuietHours()
    }

    var nasURL: URL { URL(fileURLWithPath: nasMountPath) }

    /// Enabled source folders, deduped, excluding any that live inside the NAS
    /// root (so Porter never tries to watch — and re-file — its own destination).
    var activeSourceURLs: [URL] {
        var seen = Set<String>()
        var result: [URL] = []
        let nas = nasMountPath
        for source in sources where source.enabled {
            let path = source.url.standardizedFileURL.path
            guard !seen.contains(path) else { continue }
            guard !path.hasPrefix(nas + "/") && path != nas else { continue }
            seen.insert(path)
            result.append(source.url)
        }
        return result
    }

    // MARK: - Persistence

    private static func load(_ url: URL) -> Stored? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Stored.self, from: data)
    }

    private func save() {
        let stored = Stored(
            sources: sources, rules: rules, sourcePath: nil,
            nasMountPath: nasMountPath, smbURL: smbURL,
            settleSeconds: settleSeconds, heartbeatSeconds: heartbeatSeconds,
            debounceSeconds: debounceSeconds, menuBarEnabled: menuBarEnabled,
            autoCheckUpdates: autoCheckUpdates, notificationsEnabled: notificationsEnabled,
            paused: paused, quietHours: quietHours)
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
