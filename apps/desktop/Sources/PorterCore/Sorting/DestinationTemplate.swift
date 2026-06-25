import Foundation

/// Expands date tokens in a destination string so a rule can file into
/// date-based subfolders, e.g. `Movies/{yyyy}/{MM}` → `Movies/2026/06`.
///
/// Anything inside `{…}` is treated as a `DateFormatter` pattern and rendered
/// against the file's date (its modification time — i.e. roughly when it was
/// downloaded). Text outside braces is copied verbatim, so `/` between tokens
/// still nests folders the way `Mover` expects. Common patterns:
///   {yyyy} → 2026   {MM} → 06   {MMMM} → June   {dd} → 26   {yyyy-MM} → 2026-06
public enum DestinationTemplate {
    /// True if `template` contains at least one `{…}` token worth expanding.
    public static func hasTokens(_ template: String) -> Bool {
        guard let open = template.firstIndex(of: "{") else { return false }
        return template[open...].contains("}")
    }

    /// Render `template` for `date`. Returns it unchanged when there are no tokens.
    public static func expand(_ template: String, date: Date,
                              calendar: Calendar = .current,
                              locale: Locale = .current) -> String {
        guard template.contains("{") else { return template }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone

        var result = ""
        var index = template.startIndex
        while index < template.endIndex {
            let char = template[index]
            if char == "{", let close = template[index...].firstIndex(of: "}") {
                let token = String(template[template.index(after: index)..<close])
                if token.isEmpty {
                    // Literal "{}" — keep it rather than emit nothing.
                    result += "{}"
                } else {
                    formatter.dateFormat = token
                    result += formatter.string(from: date)
                }
                index = template.index(after: close)
            } else {
                result.append(char)
                index = template.index(after: index)
            }
        }
        return result
    }
}
