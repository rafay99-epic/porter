import Foundation

/// The cross-volume move mechanics, ported from `bin/sort-downloads`'s copy
/// pattern. Stateless aside from the NAS root it targets, so it's easy to test
/// against a temp directory standing in for the share.
///
/// Why not `FileManager.moveItem`? On a cross-volume move macOS falls back to
/// `copyfile()` with full metadata, which tries to carry every extended
/// attribute. SMB rejects protected xattrs (`com.apple.provenance`,
/// `com.apple.quarantine`) with EPERM and aborts the whole copy — silently
/// breaking screenshots and Gatekeeper-marked downloads. We instead copy with
/// `COPYFILE_DATA | COPYFILE_STAT` (bytes + mode/mtime, NO xattrs/ACLs — the
/// `cp -Xp` equivalent) into a temp file on the destination volume, atomically
/// rename it into place, then unlink the source. If any step fails the source is
/// left untouched for the next sweep.
public struct Mover: Sendable {
    public let nasRoot: URL

    public init(nasRoot: URL) {
        self.nasRoot = nasRoot
    }

    public enum MoveError: Error, Equatable {
        case createDirectoryFailed(String)
        case copyFailed(String)
        case renameFailed(String)
        /// Copy + rename succeeded but the source couldn't be unlinked. The file
        /// is safely on the NAS; we just couldn't remove the original.
        case sourceNotRemoved(destination: URL)
    }

    /// Move `source` into `<nasRoot>/<category>/`, returning the final destination
    /// URL. Creates the category folder if absent, resolving an existing
    /// case-variant first (so `Documents` and `documents` don't both get made).
    @discardableResult
    public func move(_ source: URL, to category: FileCategory) throws -> URL {
        let destDir = resolveCategoryDirectory(category)
        do {
            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        } catch {
            throw MoveError.createDirectoryFailed(destDir.path)
        }

        let dest = resolveDestination(in: destDir, name: source.lastPathComponent)
        let tmp = destDir.appendingPathComponent("\(dest.lastPathComponent).partial-\(ProcessInfo.processInfo.processIdentifier)")

        // 1. Copy bytes + mode/mtime, no xattrs/ACLs, to a temp on the dest volume.
        let copyRC = source.path.withCString { src in
            tmp.path.withCString { dst in
                copyfile(src, dst, nil, copyfile_flags_t(COPYFILE_DATA | COPYFILE_STAT))
            }
        }
        guard copyRC == 0 else {
            unlinkQuietly(tmp)
            throw MoveError.copyFailed(dest.path)
        }

        // 2. Same-volume atomic rename into the final name.
        let renameRC = tmp.path.withCString { from in
            dest.path.withCString { to in rename(from, to) }
        }
        guard renameRC == 0 else {
            unlinkQuietly(tmp)
            throw MoveError.renameFailed(dest.path)
        }

        // 3. Remove the source. The file is already safe on the NAS; if unlink
        //    fails we report it distinctly rather than as a lost file.
        let unlinkRC = source.path.withCString { unlink($0) }
        guard unlinkRC == 0 else {
            throw MoveError.sourceNotRemoved(destination: dest)
        }

        return dest
    }

    // MARK: - Path resolution

    /// `find_dir_ci`: if `<nasRoot>/<folder>` exists in any case, return that exact
    /// path; otherwise return the canonically-cased path (created on first move).
    public func resolveCategoryDirectory(_ category: FileCategory) -> URL {
        let target = nasRoot.appendingPathComponent(category.folderName, isDirectory: true)
        if FileManager.default.fileExists(atPath: target.path) { return target }

        let wanted = category.folderName.lowercased()
        if let siblings = try? FileManager.default.contentsOfDirectory(
            at: nasRoot, includingPropertiesForKeys: [.isDirectoryKey]) {
            for url in siblings where url.lastPathComponent.lowercased() == wanted {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                    return url
                }
            }
        }
        return target
    }

    /// Finder-style collision suffix: `name (1).ext`, `name (2).ext`, … so an
    /// existing destination is never overwritten.
    public func resolveDestination(in dir: URL, name: String) -> URL {
        let first = dir.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: first.path) else { return first }

        let ns = name as NSString
        let ext = ns.pathExtension
        let base = ns.deletingPathExtension
        var n = 1
        while true {
            let candidate = ext.isEmpty ? "\(base) (\(n))" : "\(base) (\(n)).\(ext)"
            let url = dir.appendingPathComponent(candidate)
            if !FileManager.default.fileExists(atPath: url.path) { return url }
            n += 1
        }
    }

    private func unlinkQuietly(_ url: URL) {
        _ = url.path.withCString { unlink($0) }
    }
}
