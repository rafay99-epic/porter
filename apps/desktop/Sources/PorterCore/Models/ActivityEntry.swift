import Foundation

/// One line in the activity log: a file that was moved, or a move that failed.
/// Skips (junk, partial, unsettled) are deliberately NOT recorded — they're noise,
/// exactly as `bin/sort-downloads` never logged them.
public struct ActivityEntry: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let date: Date
    public let fileName: String
    /// Destination folder on the NAS (the rule/routing decision). Drives the row
    /// icon via `FileCategory.symbol(forFolder:)`.
    public let destination: String?
    public let outcome: Outcome
    /// Full path the file was moved *from* — the watched-folder location. Needed to
    /// put it back on "Undo". Nil when unknown (older entries).
    public let sourcePath: String?
    /// Full path the file now lives at on the NAS after a successful move. Nil for
    /// failures and older entries.
    public let finalPath: String?
    /// Set true once the user has pulled this move back to its source.
    public var undone: Bool

    public enum Outcome: Sendable, Equatable {
        case moved(folder: String)
        case failed(reason: String)
    }

    public init(id: UUID = UUID(), date: Date, fileName: String,
                destination: String?, outcome: Outcome,
                sourcePath: String? = nil, finalPath: String? = nil, undone: Bool = false) {
        self.id = id
        self.date = date
        self.fileName = fileName
        self.destination = destination
        self.outcome = outcome
        self.sourcePath = sourcePath
        self.finalPath = finalPath
        self.undone = undone
    }

    public var isFailure: Bool {
        if case .failed = outcome { return true }
        return false
    }

    /// Whether a one-click "move it back" is possible: a successful move we still
    /// know both ends of, that hasn't already been undone.
    public var canUndo: Bool {
        if case .moved = outcome {
            return !undone && sourcePath != nil && finalPath != nil
        }
        return false
    }
}
