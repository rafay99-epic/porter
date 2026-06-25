import Foundation

/// How a rule decides whether it applies to a file. Designed to be extensible —
/// adding a new kind is an isolated change here plus one `case` in `matches`.
/// `regex` is the open-ended escape hatch for any custom matching not covered by
/// the named kinds.
public enum RuleMatch: Codable, Equatable, Sendable {
    case extensions([String])     // by file extension (case-insensitive)
    case namePrefix(String)       // name starts with …  (e.g. "Screenshot ")
    case nameSuffix(String)       // name ends with …
    case nameContains(String)     // name contains …    (case-insensitive)
    case regex(String)            // full regex over the file name
    case anything                 // catch-all — always matches

    /// Does this match `fileName`? Invalid regex never matches (so a typo can't
    /// crash a sweep or swallow everything).
    public func matches(_ fileName: String) -> Bool {
        switch self {
        case .extensions(let exts):
            let ext = (fileName as NSString).pathExtension.lowercased()
            return !ext.isEmpty && exts.contains { $0.lowercased() == ext }
        case .namePrefix(let prefix):
            return !prefix.isEmpty && fileName.hasPrefix(prefix)
        case .nameSuffix(let suffix):
            return !suffix.isEmpty && fileName.hasSuffix(suffix)
        case .nameContains(let needle):
            return !needle.isEmpty && fileName.range(of: needle, options: .caseInsensitive) != nil
        case .regex(let pattern):
            guard !pattern.isEmpty, let regex = try? NSRegularExpression(pattern: pattern) else { return false }
            let range = NSRange(fileName.startIndex..., in: fileName)
            return regex.firstMatch(in: fileName, range: range) != nil
        case .anything:
            return true
        }
    }

    /// Short human label for the rules UI.
    public var summary: String {
        switch self {
        case .extensions(let exts): return exts.map { ".\($0)" }.joined(separator: " ")
        case .namePrefix(let p):    return "name starts with “\(p)”"
        case .nameSuffix(let s):    return "name ends with “\(s)”"
        case .nameContains(let c):  return "name contains “\(c)”"
        case .regex(let r):         return "matches /\(r)/"
        case .anything:             return "anything else"
        }
    }
}

/// What to do when a file with the same name already exists at the destination.
/// Per-rule, so e.g. an "Installers" rule can overwrite stale copies while
/// documents are kept side by side with a ` (1)` suffix.
public enum ConflictPolicy: String, Codable, CaseIterable, Identifiable, Sendable, Equatable {
    case rename      // keep both — add a Finder-style " (1)" suffix (the default)
    case skip        // leave the file in place, don't move it
    case overwrite   // replace whatever is already at the destination
    case keepNewer   // overwrite only if the incoming file is newer, else skip

    public var id: String { rawValue }

    /// Label for the rule editor picker.
    public var label: String {
        switch self {
        case .rename:    return "Keep both (rename)"
        case .skip:      return "Skip"
        case .overwrite: return "Overwrite"
        case .keepNewer: return "Keep newer"
        }
    }
}

/// One sorting rule: if `match` applies (and the rule is enabled), the file is
/// filed into `<NAS>/<destination>`. Rules are evaluated in list order; first
/// match wins. The list should end with an `.anything` rule as a safety net.
public struct SortRule: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var enabled: Bool
    public var match: RuleMatch
    /// Destination folder under the NAS root. May be nested ("Documents/Invoices").
    public var destination: String
    /// How to resolve a name clash at the destination.
    public var conflictPolicy: ConflictPolicy

    public init(id: UUID = UUID(), enabled: Bool = true, match: RuleMatch,
                destination: String, conflictPolicy: ConflictPolicy = .rename) {
        self.id = id
        self.enabled = enabled
        self.match = match
        self.destination = destination
        self.conflictPolicy = conflictPolicy
    }

    private enum CodingKeys: String, CodingKey {
        case id, enabled, match, destination, conflictPolicy
    }

    /// Lenient decode: every field has a fallback so adding a new key (like
    /// `conflictPolicy`) never invalidates an existing settings.json — old rules
    /// keep working with sensible defaults rather than the whole list resetting.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        match = try c.decode(RuleMatch.self, forKey: .match)
        destination = try c.decode(String.self, forKey: .destination)
        conflictPolicy = try c.decodeIfPresent(ConflictPolicy.self, forKey: .conflictPolicy) ?? .rename
    }
}

extension SortRule {
    /// The built-in default rule set — reproduces `bin/sort-downloads`'s classify()
    /// behaviour exactly. Seeded on first run; fully editable afterwards. Screenshot
    /// rule first (name beats extension), catch-all last.
    public static var defaults: [SortRule] {
        [
            SortRule(match: .namePrefix("Screenshot "), destination: "screenshots"),
            SortRule(match: .namePrefix("Screen Shot "), destination: "screenshots"),
            SortRule(match: .extensions(["jpg", "jpeg", "png", "gif", "webp", "heic", "heif",
                                         "tiff", "tif", "bmp", "svg", "raw", "cr2", "nef"]),
                     destination: "Pictures"),
            SortRule(match: .extensions(["pdf"]), destination: "PDFs"),
            SortRule(match: .extensions(["doc", "docx", "xls", "xlsx", "ppt", "pptx", "odt", "ods",
                                         "odp", "txt", "md", "rtf", "csv", "epub", "pages", "numbers", "key"]),
                     destination: "Documents"),
            SortRule(match: .extensions(["dmg", "pkg", "iso", "mpkg"]), destination: "Installers"),
            SortRule(match: .extensions(["mp4", "mov", "mkv", "webm", "avi", "m4v", "flv", "wmv"]),
                     destination: "Movies"),
            SortRule(match: .extensions(["mp3", "m4a", "wav", "flac", "ogg", "aac", "aiff"]),
                     destination: "Music"),
            SortRule(match: .extensions(["zip", "tar", "gz", "tgz", "bz2", "7z", "rar", "xz", "zst"]),
                     destination: "Archives"),
            SortRule(match: .anything, destination: "Other")
        ]
    }
}
