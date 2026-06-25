import XCTest
@testable import PorterCore

/// The default rule set must reproduce the old hardcoded classification exactly,
/// and the engine must honour order (first match wins) + enabled flags.
final class RuleEngineTests: XCTestCase {
    private let rules = SortRule.defaults

    private func dest(_ name: String) -> String {
        RuleEngine.destination(for: name, using: rules)
    }

    func testScreenshotsBeatExtension() {
        // PNG, but the screenshot name rule comes first → screenshots, not Pictures.
        XCTAssertEqual(dest("Screenshot 2026-06-25 at 14.03.png"), "screenshots")
        XCTAssertEqual(dest("Screen Shot 2026-06-25.png"), "screenshots")
        XCTAssertEqual(dest("vacation.png"), "Pictures")
    }

    func testExtensionMapping() {
        XCTAssertEqual(dest("report.PDF"), "PDFs")          // case-insensitive ext
        XCTAssertEqual(dest("notes.md"), "Documents")
        XCTAssertEqual(dest("Xcode.dmg"), "Installers")
        XCTAssertEqual(dest("clip.mov"), "Movies")
        XCTAssertEqual(dest("song.flac"), "Music")
        XCTAssertEqual(dest("bundle.tar.gz"), "Archives")
        XCTAssertEqual(dest("mystery.xyz"), "Other")        // catch-all
        XCTAssertEqual(dest("Makefile"), "Other")
    }

    func testFirstMatchWinsAndDisabledSkipped() {
        let custom = [
            SortRule(match: .nameContains("invoice"), destination: "Documents/Invoices"),
            SortRule(enabled: false, match: .extensions(["pdf"]), destination: "ShouldBeSkipped"),
            SortRule(match: .extensions(["pdf"]), destination: "PDFs"),
            SortRule(match: .anything, destination: "Other")
        ]
        XCTAssertEqual(RuleEngine.destination(for: "march invoice.pdf", using: custom), "Documents/Invoices")
        XCTAssertEqual(RuleEngine.destination(for: "manual.pdf", using: custom), "PDFs")
        XCTAssertEqual(RuleEngine.destination(for: "photo.png", using: custom), "Other")
    }

    func testMatchKinds() {
        XCTAssertTrue(RuleMatch.namePrefix("IMG_").matches("IMG_0001.jpg"))
        XCTAssertTrue(RuleMatch.nameSuffix("-final.pdf").matches("contract-final.pdf"))
        XCTAssertTrue(RuleMatch.nameContains("RECEIPT").matches("my receipt.pdf"))   // case-insensitive
        XCTAssertTrue(RuleMatch.regex(#"^\d{4}-\d{2}-\d{2}"#).matches("2026-06-25 log.txt"))
        XCTAssertFalse(RuleMatch.regex("[").matches("anything"))                      // invalid regex → no match
        XCTAssertTrue(RuleMatch.anything.matches("whatever"))
    }

    func testSizeConditions() {
        let big = FileMetadata(name: "movie.mov", size: 2_000_000_000)
        let small = FileMetadata(name: "note.txt", size: 1_000)
        XCTAssertTrue(RuleMatch.largerThan(bytes: 1_000_000_000).matches(big))
        XCTAssertFalse(RuleMatch.largerThan(bytes: 1_000_000_000).matches(small))
        XCTAssertTrue(RuleMatch.smallerThan(bytes: 1_000_000).matches(small))
    }

    func testAgeConditions() {
        let now = Date(timeIntervalSince1970: 1_000_000_000)
        let old = FileMetadata(name: "old.zip", modified: now.addingTimeInterval(-10 * 86_400))
        XCTAssertTrue(RuleMatch.olderThan(days: 7).matches(old, now: now))
        XCTAssertFalse(RuleMatch.newerThan(days: 7).matches(old, now: now))
        let fresh = FileMetadata(name: "fresh.zip", modified: now.addingTimeInterval(-3_600))
        XCTAssertTrue(RuleMatch.newerThan(days: 1).matches(fresh, now: now))
    }

    func testKindConditionUsesUTIHierarchy() {
        // No explicit UTI — resolved from the extension.
        XCTAssertTrue(RuleMatch.kind(.image).matches(FileMetadata(name: "vacation.heic")))
        XCTAssertTrue(RuleMatch.kind(.video).matches(FileMetadata(name: "clip.mov")))
        XCTAssertFalse(RuleMatch.kind(.audio).matches(FileMetadata(name: "vacation.heic")))
    }

    func testAndOrCombinators() {
        // Large videos only.
        let big = FileMetadata(name: "film.mp4", size: 5_000_000_000)
        let smallVideo = FileMetadata(name: "tiny.mp4", size: 1_000)
        let largeVideos = RuleMatch.all([.kind(.video), .largerThan(bytes: 1_000_000_000)])
        XCTAssertTrue(largeVideos.matches(big))
        XCTAssertFalse(largeVideos.matches(smallVideo))

        // Either a PDF or something with "invoice" in the name.
        let either = RuleMatch.any([.extensions(["pdf"]), .nameContains("invoice")])
        XCTAssertTrue(either.matches(FileMetadata(name: "manual.pdf")))
        XCTAssertTrue(either.matches(FileMetadata(name: "march invoice.txt")))
        XCTAssertFalse(either.matches(FileMetadata(name: "photo.png")))
    }

    func testNewConditionsSurviveCodableRoundTrip() throws {
        let rule = SortRule(match: .all([.kind(.image), .largerThan(bytes: 5_000_000)]),
                            destination: "Pictures/Large", conflictPolicy: .keepNewer)
        let data = try JSONEncoder().encode([rule])
        let decoded = try JSONDecoder().decode([SortRule].self, from: data)
        XCTAssertEqual(decoded, [rule])
    }
}

final class FileTriageTests: XCTestCase {
    func testMacOSJunk() {
        XCTAssertTrue(FileTriage.isMacOSJunk(".DS_Store"))
        XCTAssertTrue(FileTriage.isMacOSJunk("._shadow.pdf"))
        XCTAssertTrue(FileTriage.isMacOSJunk("Icon\r"))
        XCTAssertFalse(FileTriage.isMacOSJunk("report.pdf"))
    }

    func testPartialOrHidden() {
        XCTAssertTrue(FileTriage.isPartialOrHidden("movie.mp4.crdownload"))
        XCTAssertTrue(FileTriage.isPartialOrHidden("data.part"))
        XCTAssertTrue(FileTriage.isPartialOrHidden(".hidden"))
        XCTAssertFalse(FileTriage.isPartialOrHidden("movie.mp4"))
    }

    func testSettle() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertTrue(FileTriage.isSettled(modified: now.addingTimeInterval(-45), now: now, seconds: 30))
        XCTAssertFalse(FileTriage.isSettled(modified: now.addingTimeInterval(-5), now: now, seconds: 30))
    }
}
