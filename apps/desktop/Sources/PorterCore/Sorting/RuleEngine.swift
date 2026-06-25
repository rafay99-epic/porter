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
        for rule in rules where rule.enabled && rule.match.matches(fileName) {
            return rule.destination
        }
        return "Other"
    }
}
