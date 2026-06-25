import XCTest
@testable import PorterCore

final class QuietHoursTests: XCTestCase {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 6, day: 26, hour: hour, minute: minute))!
    }

    func testDisabledIsNeverQuiet() {
        let q = QuietHours(enabled: false, startMinute: 0, endMinute: 1439)
        XCTAssertFalse(q.isQuiet(at: at(3), calendar: cal))
    }

    func testSameDayWindow() {
        let q = QuietHours(enabled: true, startMinute: 9 * 60, endMinute: 17 * 60) // 09:00–17:00
        XCTAssertTrue(q.isQuiet(at: at(12), calendar: cal))
        XCTAssertFalse(q.isQuiet(at: at(8), calendar: cal))
        XCTAssertFalse(q.isQuiet(at: at(17), calendar: cal), "end is exclusive")
    }

    func testWrapsPastMidnight() {
        let q = QuietHours(enabled: true, startMinute: 22 * 60, endMinute: 7 * 60) // 22:00–07:00
        XCTAssertTrue(q.isQuiet(at: at(23), calendar: cal))
        XCTAssertTrue(q.isQuiet(at: at(2), calendar: cal))
        XCTAssertFalse(q.isQuiet(at: at(12), calendar: cal))
    }

    func testEmptyWindowIsNeverQuiet() {
        let q = QuietHours(enabled: true, startMinute: 600, endMinute: 600)
        XCTAssertFalse(q.isQuiet(at: at(10), calendar: cal))
    }

    func testEndLabel() {
        XCTAssertEqual(QuietHours(endMinute: 7 * 60 + 30).endLabel, "07:30")
    }
}
