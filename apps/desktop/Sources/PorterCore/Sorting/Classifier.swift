import Foundation

/// Maps a file name to its destination `Category`, purely by name/extension —
/// a direct port of `classify()` in `bin/sort-downloads`. No I/O, so it's trivial
/// to unit-test the whole map.
public enum Classifier {
    /// Screenshots are matched by name *before* extension classification, so a
    /// `Screenshot 2026-… .png` that lands in Downloads routes to `screenshots/`
    /// rather than `Pictures/`.
    public static func isScreenshotName(_ name: String) -> Bool {
        name.hasPrefix("Screenshot ") || name.hasPrefix("Screen Shot ")
    }

    public static func category(for name: String) -> FileCategory {
        if isScreenshotName(name) { return .screenshots }

        // No extension (no dot, or a leading-dot dotfile with nothing after) → Other.
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else {
            return .other
        }
        let ext = String(name[name.index(after: dot)...]).lowercased()

        switch ext {
        case "jpg", "jpeg", "png", "gif", "webp", "heic", "heif",
             "tiff", "tif", "bmp", "svg", "raw", "cr2", "nef":
            return .pictures
        case "pdf":
            return .pdfs
        case "doc", "docx", "xls", "xlsx", "ppt", "pptx", "odt", "ods", "odp",
             "txt", "md", "rtf", "csv", "epub", "pages", "numbers", "key":
            return .documents
        case "dmg", "pkg", "iso", "mpkg":
            return .installers
        case "mp4", "mov", "mkv", "webm", "avi", "m4v", "flv", "wmv":
            return .movies
        case "mp3", "m4a", "wav", "flac", "ogg", "aac", "aiff":
            return .music
        case "zip", "tar", "gz", "tgz", "bz2", "7z", "rar", "xz", "zst":
            return .archives
        default:
            return .other
        }
    }
}
