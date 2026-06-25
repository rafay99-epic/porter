import Foundation

/// Evaluates an ordered rule set against a file name to pick its destination
/// folder. First enabled rule that matches wins. Replaces the old hardcoded
/// `Classifier` switch — the same behaviour now lives in editable data
/// (`SortRule.defaults`).
public enum RuleEngine {
    /// Destination folder for `fileName`. Falls back to "Other" if no rule matches
    /// (defensive: the default set ends with an `.anything` catch-all, but a user
    /// could delete it).
    public static func destination(for fileName: String, using rules: [SortRule]) -> String {
        firstMatch(for: fileName, using: rules)?.destination ?? "Other"
    }

    /// The first enabled rule that matches `fileName`, or nil if none do. Powers the
    /// rule tester (which rule wins for a typed name) and keeps `destination(for:)`
    /// a thin wrapper so they can never disagree.
    public static func firstMatch(for fileName: String, using rules: [SortRule]) -> SortRule? {
        rules.first { $0.enabled && $0.match.matches(fileName) }
    }
}
