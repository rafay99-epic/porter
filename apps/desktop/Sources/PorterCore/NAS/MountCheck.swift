import Foundation

/// A network share currently mounted on the system, discovered from the kernel's
/// mount table. The point of this type is to let Porter *auto-detect* a NAS the
/// user already connected in Finder — so they pick it from a list instead of
/// typing an `smb://` address they may not know.
public struct MountedShare: Sendable, Identifiable, Equatable {
    /// Where it's mounted, e.g. `/Volumes/media`.
    public let mountPoint: String
    /// The source as the kernel reports it, e.g. `//user@host/share`.
    public let from: String
    /// Filesystem type, e.g. `smbfs`, `afpfs`, `nfs`.
    public let fsType: String

    public var id: String { mountPoint }

    /// Friendly name — the volume's folder name (`media`).
    public var name: String { (mountPoint as NSString).lastPathComponent }

    /// The connection URL reconstructed from `from`, when we can: `smbfs` →
    /// `smb://…`, `afpfs` → `afp://…`. nil for types we don't rebuild (the mount
    /// point alone is still enough for Porter to file onto it).
    public var url: String? {
        guard from.hasPrefix("//") else { return nil }
        switch fsType {
        case "smbfs": return "smb:" + from
        case "afpfs": return "afp:" + from
        default:      return nil
        }
    }
}

/// Mount-table queries. Used to gate every sweep (is the NAS up?) and to power the
/// "pick a mounted share" onboarding step.
public enum MountCheck {
    /// True when `path` appears as a mount point in the kernel's mount table. A
    /// stub folder left at the path would pass a plain existence check, so we
    /// consult the live table instead — the `mount | grep " on <path> "` equivalent.
    public static func isMounted(_ path: String) -> Bool {
        forEachMount { onName, _, _ in onName == path }
    }

    public static func isMounted(_ url: URL) -> Bool { isMounted(url.path) }

    /// Every currently-mounted network share (smb/afp/nfs/webdav/ftp), so the user
    /// can pick the NAS they already connected in Finder.
    public static func networkMounts() -> [MountedShare] {
        let networkTypes: Set<String> = ["smbfs", "afpfs", "nfs", "webdav", "ftp"]
        var shares: [MountedShare] = []
        _ = forEachMount { onName, fromName, fsType in
            if networkTypes.contains(fsType) {
                shares.append(MountedShare(mountPoint: onName, from: fromName, fsType: fsType))
            }
            return false // keep scanning all mounts
        }
        return shares
    }

    // MARK: - Private

    /// Walk the mount table, calling `body(mountOn, mountFrom, fsType)` for each.
    /// Stops early and returns true if `body` returns true.
    @discardableResult
    private static func forEachMount(_ body: (String, String, String) -> Bool) -> Bool {
        var buffer: UnsafeMutablePointer<statfs>?
        let count = getmntinfo(&buffer, MNT_NOWAIT)
        guard count > 0, let buffer else { return false }
        for i in 0..<Int(count) {
            var fs = buffer[i]
            let onName = cString(&fs.f_mntonname)
            let fromName = cString(&fs.f_mntfromname)
            let fsType = cString(&fs.f_fstypename)
            if body(onName, fromName, fsType) { return true }
        }
        return false
    }

    /// Read a fixed-size C `char` array (imported into Swift as a tuple) as a String.
    private static func cString<T>(_ field: inout T) -> String {
        withUnsafePointer(to: &field) {
            $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout<T>.size) {
                String(cString: $0)
            }
        }
    }
}
