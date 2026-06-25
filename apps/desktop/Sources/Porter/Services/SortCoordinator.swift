import Foundation
import AppKit
import Observation
import PorterCore

/// The single visible state of the app, surfaced as the menu-bar icon.
enum PorterStatus: Equatable {
    case idle               // watching, nothing to do
    case syncing            // a sweep is in flight
    case sorted(Int)        // transient confirmation after a sweep moved files
    case paused             // NAS not mounted
    case suspended(String)  // intentionally not sorting (user pause / quiet hours)
    case needsPermission    // can't read the source folder (Full Disk Access)
    case error(String)      // last sweep had failures

    /// SF Symbol for the menu-bar item. The shape carries the state (menu-bar
    /// rendering is monochrome), so each status is visually distinct without color.
    var symbolName: String {
        switch self {
        case .idle:            return "tray.and.arrow.down"
        case .syncing:         return "arrow.triangle.2.circlepath"
        case .sorted:          return "checkmark.circle.fill"
        case .paused:          return "externaldrive.badge.xmark"
        case .suspended:       return "pause.circle"
        case .needsPermission: return "lock.shield"
        case .error:           return "exclamationmark.triangle"
        }
    }

    var title: String {
        switch self {
        case .idle:            return "Watching for new files"
        case .syncing:         return "Sorting…"
        case .sorted(let n):   return "Sorted \(n) file\(n == 1 ? "" : "s")"
        case .paused:          return "NAS not mounted"
        case .suspended(let m): return m
        case .needsPermission: return "Needs file access"
        case .error(let msg):  return msg
        }
    }
}

/// Live progress of an in-flight sweep, for a determinate progress bar.
struct SortProgress: Equatable {
    var completed: Int
    var total: Int
    var fraction: Double { total > 0 ? Double(completed) / Double(total) : 0 }
}

/// The brain: owns the in-process folder watcher, the mount-state observers, the
/// periodic safety sweep, and the activity log. Everything the UI shows is derived
/// from `@Observable` properties here. Runs entirely in the app's GUI session, so
/// the moves it triggers can write to the SMB share.
@MainActor
@Observable
final class SortCoordinator {
    private(set) var status: PorterStatus = .idle {
        didSet {
            guard status != oldValue else { return }
            log.info("status → \(status.title)")
        }
    }
    private(set) var nasMounted = false {
        didSet {
            guard nasMounted != oldValue else { return }
            log.notice(nasMounted ? "NAS mounted at \(settings.nasMountPath)" : "NAS unmounted from \(settings.nasMountPath)")
        }
    }
    private(set) var lastSweepAt: Date?
    private(set) var totalMoved = 0
    private(set) var totalFailed = 0
    /// Newest-first, capped. Skips are never recorded — only moves and failures.
    private(set) var activity: [ActivityEntry] = []
    /// Live progress while a sweep moves files (nil when idle).
    private(set) var progress: SortProgress?

    let settings: PorterSettings

    private let log = AppInfo.logger("coordinator")
    private let notifier = Notifier()
    private let statsStore = StatsStore(directory: Channel.current.statsDirectory)
    private let watcherQueue = DispatchQueue(label: "\(AppInfo.bundleIdentifier).watcher", qos: .utility)
    private var watcher: FolderWatcher?
    private var debounceTask: Task<Void, Never>?
    private var heartbeat: Task<Void, Never>?
    private var started = false
    private var isSweeping = false
    private var resweepQueued = false
    private var sortedRevertTask: Task<Void, Never>?
    /// Standardized paths of files the user pulled back with "Undo" — skipped by the
    /// next sweeps so they aren't immediately re-sorted. Pruned of vanished paths
    /// each sweep (once the user moves the file away it drops out naturally).
    private var ignoredPaths: Set<String> = []

    private static let activityCap = 100

    init(settings: PorterSettings) {
        self.settings = settings
    }

    // MARK: - Lifecycle

    func start() {
        guard !started else { return }
        started = true
        FileLog.shared.pruneOldLogs()
        log.info("\(Channel.current.displayName) launched — watching \(settings.activeSourceURLs.count) folder(s), filing to \(settings.nasMountPath)")
        if settings.notificationsEnabled { notifier.requestAuthorizationIfNeeded() }
        observeVolumeChanges()
        startWatching()
        startHeartbeat()
        Task { await requestSweep() }
    }

    /// Re-point the watcher and run a sweep — called after the user edits the
    /// source folder in Settings.
    func reconfigure() {
        startWatching()
        Task { await requestSweep() }
    }

    /// User pressed "Sort Now".
    func sortNow() {
        Task { await requestSweep() }
    }

    var isPaused: Bool { settings.paused }

    /// Toggle the global pause. Resuming kicks off a sweep immediately so a backlog
    /// that built up while paused is cleared right away.
    func setPaused(_ paused: Bool) {
        guard settings.paused != paused else { return }
        settings.paused = paused
        if paused {
            status = .suspended("Paused")
            log.info("sorting paused by user")
        } else {
            log.info("sorting resumed by user")
            Task { await requestSweep() }
        }
    }

    // MARK: - Watching

    private func startWatching() {
        watcher?.stop()
        let folders = settings.activeSourceURLs
        let w = FolderWatcher(folders: folders, queue: watcherQueue) { [weak self] paths in
            Task { @MainActor in self?.fileSystemChanged(paths) }
        }
        w.start()
        watcher = w
        let names = folders.map(\.lastPathComponent).joined(separator: ", ")
        log.info("watching \(folders.count) folder(s): \(names.isEmpty ? "(none)" : names)")
    }

    private func fileSystemChanged(_ paths: [String] = []) {
        log.debug("fsevent: \(paths.count) path(s) changed")
        // Debounce a burst of events into one sweep ~1s later. The per-file settle
        // check still protects against grabbing a download that's mid-write.
        let delay = max(0.1, settings.debounceSeconds)
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if Task.isCancelled { return }
            await self?.requestSweep()
        }
    }

    private func startHeartbeat() {
        // Safety net: a sweep at least once every `heartbeatSeconds` regardless of
        // fsevents. Unlike the launchd era this is a plain in-process timer — not
        // subject to WatchPaths death or StartInterval throttling. Interval is
        // config-driven (PorterSettings), not hardcoded.
        heartbeat = Task { [weak self] in
            while !Task.isCancelled {
                let interval = self?.settings.heartbeatSeconds ?? 60
                try? await Task.sleep(nanoseconds: UInt64(max(5, interval) * 1_000_000_000))
                await self?.requestSweep()
            }
        }
    }

    private func observeVolumeChanges() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in await self?.requestSweep() }
            }
        }
    }

    // MARK: - Sweeping (single-flight)

    private func requestSweep() async {
        guard !isSweeping else { resweepQueued = true; return }
        await runSweep()
        while resweepQueued {
            resweepQueued = false
            await runSweep()
        }
    }

    private func runSweep() async {
        // Intentional suspension takes precedence over everything: a user pause or
        // an active quiet-hours window means "don't touch files", full stop.
        if settings.paused {
            status = .suspended("Paused")
            return
        }
        if settings.quietHours.isQuiet(at: Date()) {
            status = .suspended("Quiet hours until \(settings.quietHours.endLabel)")
            return
        }

        // Probe file access FIRST — independent of the NAS. This is what triggers
        // the Downloads TCC prompt on first launch, and it surfaces a missing grant
        // even while the share is offline (a paused-but-also-unreadable app would
        // otherwise hide the real blocker behind "NAS not mounted").
        // Permission: if any enabled source can't be read (TCC), surface it.
        if let blocked = settings.activeSourceURLs.first(where: { !Permissions.canRead($0) }) {
            if status != .needsPermission {
                log.error("cannot read \(blocked.path) — grant Porter access to that folder (or Full Disk Access) in System Settings")
            }
            status = .needsPermission
            return
        }
        nasMounted = MountCheck.isMounted(settings.nasMountPath)
        guard nasMounted else {
            status = .paused
            return
        }

        isSweeping = true
        status = .syncing
        progress = nil
        // Drop ignore entries whose file is gone (user dealt with it) so the set
        // doesn't grow unbounded.
        ignoredPaths = ignoredPaths.filter { FileManager.default.fileExists(atPath: $0) }
        let sources = settings.sources
        let rules = settings.rules
        let nasRoot = settings.nasURL
        let settle = settings.settleSeconds
        let ignoring = ignoredPaths
        // Capture self strongly: it's a @MainActor (Sendable) object and the task is
        // short-lived, so there's no cycle and the @Sendable progress callback can
        // hop back to the main actor to publish progress.
        let coordinator = self
        let summary = await Task.detached(priority: .utility) {
            Sorter(sources: sources, rules: rules, nasRoot: nasRoot, settleSeconds: settle).sweep(ignoring: ignoring) { completed, total in
                Task { @MainActor in
                    coordinator.progress = total > 0 ? SortProgress(completed: completed, total: total) : nil
                }
            }
        }.value
        isSweeping = false
        progress = nil
        apply(summary)
    }

    private func apply(_ summary: SweepSummary) {
        lastSweepAt = Date()
        totalMoved += summary.moved
        totalFailed += summary.failed

        if !summary.entries.isEmpty {
            activity.insert(contentsOf: summary.entries.reversed(), at: 0)
            if activity.count > Self.activityCap {
                activity.removeLast(activity.count - Self.activityCap)
            }
            for entry in summary.entries {
                switch entry.outcome {
                case .moved(let folder):
                    log.info("moved \(entry.fileName) → \(folder)/")
                case .failed(let reason):
                    log.error("FAILED \(entry.fileName): \(reason)")
                }
            }
        }

        if summary.nasLost {
            // The share vanished mid-sweep — pause; the mount observer / heartbeat
            // resumes when it's back.
            nasMounted = false
            status = .paused
        } else if summary.readDenied {
            status = .needsPermission
        } else if summary.failed > 0 {
            status = .error("\(summary.failed) move\(summary.failed == 1 ? "" : "s") failed")
        } else if summary.moved > 0 {
            showSortedConfirmation(summary.moved)
        } else {
            status = .idle
        }

        if summary.didWork {
            log.info("sweep done — moved \(summary.moved) failed \(summary.failed) skipped \(summary.skipped)")
            if settings.notificationsEnabled {
                notifier.notifySorted(summary.moved)
                notifier.notifyFailures(summary.failed)
            }
            recordStats(from: summary)
        }
    }

    /// Persist one StatRecord per successful move for the stats dashboard. Done off
    /// the main actor — stats are best-effort and must never block a sweep.
    private func recordStats(from summary: SweepSummary) {
        let records: [StatRecord] = summary.entries.compactMap { entry in
            guard case .moved = entry.outcome, let destination = entry.destination else { return nil }
            return StatRecord(date: entry.date,
                              category: StatsStore.category(fromDestination: destination),
                              bytes: entry.byteCount)
        }
        guard !records.isEmpty else { return }
        let store = statsStore
        Task.detached(priority: .utility) { store.append(records) }
    }

    /// Load the full persisted move history for the stats dashboard.
    func loadStats() async -> [StatRecord] {
        let store = statsStore
        return await Task.detached(priority: .userInitiated) { store.load() }.value
    }

    /// Briefly show a "Sorted N" confirmation (icon + title go green/check), then
    /// fall back to idle — so a fast sweep doesn't just silently flash by.
    private func showSortedConfirmation(_ count: Int) {
        status = .sorted(count)
        sortedRevertTask?.cancel()
        sortedRevertTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled, let self else { return }
            if case .sorted = self.status { self.status = .idle }
        }
    }

    // MARK: - Dry-run preview

    /// Compute the moves a sweep would make right now, without touching any file.
    /// Runs the same triage off the main actor so a big folder doesn't hitch the UI.
    func previewPlan() async -> [PlannedMove] {
        let sources = settings.sources
        let rules = settings.rules
        let nasRoot = settings.nasURL
        let settle = settings.settleSeconds
        let ignoring = ignoredPaths
        return await Task.detached(priority: .userInitiated) {
            Sorter(sources: sources, rules: rules, nasRoot: nasRoot, settleSeconds: settle)
                .plan(ignoring: ignoring)
        }.value
    }

    // MARK: - Undo

    /// Move a sorted file back to the folder it came from. Best-effort: uses the
    /// same xattr-stripping copy as the forward move (so the trip back over SMB
    /// also succeeds). The restored file is added to `ignoredPaths` so the next
    /// sweep doesn't just re-file it. Marks the activity row as undone on success.
    func undo(_ entry: ActivityEntry) {
        guard entry.canUndo,
              let finalPath = entry.finalPath,
              let sourcePath = entry.sourcePath else { return }
        let from = URL(fileURLWithPath: finalPath)
        let destDir = URL(fileURLWithPath: sourcePath).deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: finalPath) else {
            log.error("undo: \(entry.fileName) is no longer at \(finalPath)")
            return
        }
        let nasRoot = settings.nasURL
        Task {
            let restored: URL? = await Task.detached(priority: .userInitiated) {
                try? Mover(nasRoot: nasRoot).move(from, intoDirectory: destDir)
            }.value
            guard let restored else {
                status = .error("Couldn't move \(entry.fileName) back")
                log.error("undo failed for \(entry.fileName)")
                return
            }
            ignoredPaths.insert(restored.standardizedFileURL.path)
            if let idx = activity.firstIndex(where: { $0.id == entry.id }) {
                activity[idx].undone = true
            }
            if totalMoved > 0 { totalMoved -= 1 }
            log.info("undo: moved \(entry.fileName) back to \(destDir.lastPathComponent)/")
        }
    }

    // MARK: - Actions for the UI

    /// Ask Finder to mount the configured SMB URL (same path the old `.inetloc`
    /// used, so the saved Keychain credential just works). Falls back to revealing
    /// the mountpoint in Finder when no SMB URL is configured.
    func mountNow() {
        let smb = settings.smbURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !smb.isEmpty else {
            NSWorkspace.shared.open(settings.nasURL)
            return
        }
        Task.detached {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            proc.arguments = ["-e", "tell application \"Finder\" to mount volume \"\(smb)\""]
            try? proc.run()
            proc.waitUntilExit()
            await self.requestSweep()
        }
    }

    /// Called when the user flips notifications on in Settings — prompts for the
    /// system grant if we haven't asked yet.
    func enableNotifications() { notifier.requestAuthorizationIfNeeded() }

    func revealLogInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([FileLog.shared.currentLogFileURL()])
    }

    /// Open the NAS location in Finder — the mount point if it exists, otherwise
    /// `/Volumes` so the user can find/click the share manually.
    func revealNAS() {
        let url = settings.nasURL
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/Volumes"))
        }
    }

    func openFullDiskAccessSettings() { Permissions.openFullDiskAccessSettings() }
}
