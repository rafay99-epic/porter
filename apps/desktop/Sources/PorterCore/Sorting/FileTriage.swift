import Foundation

/// Name- and age-based predicates that decide whether a file in a watched folder
/// is eligible to be moved at all. Ported from the guard clauses in
/// `bin/sort-downloads` — kept pure (name + mtime in, Bool out) so every rule is
/// unit-testable without touching the filesystem.
public enum FileTriage {
    /// macOS sprinkles metadata files into every directory it touches. We never
    /// move, log, or even count these — they're treated as if absent. Covers
    /// `.DS_Store`, the `.localized` marker, AppleDouble shadows (`._*`), the
    /// custom-icon file (`Icon\r`), and the per-volume system dirs.
    public static func isMacOSJunk(_ name: String) -> Bool {
        switch name {
        case ".DS_Store", ".localized", ".Spotlight-V100", ".Trashes",
             ".fseventsd", ".TemporaryItems", ".DocumentRevisions-V100", ".apdisk":
            return true
        case "Icon\r":
            return true
        default:
            return name.hasPrefix("._")
        }
    }

    /// Partial / in-flight downloads (and any other dotfile) — skip until done.
    /// Matches the `is_partial` helper: leading-dot files plus the common
    /// browser/download-manager temp suffixes.
    public static func isPartialOrHidden(_ name: String) -> Bool {
        if name.hasPrefix(".") { return true }
        let partialSuffixes = [".crdownload", ".download", ".part", ".tmp", ".aria2", ".opdownload"]
        let lower = name.lowercased()
        return partialSuffixes.contains { lower.hasSuffix($0) }
    }

    /// A file is "settled" once it hasn't been modified for `seconds` — protects
    /// against grabbing a download that's still being written. `modified` is the
    /// file's mtime; `now` is injected so tests are deterministic.
    public static func isSettled(modified: Date, now: Date, seconds: TimeInterval) -> Bool {
        now.timeIntervalSince(modified) >= seconds
    }
}
