import Foundation
import UniformTypeIdentifiers

/// The facts about a file a rule can match against. Built once per file during
/// triage and passed to `RuleMatch.matches`, so size/age/kind conditions don't
/// each re-stat the file. Kept a plain value type (no URL) so matching stays pure
/// and testable.
public struct FileMetadata: Sendable, Equatable {
    public var name: String
    /// Size in bytes (0 when unknown).
    public var size: Int64
    /// Content modification time — roughly "when it was downloaded".
    public var modified: Date
    /// UTType identifier (e.g. "public.jpeg"), when the system could resolve one.
    public var contentTypeIdentifier: String?

    public init(name: String, size: Int64 = 0, modified: Date = Date(),
                contentTypeIdentifier: String? = nil) {
        self.name = name
        self.size = size
        self.modified = modified
        self.contentTypeIdentifier = contentTypeIdentifier
    }

    /// Resolved `UTType`: the system-provided identifier if present, else inferred
    /// from the filename extension. Nil when neither yields a type.
    public var contentType: UTType? {
        if let id = contentTypeIdentifier, let type = UTType(id) { return type }
        let ext = (name as NSString).pathExtension
        return ext.isEmpty ? nil : UTType(filenameExtension: ext)
    }
}

/// A coarse, friendly file kind a rule can match on — resolved through the
/// system's UTI hierarchy, so "Image" catches jpg/png/heic/raw/… without listing
/// every extension.
public enum FileKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case image, video, audio, pdf, archive, sourceCode, spreadsheet

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .image:       return "Image"
        case .video:       return "Video"
        case .audio:       return "Audio"
        case .pdf:         return "PDF"
        case .archive:     return "Archive"
        case .sourceCode:  return "Source code"
        case .spreadsheet: return "Spreadsheet"
        }
    }

    /// The umbrella UTType this kind tests conformance against.
    var utType: UTType {
        switch self {
        case .image:       return .image
        case .video:       return .movie
        case .audio:       return .audio
        case .pdf:         return .pdf
        case .archive:     return .archive
        case .sourceCode:  return .sourceCode
        case .spreadsheet: return .spreadsheet
        }
    }

    /// Does `meta`'s resolved content type conform to this kind?
    public func matches(_ meta: FileMetadata) -> Bool {
        guard let type = meta.contentType else { return false }
        return type.conforms(to: utType)
    }
}
