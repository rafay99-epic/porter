import Foundation

/// A proposed new rule, inferred from what Porter has actually been sorting.
public struct RuleSuggestion: Identifiable, Equatable, Sendable {
    /// The file extension this suggestion is about (lowercased, no dot).
    public let ext: String
    /// How many recent files of this extension fell through to the catch-all.
    public let count: Int

    public var id: String { ext }

    /// A ready-to-edit rule for this extension — destination left blank for the
    /// user to choose.
    public var rule: SortRule {
        SortRule(match: .extensions([ext]), destination: "")
    }
}

/// Watches what Porter sorts and proposes rules for file types that keep landing
/// in the catch-all. The insight: if you've filed several `.epub` files and they
/// all ended up in "Other", a dedicated rule would tidy them — so offer one.
///
/// Pure (history + current rules in, suggestions out) so it's fully unit-testable.
public enum SuggestionEngine {
    /// Suggestions derived from `entries` (newest-first activity), given the current
    /// `rules`. An extension is suggested when at least `minimumCount` of its files
    /// went to the catch-all destination and no current rule already routes that
    /// extension somewhere specific. `dismissed` extensions are excluded.
    public static func suggestions(from entries: [ActivityEntry],
                                   rules: [SortRule],
                                   dismissed: Set<String> = [],
                                   minimumCount: Int = 3) -> [RuleSuggestion] {
        let catchAll = catchAllDestination(in: rules)

        var counts: [String: Int] = [:]
        for entry in entries {
            guard case .moved = entry.outcome, !entry.undone,
                  let destination = entry.destination,
                  topLevel(destination).caseInsensitiveCompare(catchAll) == .orderedSame else { continue }
            let ext = (entry.fileName as NSString).pathExtension.lowercased()
            guard !ext.isEmpty, !dismissed.contains(ext) else { continue }
            counts[ext, default: 0] += 1
        }

        var result: [RuleSuggestion] = []
        for (ext, count) in counts where count >= minimumCount && !isCovered(ext, by: rules) {
            result.append(RuleSuggestion(ext: ext, count: count))
        }
        result.sort { lhs, rhs in
            lhs.count != rhs.count ? lhs.count > rhs.count : lhs.ext < rhs.ext
        }
        return result
    }

    /// Destination of the trailing `.anything` rule (where uncategorized files go),
    /// defaulting to "Other" to match `RuleEngine`.
    private static func catchAllDestination(in rules: [SortRule]) -> String {
        rules.last { $0.match == .anything }?.destination ?? "Other"
    }

    /// Would an existing enabled, non-catch-all rule already route `ext`? Probe with
    /// a synthetic filename so this honours every match kind, not just `.extensions`.
    private static func isCovered(_ ext: String, by rules: [SortRule]) -> Bool {
        let probe = FileMetadata(name: "sample.\(ext)")
        for rule in rules where rule.enabled {
            if rule.match == .anything { continue }
            if rule.match.matches(probe) { return true }
        }
        return false
    }

    private static func topLevel(_ destination: String) -> String {
        destination.split(separator: "/").first.map(String.init) ?? destination
    }
}
