import Foundation

/// Which build channel this app is. Baked into Info.plist (`PorterChannel`) by
/// `build.sh`; defaults to `.stable` when the key is absent (e.g. a plain
/// `swift run`). The three channels install side by side because their bundle
/// ids differ:
///   • Stable — your daily driver, auto-updates from the latest GitHub release.
///   • Nightly — the integration channel, auto-updates from the newest pre-release.
///   • Dev — whatever branch you built locally with `./dev.sh`: separate data,
///     distinct icon, and no updater (rebuild to change it).
public enum Channel: String, Sendable {
    case stable
    case nightly
    case dev

    public static let current: Channel = {
        let raw = Bundle.main.infoDictionary?["PorterChannel"] as? String
        return raw.flatMap(Channel.init(rawValue:)) ?? .stable
    }()

    /// Human-facing app name — matches `CFBundleName` and the `.app` on disk.
    public var displayName: String {
        switch self {
        case .stable:  return "Porter"
        case .nightly: return "Porter Nightly"
        case .dev:     return "Porter Dev"
        }
    }

    /// Short corner-of-the-UI tag, nil on Stable.
    public var badge: String? {
        switch self {
        case .stable:  return nil
        case .nightly: return "NIGHTLY"
        case .dev:     return "DEV"
        }
    }

    /// Suffix appended to `com.syntaxlabtechnology.porter` to form the bundle id.
    public var bundleSuffix: String {
        switch self {
        case .stable:  return ""
        case .nightly: return ".nightly"
        case .dev:     return ".dev"
        }
    }

    /// The published DMG asset name for this channel. nil for Dev, which never
    /// publishes a release.
    public var assetName: String? {
        switch self {
        case .stable:  return "Porter.dmg"
        case .nightly: return "Porter-Nightly.dmg"
        case .dev:     return nil
        }
    }

    /// Hidden data-home directory name under `~/`.
    public var dataDirSuffix: String {
        switch self {
        case .stable:  return ".porter"
        case .nightly: return ".porter-nightly"
        case .dev:     return ".porter-dev"
        }
    }

    /// Per-channel data home (`~/.porter`, `~/.porter-nightly`, …). Channels stay
    /// isolated here so they can run side by side without stepping on each other.
    public var dataDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(dataDirSuffix, isDirectory: true)
    }

    /// Where the daily log files live (`~/.porter*/logs/`).
    public var logsDirectory: URL {
        dataDirectory.appendingPathComponent("logs", isDirectory: true)
    }

    /// Where persisted settings live (`~/.porter*/config/`).
    public var configDirectory: URL {
        dataDirectory.appendingPathComponent("config", isDirectory: true)
    }

    /// Where the persisted move history for the stats dashboard lives
    /// (`~/.porter*/stats/`).
    public var statsDirectory: URL {
        dataDirectory.appendingPathComponent("stats", isDirectory: true)
    }

    /// Stable tracks the latest full release; Nightly tracks the newest
    /// pre-release. (Dev tracks nothing — see `updatesEnabled`.)
    public var isPrerelease: Bool { self == .nightly }

    /// Dev has no updater at all. Stable and Nightly both update from their feeds.
    public var updatesEnabled: Bool { self != .dev }

    /// Extra build detail (branch@sha), baked in for Nightly and Dev so the
    /// About screen can show exactly what's running. nil on Stable.
    public static var buildInfo: String? {
        Bundle.main.infoDictionary?["PorterBuildInfo"] as? String
    }
}
