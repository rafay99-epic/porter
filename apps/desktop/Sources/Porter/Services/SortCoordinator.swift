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
    private let watcherQueue = DispatchQueue(label: "\(AppInfo.bundleIdentifier).watcher", qos: .utility)
    private var watcher: FolderWatcher?
    private var debounceTask: Task<Void, Never>?
    private var heartbeat: Task<Void, Never>?
    private var started = false
    private var isSweeping = false
    private var resweepQueued = false
    private var sortedRevertTask: Task<Void, Never>?

    private static let activityCap = 100

    init(settings: PorterSettings) {
        self.settings = settings
    }

    // MARK: - Lifecycle

    func start() {
        guard !started else { return }
        started = true
        FileLog.shared.pruneOldLogs()
        log.info("\(Channel.current.displayName) launched — watching \(settings.sourcePath), filing to \(settings.nasMountPath)")
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

    // MARK: - Watching

    private func startWatching() {
        watcher?.stop()
        let w = FolderWatcher(folder: settings.sourceURL, queue: watcherQueue) { [weak self] paths in
            Task { @MainActor in self?.fileSystemChanged(paths) }
        }
        w.start()
        watcher = w
        log.info("watching \(settings.sourcePath)")
    }

    private func fileSystemChanged(_ paths: [String] = []) {
        log.debug("fsevent: \(paths.count) path(s) changed in \(settings.sourcePath)")
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
        // Probe file access FIRST — independent of the NAS. This is what triggers
        // the Downloads TCC prompt on first launch, and it surfaces a missing grant
        // even while the share is offline (a paused-but-also-unreadable app would
        // otherwise hide the real blocker behind "NAS not mounted").
        guard Permissions.canRead(settings.sourceURL) else {
            if status != .needsPermission {
                log.error("cannot read \(settings.sourcePath) — grant Porter access to that folder (or Full Disk Access) in System Settings")
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
        let sources = [settings.sourceURL]
        let nasRoot = settings.nasURL
        let settle = settings.settleSeconds
        // Capture self strongly: it's a @MainActor (Sendable) object and the task is
        // short-lived, so there's no cycle and the @Sendable progress callback can
        // hop back to the main actor to publish progress.
        let coordinator = self
        let summary = await Task.detached(priority: .utility) {
            Sorter(sources: sources, nasRoot: nasRoot, settleSeconds: settle).sweep { completed, total in
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

        if summary.readDenied {
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
        }
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
