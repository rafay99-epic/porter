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
