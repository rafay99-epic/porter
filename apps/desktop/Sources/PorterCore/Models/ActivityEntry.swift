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

    public enum Outcome: Sendable, Equatable {
        case moved(folder: String)
        case failed(reason: String)
    }

    public init(id: UUID = UUID(), date: Date, fileName: String,
                destination: String?, outcome: Outcome) {
        self.id = id
        self.date = date
        self.fileName = fileName
        self.destination = destination
        self.outcome = outcome
    }

    public var isFailure: Bool {
        if case .failed = outcome { return true }
        return false
    }
}
