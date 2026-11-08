import XCTest
@testable import Fairway

final class CounterTests: XCTestCase {
    func testUnplayedHoleHasNoScore() { XCTAssertNil(CounterDraft(score: nil).score) }
    func testPuttIsAlsoAStroke() {
        var draft = CounterDraft(score: Score(strokes: 3, putts: 0))
        draft.changePutt(1)
        XCTAssertEqual(draft.score, Score(strokes: 4, putts: 1))
    }
    func testUndoAllPuttHoleOnce() {
        var draft = CounterDraft(score: Score(strokes: 2, putts: 2))
        draft.changePutt(-1)
        XCTAssertEqual(draft.score, Score(strokes: 1, putts: 1))
    }
    func testUndoLastStrokeReturnsUnplayed() {
        var draft = CounterDraft(score: Score(strokes: 1, putts: 0))
        draft.changeStroke(-1)
        XCTAssertNil(draft.score)
    }
    func testRemovingStrokeDoesNotLeaveOrphanClubs() {
        var draft = CounterDraft(score: Score(strokes: 3, putts: 0, clubs: [.driver, .iron7, .sw]))
        draft.changeStroke(-1); draft.changeStroke(1)
        XCTAssertEqual(draft.score?.clubs, [.driver, .iron7, nil])
    }
    func testPuttCannotExceedMaximumStrokes() {
        var draft = CounterDraft(score: Score(strokes: 30, putts: 2))
        draft.changePutt(1)
        XCTAssertEqual(draft.score, Score(strokes: 30, putts: 2))
    }
    func testUndoPuttAtZeroDoesNotRemoveAStroke() {
        var draft = CounterDraft(score: Score(strokes: 3, putts: 0))
        draft.changePutt(-1)
        XCTAssertEqual(draft.score, Score(strokes: 3, putts: 0))
    }
    func testUndoPuttAndPenaltyPreservesLaterClubRecords() {
        var draft = CounterDraft(score: Score(strokes: 1, putts: 0, clubs: [.driver]))
        draft.changePutt(1, markClub: true)
        draft.changePenalty(1)
        draft.changeStroke(1)
        draft.clubs[3] = .iron7
        XCTAssertEqual(draft.score?.strokes, 4)
        XCTAssertEqual(draft.score?.penaltyStrokes, 1)
        draft.changePutt(-1)
        draft.changePenalty(-1)
        XCTAssertEqual(draft.score, Score(strokes: 2, putts: 0, clubs: [.driver, .iron7]))
    }
    func testCourseSelectionSyncsWithoutOverwritingScores() throws {
        var earlier = Round(course: "Test", count: 18)
        earlier.holes[0].score = Value(value: Score(strokes: 4, putts: 2))
        var updated = earlier
        updated.courses = Value(value: CourseSelection(front: .east, back: .west),
                                revision: Revision(counter: 1, device: "watch"))
        earlier.merge(updated)
        let restored = try JSONDecoder().decode(Round.self, from: JSONEncoder().encode(earlier))
        XCTAssertEqual(restored.holeTitle(0), "東 1H")
        XCTAssertEqual(restored.holeTitle(9), "西 1H")
        XCTAssertEqual(restored.total, 4)
    }
    func testLocalCounterSaveSurvivesRelaunchWithoutSync() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("scores.json")
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let store = Store(fileURL: file, connectivity: false)
        let id = try XCTUnwrap(store.create(course: "Test", count: 9))
        var draft = CounterDraft(score: nil)
        draft.changeStroke(1); draft.changePutt(1)
        XCTAssertTrue(store.saveScore(id, hole: 0, score: draft.score, expected: .zero, send: false))
        XCTAssertEqual(Store(fileURL: file, connectivity: false).round(id)?.holes[0].score.value, draft.score)
    }
}
