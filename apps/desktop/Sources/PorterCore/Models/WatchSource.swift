import Foundation

/// A folder Porter watches, and how files found in it are routed.
public struct WatchSource: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var path: String
    public var enabled: Bool
    public var routing: Routing

    /// How files from this source are filed onto the NAS.
    public enum Routing: Codable, Equatable, Sendable {
        /// Run the global rule set to pick a destination per file.
        case classify
        /// Send every file from this source into one fixed NAS folder
        /// (e.g. a Pictures folder → "Photos"), bypassing the rules.
        case fixed(folder: String)
    }

    public init(id: UUID = UUID(), path: String, enabled: Bool = true, routing: Routing = .classify) {
        self.id = id
        self.path = path
        self.enabled = enabled
        self.routing = routing
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
