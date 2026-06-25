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
        let dest = try mover.move(file, to: "PDFs")

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
        let dest = try mover.move(file, to: "Documents")

        XCTAssertEqual(dest.lastPathComponent, "notes (1).txt")
        XCTAssertEqual(try String(contentsOf: dest, encoding: .utf8), "new")
    }

    func testOverwritePolicyReplacesExisting() throws {
        let docs = nas.appendingPathComponent("Documents")
        try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        try "old".write(to: docs.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

        let file = try makeFile("notes.txt", contents: "new")
        let dest = try Mover(nasRoot: nas).move(file, to: "Documents", policy: .overwrite)

        XCTAssertEqual(dest.lastPathComponent, "notes.txt", "no suffix — it replaces in place")
        XCTAssertEqual(try String(contentsOf: dest, encoding: .utf8), "new")
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testSkipPolicyLeavesSourceAndThrows() throws {
        let docs = nas.appendingPathComponent("Documents")
        try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        try "old".write(to: docs.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

        let file = try makeFile("notes.txt", contents: "new")
        XCTAssertThrowsError(try Mover(nasRoot: nas).move(file, to: "Documents", policy: .skip)) { error in
            guard case Mover.MoveError.skippedExisting = error else {
                return XCTFail("expected skippedExisting, got \(error)")
            }
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path), "source untouched on skip")
        XCTAssertEqual(try String(contentsOf: docs.appendingPathComponent("notes.txt"), encoding: .utf8), "old")
    }

    func testKeepNewerOverwritesOnlyWhenNewer() throws {
        let docs = nas.appendingPathComponent("Documents")
        try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        let existing = docs.appendingPathComponent("notes.txt")
        try "old".write(to: existing, atomically: true, encoding: .utf8)
        // Make the existing file clearly older than the incoming one.
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-3600)], ofItemAtPath: existing.path)

        let newer = try makeFile("notes.txt", contents: "new")
        let dest = try Mover(nasRoot: nas).move(newer, to: "Documents", policy: .keepNewer)
        XCTAssertEqual(try String(contentsOf: dest, encoding: .utf8), "new")

        // Now the NAS copy is newest; an older incoming file is skipped.
        let older = try makeFile("notes.txt", contents: "stale")
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-7200)], ofItemAtPath: older.path)
        XCTAssertThrowsError(try Mover(nasRoot: nas).move(older, to: "Documents", policy: .keepNewer))
        XCTAssertEqual(try String(contentsOf: dest, encoding: .utf8), "new", "kept the newer NAS copy")
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
        let dest = try mover.move(file, to: "Documents")

        XCTAssertEqual(try String(contentsOf: dest, encoding: .utf8), "memo-bytes")
        let docDirs = try FileManager.default.contentsOfDirectory(atPath: nas.path)
            .filter { $0.lowercased() == "documents" }
        XCTAssertEqual(docDirs.count, 1, "must reuse the existing folder, not create a duplicate case-variant")
    }

    func testMoveIntoDirectoryRoundTripsForUndo() throws {
        // Forward: Downloads → NAS/PDFs. Then undo: NAS/PDFs → back into Downloads.
        let file = try makeFile("paper.pdf", contents: "abc")
        let mover = Mover(nasRoot: nas)
        let onNAS = try mover.move(file, to: "PDFs")
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))

        let restored = try mover.move(onNAS, intoDirectory: source)
        XCTAssertEqual(restored.deletingLastPathComponent().path, source.path)
        XCTAssertEqual(try String(contentsOf: restored, encoding: .utf8), "abc")
        XCTAssertFalse(FileManager.default.fileExists(atPath: onNAS.path), "NAS copy removed after undo")
    }

    func testSweepIgnoresPulledBackPaths() throws {
        let kept = try makeFile("keep.pdf")
        _ = try makeFile("sortme.pdf")
        let src = WatchSource(path: source.path, routing: .classify)
        let sorter = Sorter(sources: [src], rules: SortRule.defaults, nasRoot: nas, settleSeconds: 0)
        let summary = sorter.sweep(now: Date().addingTimeInterval(60),
                                   ignoring: [kept.standardizedFileURL.path])

        XCTAssertEqual(summary.moved, 1, "the ignored file must stay put")
        XCTAssertTrue(FileManager.default.fileExists(atPath: kept.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: nas.appendingPathComponent("PDFs/sortme.pdf").path))
    }

    func testPlanPreviewsWithoutMoving() throws {
        _ = try makeFile("a.png")
        _ = try makeFile("b.pdf")
        _ = try makeFile(".DS_Store")               // junk → absent from plan
        _ = try makeFile("c.mp4.crdownload")         // partial → absent from plan

        let src = WatchSource(path: source.path, routing: .classify)
        let sorter = Sorter(sources: [src], rules: SortRule.defaults, nasRoot: nas, settleSeconds: 0)
        let plan = sorter.plan(now: Date().addingTimeInterval(60))

        XCTAssertEqual(Set(plan.map(\.name)), ["a.png", "b.pdf"])
        XCTAssertEqual(plan.first { $0.name == "a.png" }?.destination, "Pictures")
        // Nothing actually moved.
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.appendingPathComponent("a.png").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: nas.appendingPathComponent("Pictures/a.png").path))
    }

    func testSweepEndToEndClassify() throws {
        _ = try makeFile("a.png")
        _ = try makeFile("b.pdf")
        _ = try makeFile(".DS_Store")             // junk → ignored
        _ = try makeFile("c.mp4.crdownload")       // partial → skipped

        let src = WatchSource(path: source.path, routing: .classify)
        let sorter = Sorter(sources: [src], rules: SortRule.defaults, nasRoot: nas, settleSeconds: 0)
        let summary = sorter.sweep(now: Date().addingTimeInterval(60))

        XCTAssertEqual(summary.moved, 2)
        XCTAssertEqual(summary.failed, 0)
        XCTAssertEqual(summary.skipped, 1) // the .crdownload; .DS_Store isn't counted
        XCTAssertTrue(FileManager.default.fileExists(atPath: nas.appendingPathComponent("Pictures/a.png").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: nas.appendingPathComponent("PDFs/b.pdf").path))
    }

    func testRecursiveWatchSortsSubfolders() throws {
        // Top-level file plus one nested two levels deep.
        _ = try makeFile("top.pdf")
        let sub = source.appendingPathComponent("a/b")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try "deep".write(to: sub.appendingPathComponent("buried.png"), atomically: true, encoding: .utf8)

        let src = WatchSource(path: source.path, routing: .classify, recursive: true)
        let sorter = Sorter(sources: [src], rules: SortRule.defaults, nasRoot: nas, settleSeconds: 0)
        let summary = sorter.sweep(now: Date().addingTimeInterval(60))

        XCTAssertEqual(summary.moved, 2, "both the top-level and the buried file move")
        XCTAssertTrue(FileManager.default.fileExists(atPath: nas.appendingPathComponent("PDFs/top.pdf").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: nas.appendingPathComponent("Pictures/buried.png").path))
    }

    func testNonRecursiveLeavesSubfolderFiles() throws {
        _ = try makeFile("top.pdf")
        let sub = source.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try "deep".write(to: sub.appendingPathComponent("buried.png"), atomically: true, encoding: .utf8)

        let src = WatchSource(path: source.path, routing: .classify, recursive: false)
        let sorter = Sorter(sources: [src], rules: SortRule.defaults, nasRoot: nas, settleSeconds: 0)
        let summary = sorter.sweep(now: Date().addingTimeInterval(60))

        XCTAssertEqual(summary.moved, 1, "only the top-level file moves")
        XCTAssertTrue(FileManager.default.fileExists(atPath: sub.appendingPathComponent("buried.png").path))
    }

    func testFixedRoutingSendsEverythingToOneFolder() throws {
        _ = try makeFile("vacation.png")
        _ = try makeFile("notes.txt")

        // A "Pictures-style" source: force everything to one NAS folder.
        let src = WatchSource(path: source.path, routing: .fixed(folder: "Photos"))
        let sorter = Sorter(sources: [src], rules: SortRule.defaults, nasRoot: nas, settleSeconds: 0)
        let summary = sorter.sweep(now: Date().addingTimeInterval(60))

        XCTAssertEqual(summary.moved, 2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: nas.appendingPathComponent("Photos/vacation.png").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: nas.appendingPathComponent("Photos/notes.txt").path))
    }

    func testNestedDestinationCreated() throws {
        _ = try makeFile("march invoice.pdf")
        let rules = [
            SortRule(match: .nameContains("invoice"), destination: "Documents/Invoices"),
            SortRule(match: .anything, destination: "Other")
        ]
        let src = WatchSource(path: source.path, routing: .classify)
        let sorter = Sorter(sources: [src], rules: rules, nasRoot: nas, settleSeconds: 0)
        let summary = sorter.sweep(now: Date().addingTimeInterval(60))

        XCTAssertEqual(summary.moved, 1)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: nas.appendingPathComponent("Documents/Invoices/march invoice.pdf").path))
    }
}
