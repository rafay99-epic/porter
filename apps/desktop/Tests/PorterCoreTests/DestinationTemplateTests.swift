import XCTest
@testable import PorterCore

final class DestinationTemplateTests: XCTestCase {
    /// Fixed date in UTC so the expansion is deterministic regardless of where the
    /// test runs.
    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        return f.date(from: iso)!
    }

    private var utc: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    func testNoTokensIsUnchanged() {
        XCTAssertEqual(DestinationTemplate.expand("Documents/Invoices", date: Date()), "Documents/Invoices")
        XCTAssertFalse(DestinationTemplate.hasTokens("Documents/Invoices"))
    }

    func testYearMonthTokens() {
        let d = date("2026-03-09T12:00:00Z")
        let out = DestinationTemplate.expand("Movies/{yyyy}/{MM}", date: d,
                                             calendar: utc, locale: Locale(identifier: "en_US_POSIX"))
        XCTAssertEqual(out, "Movies/2026/03")
        XCTAssertTrue(DestinationTemplate.hasTokens("Movies/{yyyy}/{MM}"))
    }

    func testCombinedTokenInOneComponent() {
        let d = date("2026-12-31T23:00:00Z")
        let out = DestinationTemplate.expand("Archives/{yyyy-MM}", date: d,
                                             calendar: utc, locale: Locale(identifier: "en_US_POSIX"))
        XCTAssertEqual(out, "Archives/2026-12")
    }

    func testStrayBraceIsNotMangled() {
        // No closing brace → copied verbatim, never crashes.
        XCTAssertEqual(DestinationTemplate.expand("Weird{name", date: Date()), "Weird{name")
    }
}
