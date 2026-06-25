import Foundation
import AppKit

/// Full Disk Access detection + the deep links to grant it. There's no public API
/// to *query* a TCC grant, so we probe behaviourally: try to list the watched
/// folder. A permission error means the grant is missing — the durable fix for
/// the silent `find: Operation not permitted` failure that plagued the launchd
/// version. Because Porter is a signed app bundle, the grant attaches to its
/// stable identity and survives code edits (unlike a `/bin/bash` + script grant).
enum Permissions {
    /// Can we read the contents of `folder`? `false` almost always means a missing
    /// Full Disk Access (or Downloads-folder) grant.
    static func canRead(_ folder: URL) -> Bool {
        do {
            _ = try FileManager.default.contentsOfDirectory(
                atPath: folder.path)
            return true
        } catch {
            let ns = error as NSError
            // NSFileReadNoPermissionError (257) / POSIX EPERM → denied. Treat a
            // genuinely missing folder as "readable" so we don't nag about a path
            // the user simply hasn't created yet.
            if ns.code == 257 || (error as? POSIXError)?.code == .EPERM { return false }
            return true
        }
    }

    static func openFullDiskAccessSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
    }

    static func openFilesAndFoldersSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders")
    }

    private static func open(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
