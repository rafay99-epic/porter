import Foundation

/// One persisted move, the unit the stats dashboard aggregates over time.
/// Deliberately tiny — date, top-level category, and bytes — so a long history
/// stays cheap to load and chart.
public struct StatRecord: Codable, Sendable, Equatable {
    public let date: Date
    /// Top-level destination folder (e.g. "Pictures" from "Pictures/2026/06").
    public let category: String
    public let bytes: Int64

    public init(date: Date, category: String, bytes: Int64) {
        self.date = date
        self.category = category
        self.bytes = bytes
    }
}

/// Append-only history of moves, persisted as a JSON array under
/// `~/.porter*/stats/history.json`. Unlike the in-memory activity log (capped at
/// 100, lost on quit), this survives relaunches so the dashboard can show trends.
/// Pruned to a rolling window on save so it can't grow without bound.
///
/// Single-writer (the coordinator) so a plain load-modify-save is safe; the whole
/// type is `Sendable` (only an immutable `URL`) so it can be used off the main
/// actor from a detached task.
public final class StatsStore: Sendable {
    private let fileURL: URL
    /// Drop records older than this many days on save.
    private let retentionDays: Int

    public init(directory: URL, retentionDays: Int = 365) {
        self.fileURL = directory.appendingPathComponent("history.json")
        self.retentionDays = retentionDays
    }

    public func load() -> [StatRecord] {
        guard let data = try? Data(contentsOf: fileURL),
              let records = try? JSONDecoder().decode([StatRecord].self, from: data) else { return [] }
        return records
    }

    /// Append `records`, prune to the retention window, and rewrite the file.
    public func append(_ records: [StatRecord], now: Date = Date()) {
        guard !records.isEmpty else { return }
        let cutoff = now.addingTimeInterval(-Double(retentionDays) * 86_400)
        let merged = (load() + records).filter { $0.date >= cutoff }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            // Default date strategy on both sides (load uses a plain decoder).
            try JSONEncoder().encode(merged).write(to: fileURL, options: .atomic)
        } catch {
            // Stats are best-effort telemetry — never let a write failure disrupt a
            // sweep. The next append retries with the same in-memory data.
        }
    }

    /// Map a top-level category out of a (possibly nested/templated) destination,
    /// e.g. "Pictures/2026/06" → "Pictures".
    public static func category(fromDestination destination: String) -> String {
        destination.split(separator: "/").first.map(String.init) ?? destination
    }
}
