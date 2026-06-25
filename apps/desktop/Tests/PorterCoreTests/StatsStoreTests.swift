import XCTest
@testable import PorterCore

final class StatsStoreTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("porter-stats-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testAppendAndLoadRoundTrips() {
        let store = StatsStore(directory: dir)
        store.append([
            StatRecord(date: Date(), category: "Pictures", bytes: 1_000),
            StatRecord(date: Date(), category: "PDFs", bytes: 2_000)
        ])
        let loaded = store.load()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded.reduce(Int64(0)) { $0 + $1.bytes }, 3_000)
    }

    func testAppendIsCumulative() {
        let store = StatsStore(directory: dir)
        store.append([StatRecord(date: Date(), category: "A", bytes: 1)])
        store.append([StatRecord(date: Date(), category: "B", bytes: 2)])
        XCTAssertEqual(store.load().count, 2)
    }

    func testRetentionPrunesOldRecords() {
        let store = StatsStore(directory: dir, retentionDays: 30)
        let now = Date()
        let old = StatRecord(date: now.addingTimeInterval(-40 * 86_400), category: "Old", bytes: 1)
        let fresh = StatRecord(date: now, category: "Fresh", bytes: 1)
        store.append([old, fresh], now: now)
        let loaded = store.load()
        XCTAssertEqual(loaded.map(\.category), ["Fresh"], "records past the window are dropped")
    }

    func testCategoryFromNestedDestination() {
        XCTAssertEqual(StatsStore.category(fromDestination: "Pictures/2026/06"), "Pictures")
        XCTAssertEqual(StatsStore.category(fromDestination: "PDFs"), "PDFs")
    }
}
