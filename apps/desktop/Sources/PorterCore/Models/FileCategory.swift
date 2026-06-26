import Foundation

/// A destination category on the NAS. The `rawValue` is the default folder name
/// created under the NAS root when no case-variant already exists (the Sorter
/// resolves an existing folder case-insensitively before falling back to this).
///
/// Named `FileCategory` rather than `Category` because Foundation imports the
/// Objective-C runtime's `Category` typedef into scope, which would shadow it.
///
/// Mirrors `bin/sort-downloads`'s category map exactly — the extension lists in
/// `Classifier` are the source of truth for which files land where.
public enum FileCategory: String, CaseIterable, Sendable, Equatable {
    case screenshots = "screenshots"
    case pictures    = "Pictures"
    case pdfs        = "PDFs"
    case documents   = "Documents"
    case installers  = "Installers"
    case movies      = "Movies"
    case music       = "Music"
    case archives    = "Archives"
    case other       = "Other"

    /// Folder name on the NAS for this category.
    public var folderName: String { rawValue }

    /// SF Symbol used in the activity list.
    public var symbolName: String {
        switch self {
        case .screenshots: return "camera.viewfinder"
        case .pictures:    return "photo"
        case .pdfs:        return "doc.richtext"
        case .documents:   return "doc.text"
        case .installers:  return "shippingbox"
        case .movies:      return "film"
        case .music:       return "music.note"
        case .archives:    return "archivebox"
        case .other:       return "questionmark.folder"
        }
    }

    /// An SF Symbol for an arbitrary destination *folder name*. If it matches a
    /// built-in category's folder (case-insensitively) use that icon; otherwise a
    /// generic folder — so custom rule destinations still get a sensible glyph.
    public static func symbol(forFolder folder: String) -> String {
        let top = folder.split(separator: "/").first.map(String.init) ?? folder
        if let match = allCases.first(where: { $0.folderName.lowercased() == top.lowercased() }) {
            return match.symbolName
        }
        return "folder"
    }
}
