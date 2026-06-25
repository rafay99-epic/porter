import XCTest
@testable import PorterCore

final class SuggestionEngineTests: XCTestCase {
    private func moved(_ name: String, to destination: String) -> ActivityEntry {
        ActivityEntry(date: Date(), fileName: name, destination: destination,
                      outcome: .moved(folder: destination))
    }

    private let rules = SortRule.defaults   // ends with .anything → "Other"

    func testSuggestsRepeatedCatchAllExtension() {
        let entries = [
            moved("a.torrent", to: "Other"),
            moved("b.torrent", to: "Other"),
            moved("c.torrent", to: "Other"),
            moved("d.png", to: "Pictures")   // already categorized → ignored
        ]
        let suggestions = SuggestionEngine.suggestions(from: entries, rules: rules)
        XCTAssertEqual(suggestions.map(\.ext), ["torrent"])
        XCTAssertEqual(suggestions.first?.count, 3)
    }

    func testBelowThresholdIsNotSuggested() {
        let entries = [moved("a.torrent", to: "Other"), moved("b.torrent", to: "Other")]
        XCTAssertTrue(SuggestionEngine.suggestions(from: entries, rules: rules, minimumCount: 3).isEmpty)
    }

    func testAlreadyCoveredExtensionIsNotSuggested() {
        // .pdf already routes to PDFs in the defaults — even if some slipped to Other.
        let entries = (0..<5).map { moved("doc\($0).pdf", to: "Other") }
        XCTAssertTrue(SuggestionEngine.suggestions(from: entries, rules: rules).isEmpty)
    }

    func testDismissedExtensionIsExcluded() {
        let entries = (0..<4).map { moved("file\($0).torrent", to: "Other") }
        let suggestions = SuggestionEngine.suggestions(from: entries, rules: rules, dismissed: ["torrent"])
        XCTAssertTrue(suggestions.isEmpty)
    }

    func testSuggestedRuleTargetsTheExtension() {
        let entries = (0..<3).map { moved("x\($0).psd", to: "Other") }
        let suggestion = SuggestionEngine.suggestions(from: entries, rules: rules).first
        XCTAssertEqual(suggestion?.rule.match, .extensions(["psd"]))
        XCTAssertEqual(suggestion?.rule.destination, "")
    }
}
