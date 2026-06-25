import XCTest
@testable import PorterCore

/// Exercises the move mechanics against temp directories standing in for the NAS.
/// (No SMB here — the xattr-stripping reason for the copy pattern is documented in
/// `Mover`; these tests pin the file-level behaviour: data integrity, collisions,
/// case-insensitive folders, source removal.)
final class MoverTests: XCTestCase {
    private var root: URL!
    private var source: URL!
    private var nas: URL!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("porter-tests-\(UUID().uuidString)")
        source = root.appendingPathComponent("Downloads")
        nas = root.appendingPathComponent("media")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nas, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func makeFile(_ name: String, contents: String = "hello porter") throws -> URL {
        let url = source.appendingPathComponent(name)
        try contents.data(using: .utf8)!.write(to: url)
        return url
    }

    func testMovePlacesFileAndRemovesSource() throws {
        let file = try makeFile("report.pdf", contents: "pdf-bytes")
        let mover = Mover(nasRoot: nas)
        let dest = try mover.move(file, to: .pdfs)

        XCTAssertEqual(dest.deletingLastPathComponent().lastPathComponent, "PDFs")
        XCTAssertEqual(try String(contentsOf: dest, encoding: .utf8), "pdf-bytes")
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path), "source should be gone")
    }

    func testCollisionGetsSuffix() throws {
        // Pre-seed a colliding destination.
        let docs = nas.appendingPathComponent("Documents")
        try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        try "old".write(to: docs.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

        let file = try makeFile("notes.txt", contents: "new")
        let mover = Mover(nasRoot: nas)
        let dest = try mover.move(file, to: .documents)

        XCTAssertEqual(dest.lastPathComponent, "notes (1).txt")
        XCTAssertEqual(try String(contentsOf: dest, encoding: .utf8), "new")
    }

    func testCaseInsensitiveFolderResolutionMakesNoDuplicate() throws {
        // NAS already has a lowercase "documents". The invariant — independent of
        // whether the filesystem is case-sensitive — is that the move reuses it
        // and does NOT create a second "Documents" alongside it. (On the case-
        // sensitive NAS the resolved folder name is literally "documents"; on a
        // case-insensitive dev disk the two names are the same inode anyway.)
        let lower = nas.appendingPathComponent("documents")
        try FileManager.default.createDirectory(at: lower, withIntermediateDirectories: true)

        let file = try makeFile("memo.md", contents: "memo-bytes")
        let mover = Mover(nasRoot: nas)
        let dest = try mover.move(file, to: .documents)

        XCTAssertEqual(try String(contentsOf: dest, encoding: .utf8), "memo-bytes")
        let docDirs = try FileManager.default.contentsOfDirectory(atPath: nas.path)
            .filter { $0.lowercased() == "documents" }
        XCTAssertEqual(docDirs.count, 1, "must reuse the existing folder, not create a duplicate case-variant")
    }

    func testSweepEndToEnd() throws {
        _ = try makeFile("a.png")
        _ = try makeFile("b.pdf")
        _ = try makeFile(".DS_Store")             // junk → ignored
        _ = try makeFile("c.mp4.crdownload")       // partial → skipped

        // now is well past every file's mtime, so the settle check passes.
        let sorter = Sorter(sources: [source], nasRoot: nas, settleSeconds: 0)
        let summary = sorter.sweep(now: Date().addingTimeInterval(60))

        XCTAssertEqual(summary.moved, 2)
        XCTAssertEqual(summary.failed, 0)
        XCTAssertEqual(summary.skipped, 1) // the .crdownload; .DS_Store isn't counted
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: nas.appendingPathComponent("Pictures/a.png").path))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: nas.appendingPathComponent("PDFs/b.pdf").path))
    }
}
