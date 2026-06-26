import Foundation
import CryptoKit

/// Content hashing for duplicate detection and copy verification. Streams the file
/// in chunks so a multi-gigabyte movie doesn't have to fit in memory.
public enum Checksum {
    private static let chunkSize = 1 << 20   // 1 MiB

    /// SHA-256 of the file's bytes as a hex string, or nil if it can't be read.
    public static func sha256(of url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            guard let chunk = try? handle.read(upToCount: chunkSize), !chunk.isEmpty else { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// True when two files have identical contents. Cheap size check first (a
    /// mismatch there rules out equality without hashing), then a full SHA-256
    /// comparison. A failure to read either file returns false — when unsure,
    /// treat them as different so nothing is wrongly dropped.
    public static func filesAreIdentical(_ a: URL, _ b: URL) -> Bool {
        let keys: Set<URLResourceKey> = [.fileSizeKey]
        let sizeA = try? a.resourceValues(forKeys: keys).fileSize
        let sizeB = try? b.resourceValues(forKeys: keys).fileSize
        if let sizeA, let sizeB, sizeA != sizeB { return false }
        guard let hashA = sha256(of: a), let hashB = sha256(of: b) else { return false }
        return hashA == hashB
    }
}
