import XCTest
@testable import PorterCore

final class ClassifierTests: XCTestCase {
    func testScreenshotsMatchByNameBeforeExtension() {
        // A screenshot is a PNG, but the name rule must win so it lands in
        // screenshots/ rather than Pictures/ — same precedence as the bash script.
        XCTAssertEqual(Classifier.category(for: "Screenshot 2026-06-25 at 14.03.01.png"), .screenshots)
        XCTAssertEqual(Classifier.category(for: "Screen Shot 2026-06-25.png"), .screenshots)
        XCTAssertTrue(Classifier.isScreenshotName("Screenshot foo"))
        XCTAssertFalse(Classifier.isScreenshotName("My Screenshot.png"))
    }

    func testExtensionMapping() {
        XCTAssertEqual(Classifier.category(for: "photo.JPG"), .pictures)   // case-insensitive
        XCTAssertEqual(Classifier.category(for: "report.pdf"), .pdfs)
        XCTAssertEqual(Classifier.category(for: "notes.md"), .documents)
        XCTAssertEqual(Classifier.category(for: "Xcode.dmg"), .installers)
        XCTAssertEqual(Classifier.category(for: "clip.mov"), .movies)
        XCTAssertEqual(Classifier.category(for: "song.flac"), .music)
        XCTAssertEqual(Classifier.category(for: "bundle.tar.gz"), .archives) // last component wins
        XCTAssertEqual(Classifier.category(for: "weird.xyz"), .other)
    }

    func testNoExtensionAndDotfiles() {
        XCTAssertEqual(Classifier.category(for: "Makefile"), .other)
        XCTAssertEqual(Classifier.category(for: ".bashrc"), .other) // leading-dot only → Other
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
        let old = now.addingTimeInterval(-45)
        let fresh = now.addingTimeInterval(-5)
        XCTAssertTrue(FileTriage.isSettled(modified: old, now: now, seconds: 30))
        XCTAssertFalse(FileTriage.isSettled(modified: fresh, now: now, seconds: 30))
    }
}
