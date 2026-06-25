import Foundation
import CoreServices

/// Thin wrapper over an `FSEventStream` watching a single folder for file-level
/// changes. Reports the changed paths on `queue`; the coordinator decides what to
/// do with them (debounce, then sweep). Start/stop are idempotent so the folder
/// can be re-pointed when settings change.
///
/// Ported from Crisp's `CrispWatcher.FolderWatcher`. The crucial difference in
/// Porter is *where this runs*: in-process inside the menu-bar app (a login-item
/// app in the full Aqua GUI session), never a launchd agent — so the moves the
/// callback ultimately triggers can write to the Finder-mounted SMB share.
public final class FolderWatcher {
    private let folders: [URL]
    private let queue: DispatchQueue
    private let onPaths: ([String]) -> Void
    private var stream: FSEventStreamRef?

    /// Watch one or more folders with a single FSEvents stream (the stream accepts
    /// an array of paths). Empty `folders` is a no-op.
    public init(folders: [URL], queue: DispatchQueue, onPaths: @escaping ([String]) -> Void) {
        self.folders = folders
        self.queue = queue
        self.onPaths = onPaths
    }

    public func start() {
        guard stream == nil, !folders.isEmpty else { return }
        let callback: FSEventStreamCallback = { _, info, count, pathsPtr, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue()
            let paths = unsafeBitCast(pathsPtr, to: CFArray.self) as? [String] ?? []
            if !paths.isEmpty { watcher.onPaths(paths) }
            _ = count
        }
        var context = FSEventStreamContext(version: 0,
                                           info: Unmanaged.passUnretained(self).toOpaque(),
                                           retain: nil, release: nil, copyDescription: nil)
        let flags = UInt32(kFSEventStreamCreateFlagFileEvents
                           | kFSEventStreamCreateFlagUseCFTypes
                           | kFSEventStreamCreateFlagNoDefer)
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault, callback, &context,
            folders.map(\.path) as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,                         // coalesce bursts over 1s
            flags) else { return }
        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    public func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit { stop() }
}
