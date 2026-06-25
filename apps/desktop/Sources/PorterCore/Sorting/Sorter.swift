import Foundation

/// Result of one sweep over the watched sources.
public struct SweepSummary: Sendable, Equatable {
    public var moved = 0
    public var skipped = 0
    public var failed = 0
    /// Move/failure records, newest sweep's worth. Skips are not included.
    public var entries: [ActivityEntry] = []
    /// True when a source folder couldn't be *read* — almost always a missing
    /// Full Disk Access grant (the launchd-era silent `moved=0` failure). The
    /// coordinator surfaces this as a "grant access" prompt rather than letting
    /// it hide.
    public var readDenied = false

    public var didWork: Bool { moved > 0 || failed > 0 }
}

/// Orchestrates a single sweep: enumerate the top level of each source folder,
/// triage each entry, classify it, and hand eligible files to the `Mover`. Pure
/// apart from the filesystem moves themselves — no logging, no UI — so it can be
/// driven from a test against temp directories. The caller (SortCoordinator) is
/// responsible for only invoking it when the NAS is actually mounted.
public struct Sorter: Sendable {
    public let sources: [URL]
    public let mover: Mover
    public let settleSeconds: TimeInterval

    public init(sources: [URL], nasRoot: URL, settleSeconds: TimeInterval = 30) {
        self.sources = sources
        self.mover = Mover(nasRoot: nasRoot)
        self.settleSeconds = settleSeconds
    }

    /// Run a sweep. `onProgress(completed, total)` is called once up front with
    /// `completed == 0` (so a determinate bar can show the total immediately), then
    /// after each file moves — so the UI can show real progress. The callback is
    /// `@Sendable` because the sweep runs off the main actor.
    public func sweep(now: Date = Date(),
                      onProgress: (@Sendable (Int, Int) -> Void)? = nil) -> SweepSummary {
        var summary = SweepSummary()
        let fm = FileManager.default

        // Pass 1 — triage: figure out exactly which files are eligible to move.
        // Skips (junk / partial / dir / unsettled) are counted here, so the
        // progress total reflects only real work.
        var eligible: [EligibleFile] = []
        for source in sources {
            let contents: [URL]
            do {
                contents = try fm.contentsOfDirectory(
                    at: source,
                    includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                    options: [])
            } catch {
                let nsError = error as NSError
                if nsError.domain == NSCocoaErrorDomain || (error as? POSIXError)?.code == .EPERM
                    || nsError.code == 257 /* NSFileReadNoPermissionError */ {
                    summary.readDenied = true
                }
                continue
            }

            for url in contents {
                let name = url.lastPathComponent
                if FileTriage.isMacOSJunk(name) { continue }   // not counted, not logged
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
                if values?.isDirectory == true { summary.skipped += 1; continue }
                if FileTriage.isPartialOrHidden(name) { summary.skipped += 1; continue }
                let modified = values?.contentModificationDate ?? now
                if !FileTriage.isSettled(modified: modified, now: now, seconds: settleSeconds) {
                    summary.skipped += 1; continue
                }
                eligible.append(EligibleFile(url: url, name: name, category: Classifier.category(for: name)))
            }
        }

        // Pass 2 — move, reporting progress as we go.
        let total = eligible.count
        onProgress?(0, total)
        for (index, item) in eligible.enumerated() {
            do {
                let dest = try mover.move(item.url, to: item.category)
                summary.moved += 1
                summary.entries.append(ActivityEntry(
                    date: now, fileName: item.name, category: item.category,
                    outcome: .moved(folder: dest.deletingLastPathComponent().lastPathComponent)))
            } catch let Mover.MoveError.sourceNotRemoved(destination) {
                summary.failed += 1
                summary.entries.append(ActivityEntry(
                    date: now, fileName: item.name, category: item.category,
                    outcome: .failed(reason: "copied to \(destination.lastPathComponent) but couldn't remove original")))
            } catch {
                summary.failed += 1
                summary.entries.append(ActivityEntry(
                    date: now, fileName: item.name, category: item.category,
                    outcome: .failed(reason: describe(error))))
            }
            onProgress?(index + 1, total)
        }
        return summary
    }

    /// One file that passed triage and is queued to move.
    private struct EligibleFile {
        let url: URL
        let name: String
        let category: FileCategory
    }

    private func describe(_ error: Error) -> String {
        switch error {
        case Mover.MoveError.createDirectoryFailed(let p): return "couldn't create folder \(p)"
        case Mover.MoveError.copyFailed(let p):            return "copy to \(p) failed"
        case Mover.MoveError.renameFailed(let p):          return "rename to \(p) failed"
        default:                                           return error.localizedDescription
        }
    }
}
