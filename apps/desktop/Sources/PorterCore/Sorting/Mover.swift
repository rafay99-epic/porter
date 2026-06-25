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

    /// Move `source` into `<nasRoot>/<destination>/`, returning the final URL.
    /// `destination` may be nested ("Documents/Invoices"). Creates the folder(s) if
    /// absent, resolving existing case-variants component-by-component first (so
    /// `Documents` and `documents` don't both get made).
    @discardableResult
    public func move(_ source: URL, to destination: String) throws -> URL {
        let destDir = resolveDestinationDirectory(destination)
        return try move(source, intoDirectory: destDir)
    }

    /// Move `source` into an already-resolved directory `destDir` using the same
    /// xattr-stripping copy + atomic rename + unlink mechanics. Used both for the
    /// forward sort (destDir under the NAS) and for "Undo" (destDir back in the
    /// original watched folder). Creates `destDir` if absent.
    @discardableResult
    public func move(_ source: URL, intoDirectory destDir: URL) throws -> URL {
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

    /// Resolve a (possibly nested) destination folder under the NAS root, matching
    /// existing case-variants at each path component so `documents/` isn't
    /// duplicated as `Documents/`. Components that don't exist yet are used as-is
    /// (and created on the move). Empty components are skipped.
    public func resolveDestinationDirectory(_ folder: String) -> URL {
        var current = nasRoot
        for component in folder.split(separator: "/").map(String.init) where !component.isEmpty {
            let target = current.appendingPathComponent(component, isDirectory: true)
            if FileManager.default.fileExists(atPath: target.path) {
                current = target
            } else if let existing = caseInsensitiveChild(of: current, named: component) {
                current = existing
            } else {
                current = target
            }
        }
        return current
    }

    /// A child directory of `dir` whose name matches `named` case-insensitively.
    private func caseInsensitiveChild(of dir: URL, named: String) -> URL? {
        let wanted = named.lowercased()
        guard let kids = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.isDirectoryKey]) else { return nil }
        for url in kids where url.lastPathComponent.lowercased() == wanted {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                return url
            }
        }
        return nil
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
