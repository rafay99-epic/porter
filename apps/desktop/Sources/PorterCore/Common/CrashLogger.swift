import Foundation

/// Best-effort crash breadcrumbs in the daily log. Installs an uncaught-exception
/// handler (catches ObjC/`NSException` crashes) and POSIX signal handlers
/// (SIGSEGV/SIGABRT/…), each of which writes a line to today's log file before the
/// process dies — so a crash leaves a trace right after the last normal event,
/// instead of vanishing silently. Call `install()` once at launch.
///
/// The signal path keeps to low-level `write(2)` on a pre-opened fd (the Swift
/// logging stack isn't async-signal-safe); it's a breadcrumb, not a full report.
public enum CrashLogger {
    nonisolated(unsafe) private static var fd: Int32 = -1
    nonisolated(unsafe) private static var installed = false

    public static func install() {
        guard !installed else { return }
        installed = true

        let dir = Channel.current.logsDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        let url = dir.appendingPathComponent("\(f.string(from: Date())).log")
        fd = open(url.path, O_WRONLY | O_APPEND | O_CREAT, 0o600)

        NSSetUncaughtExceptionHandler { exception in
            let stack = exception.callStackSymbols.joined(separator: "\n")
            let message = "UNCAUGHT EXCEPTION \(exception.name.rawValue): \(exception.reason ?? "(no reason)")\n\(stack)"
            // Normal context here — the full logging stack is safe to use.
            FileLog.shared.write(level: .error, category: "crash", message: message)
            CrashLogger.writeRaw("\nCRASH \(message)\n")
        }

        for sig in [SIGABRT, SIGSEGV, SIGBUS, SIGILL, SIGFPE, SIGTRAP] {
            signal(sig) { received in
                CrashLogger.writeRaw("\nFATAL SIGNAL \(received) — Porter is terminating\n")
                signal(received, SIG_DFL)
                raise(received)
            }
        }
    }

    private static func writeRaw(_ string: String) {
        guard fd >= 0 else { return }
        let bytes = Array(string.utf8)
        bytes.withUnsafeBytes { buf in
            guard let base = buf.baseAddress else { return }
            _ = Darwin.write(fd, base, buf.count)
        }
    }
}
