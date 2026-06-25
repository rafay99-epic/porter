import Foundation

/// A daily window during which Porter shouldn't sort (e.g. 22:00–07:00 so a big
/// move doesn't spin up the NAS overnight). Stored as minutes-since-midnight so
/// it's timezone-agnostic in the file and trivial to compare. Supports windows
/// that wrap past midnight.
public struct QuietHours: Codable, Equatable, Sendable {
    public var enabled: Bool
    /// Inclusive start, minutes since local midnight (0...1439).
    public var startMinute: Int
    /// Exclusive end, minutes since local midnight (0...1439).
    public var endMinute: Int

    public init(enabled: Bool = false, startMinute: Int = 22 * 60, endMinute: Int = 7 * 60) {
        self.enabled = enabled
        self.startMinute = startMinute
        self.endMinute = endMinute
    }

    /// Is `date` inside the quiet window? Always false when disabled. A window where
    /// start == end is treated as empty (never quiet) rather than always-quiet.
    public func isQuiet(at date: Date, calendar: Calendar = .current) -> Bool {
        guard enabled, startMinute != endMinute else { return false }
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        let now = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        if startMinute < endMinute {
            return now >= startMinute && now < endMinute       // same-day window
        } else {
            return now >= startMinute || now < endMinute        // wraps past midnight
        }
    }

    /// "07:00" — the time sorting resumes, for the status message.
    public var endLabel: String {
        String(format: "%02d:%02d", endMinute / 60, endMinute % 60)
    }
}
