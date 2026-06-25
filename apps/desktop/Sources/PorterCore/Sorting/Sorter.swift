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
    /// True when the NAS appears to have unmounted mid-sweep (a move failed and the
    /// mount table no longer shows the root). The coordinator pauses and retries.
    public var nasLost = false

    public var didWork: Bool { moved > 0 || failed > 0 }
}

/// One move the Sorter *would* make — produced by `plan()` for the dry-run
/// preview, without touching any file.
public struct PlannedMove: Identifiable, Sendable, Equatable {
    public var id: String { sourcePath }
    /// Full path of the file in its watched folder.
    public let sourcePath: String
    public let name: String
    /// Destination folder under the NAS root (may be nested).
    public let destination: String

    public init(sourcePath: String, name: String, destination: String) {
        self.sourcePath = sourcePath
        self.name = name
        self.destination = destination
    }
}

/// Orchestrates a single sweep: enumerate the top level of each source folder,
/// triage each entry, classify it, and hand eligible files to the `Mover`. Pure
/// apart from the filesystem moves themselves — no logging, no UI — so it can be
/// driven from a test against temp directories. The caller (SortCoordinator) is
/// responsible for only invoking it when the NAS is actually mounted.
public struct Sorter: Sendable {
    public let sources: [WatchSource]
    public let rules: [SortRule]
    public let mover: Mover
    public let settleSeconds: TimeInterval

    public init(sources: [WatchSource], rules: [SortRule], nasRoot: URL, settleSeconds: TimeInterval = 30) {
        self.sources = sources
        self.rules = rules
        self.mover = Mover(nasRoot: nasRoot)
        self.settleSeconds = settleSeconds
    }

    /// Run a sweep. `onProgress(completed, total)` is called once up front with
    /// `completed == 0` (so a determinate bar can show the total immediately), then
    /// after each file moves — so the UI can show real progress. The callback is
    /// `@Sendable` because the sweep runs off the main actor.
    /// `ignoring` is a set of standardized file paths the caller wants left alone —
    /// used by "Undo" so a file the user just pulled back isn't re-sorted on the
    /// very next sweep. These are skipped silently (not counted, not logged).
    public func sweep(now: Date = Date(),
                      ignoring: Set<String> = [],
                      onProgress: (@Sendable (Int, Int) -> Void)? = nil) -> SweepSummary {
        var summary = SweepSummary()

        // Pass 1 — triage: figure out exactly which files are eligible to move.
        // Skips (junk / partial / dir / unsettled) are counted here, so the
        // progress total reflects only real work.
        let triaged = triage(now: now, ignoring: ignoring)
        let eligible = triaged.files
        summary.skipped = triaged.skipped
        summary.readDenied = triaged.readDenied

        // Pass 2 — move, reporting progress as we go.
        let total = eligible.count
        onProgress?(0, total)
        for (index, item) in eligible.enumerated() {
            do {
                let dest = try mover.move(item.url, to: item.destination, policy: item.policy)
                summary.moved += 1
                summary.entries.append(ActivityEntry(
                    date: now, fileName: item.name, destination: item.destination,
                    outcome: .moved(folder: dest.deletingLastPathComponent().lastPathComponent),
                    byteCount: item.size, sourcePath: item.url.path, finalPath: dest.path))
            } catch Mover.MoveError.skippedExisting {
                // Conflict policy (skip / keep-newer) chose to leave it in place —
                // a silent skip, exactly like a junk/partial skip. Not a failure.
                summary.skipped += 1
            } catch let Mover.MoveError.sourceNotRemoved(destination) {
                summary.failed += 1
                summary.entries.append(ActivityEntry(
                    date: now, fileName: item.name, destination: item.destination,
                    outcome: .failed(reason: "copied to \(destination.lastPathComponent) but couldn't remove original"),
                    sourcePath: item.url.path))
            } catch {
                summary.failed += 1
                summary.entries.append(ActivityEntry(
                    date: now, fileName: item.name, destination: item.destination,
                    outcome: .failed(reason: describe(error)),
                    sourcePath: item.url.path))
                // If the move failed because the NAS vanished mid-sweep, stop —
                // the coordinator will pause and retry when it's back.
                if !MountCheck.isMounted(mover.nasRoot) {
                    summary.nasLost = true
                    break
                }
            }
            onProgress?(index + 1, total)
        }
        return summary
    }

    /// Dry run: the moves a sweep *would* make right now, in the order it would
    /// make them, without touching any file. Same triage as `sweep` (settle delay,
    /// junk/partial skips, ignore set), so the preview matches reality. Settled
    /// files only — a still-downloading file won't appear until it would actually
    /// move.
    public func plan(now: Date = Date(), ignoring: Set<String> = []) -> [PlannedMove] {
        triage(now: now, ignoring: ignoring).files.map {
            PlannedMove(sourcePath: $0.url.path, name: $0.name, destination: $0.destination)
        }
    }

    /// Outcome of pass-1 triage: the files to move plus the bookkeeping a sweep
    /// needs (skip count, whether a source was unreadable).
    private struct TriageResult {
        var files: [EligibleFile] = []
        var skipped = 0
        var readDenied = false
    }

    /// Shared pass-1 triage used by both `sweep` and `plan`. Pure (read-only):
    /// enumerate each enabled source, drop junk/partial/dirs/unsettled/ignored, and
    /// resolve each survivor's destination.
    private func triage(now: Date, ignoring: Set<String>) -> TriageResult {
        let fm = FileManager.default
        var result = TriageResult()
        for source in sources where source.enabled {
            let collected: (files: [URL], skippedDirs: Int)
            do {
                collected = try collectFiles(in: source, fm: fm)
            } catch {
                let nsError = error as NSError
                // 257 = no read permission (TCC) → surface as readDenied.
                // 260 = no such file (source deleted/moved) → skip silently.
                if nsError.code == 257 || (error as? POSIXError)?.code == .EPERM {
                    result.readDenied = true
                }
                continue
            }
            result.skipped += collected.skippedDirs

            for url in collected.files {
                let name = url.lastPathComponent
                if FileTriage.isMacOSJunk(name) { continue }   // not counted, not logged
                if ignoring.contains(url.standardizedFileURL.path) { continue }   // pulled back by Undo
                let values = try? url.resourceValues(forKeys: [
                    .contentModificationDateKey, .fileSizeKey, .contentTypeKey])
                if FileTriage.isPartialOrHidden(name) { result.skipped += 1; continue }
                let modified = values?.contentModificationDate ?? now
                if !FileTriage.isSettled(modified: modified, now: now, seconds: settleSeconds) {
                    result.skipped += 1; continue
                }
                let meta = FileMetadata(name: name, size: Int64(values?.fileSize ?? 0),
                                        modified: modified,
                                        contentTypeIdentifier: values?.contentType?.identifier)
                let routed = routing(for: meta, now: now, source: source)
                // Expand date tokens ({yyyy}/{MM}…) against the file's own date.
                let destination = DestinationTemplate.expand(routed.destination, date: modified)
                result.files.append(EligibleFile(url: url, name: name, destination: destination,
                                                 policy: routed.policy, size: meta.size))
            }
        }
        return result
    }

    /// Gather the candidate *files* in a source — shallow (top level only) or, when
    /// the source opts in, recursively through subfolders. Directories are never
    /// returned; in shallow mode a top-level directory counts as one skip (matching
    /// the original behaviour), while recursive mode just descends into them.
    /// macOS junk and hidden files are excluded up front. Throws on a read error so
    /// the caller can flag `readDenied`.
    private func collectFiles(in source: WatchSource, fm: FileManager) throws -> (files: [URL], skippedDirs: Int) {
        let keys: [URLResourceKey] = [.isDirectoryKey]
        if source.recursive {
            guard let enumerator = fm.enumerator(
                at: source.url, includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
                throw CocoaError(.fileReadNoSuchFile)
            }
            var files: [URL] = []
            for case let url as URL in enumerator {
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if !isDir { files.append(url) }
            }
            return (files, 0)
        } else {
            let contents = try fm.contentsOfDirectory(
                at: source.url, includingPropertiesForKeys: keys, options: [])
            var files: [URL] = []
            var skippedDirs = 0
            for url in contents {
                if FileTriage.isMacOSJunk(url.lastPathComponent) { continue }   // not counted
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if isDir { skippedDirs += 1 } else { files.append(url) }
            }
            return (files, skippedDirs)
        }
    }

    /// Destination + conflict policy for `name` under this source's routing. A
    /// fixed source has no rule, so it keeps both copies (`.rename`) — the safe
    /// default; classify sources inherit the winning rule's policy.
    private func routing(for meta: FileMetadata, now: Date, source: WatchSource) -> (destination: String, policy: ConflictPolicy) {
        switch source.routing {
        case .fixed(let folder):
            return (folder, .rename)
        case .classify:
            if let rule = RuleEngine.firstMatch(for: meta, now: now, using: rules) {
                return (rule.destination, rule.conflictPolicy)
            }
            return ("Other", .rename)
        }
    }

    /// One file that passed triage and is queued to move.
    private struct EligibleFile {
        let url: URL
        let name: String
        let destination: String
        let policy: ConflictPolicy
        let size: Int64
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
