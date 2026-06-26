import Foundation

/// A folder Porter watches, and how files found in it are routed.
public struct WatchSource: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var path: String
    public var enabled: Bool
    public var routing: Routing
    /// When true, files in subfolders are sorted too (not just the top level).
    public var recursive: Bool

    /// How files from this source are filed onto the NAS.
    public enum Routing: Codable, Equatable, Sendable {
        /// Run the global rule set to pick a destination per file.
        case classify
        /// Send every file from this source into one fixed NAS folder
        /// (e.g. a Pictures folder → "Photos"), bypassing the rules.
        case fixed(folder: String)
    }

    public init(id: UUID = UUID(), path: String, enabled: Bool = true,
                routing: Routing = .classify, recursive: Bool = false) {
        self.id = id
        self.path = path
        self.enabled = enabled
        self.routing = routing
        self.recursive = recursive
    }

    private enum CodingKeys: String, CodingKey {
        case id, path, enabled, routing, recursive
    }

    /// Lenient decode so adding a key (like `recursive`) never invalidates an
    /// existing settings.json — old sources load with sensible defaults.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        path = try c.decode(String.self, forKey: .path)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        routing = try c.decodeIfPresent(Routing.self, forKey: .routing) ?? .classify
        recursive = try c.decodeIfPresent(Bool.self, forKey: .recursive) ?? false
    }

    public var url: URL { URL(fileURLWithPath: path) }
    public var name: String { (path as NSString).lastPathComponent }
}

extension WatchSource {
    /// Default sources for a fresh install: watch Downloads, classify by rules.
    public static var defaults: [WatchSource] {
        let downloads = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads").path
        return [WatchSource(path: downloads, routing: .classify)]
    }
}
