import XCTest
@testable import Fairway

final class Revision040Tests: XCTestCase {
    func testUserClubBagAndNewUtilityRoundTrip() throws {
        XCTAssertEqual(Club.bag.map(\.shortName), ["1W", "5W", "6UT", "5I", "6I", "7I", "8I", "9I", "PW", "PT"])
        let score = Score(strokes: 2, putts: 0, clubs: [.hybrid6, .sw])
        XCTAssertEqual(try JSONDecoder().decode(Score.self, from: JSONEncoder().encode(score)), score)
    }
    func testLegacyRoundWithoutDeletionDecodes() throws {
        let original = Round(course: "既存スコア", count: 9)
        let data = try JSONEncoder().encode(original)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("deletion"))
        XCTAssertFalse(try JSONDecoder().decode(Round.self, from: data).isDeleted)
    }
    func testDeletionCannotBeResurrectedByOldOrLaterScoreTransfer() {
        var deleted = Round(course: "Test", count: 9)
        var stale = deleted
        deleted.deletion = Value(value: true, revision: Revision(counter: 2, device: "phone"))
        stale.holes[0].score = Value(value: Score(strokes: 5, putts: 2), revision: Revision(counter: 10, device: "watch"))
        var a = Library(), b = Library()
        a.merge(deleted); a.merge(stale)
        b.merge(stale); b.merge(deleted)
        XCTAssertEqual(a, b)
        XCTAssertTrue(a.visibleRounds.isEmpty)
        XCTAssertTrue(a.rounds[0].isDeleted)
    }
    func testDeletePersistsAndBlocksStaleEditor() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("scores.json")
        let store = Store(fileURL: file, connectivity: false)
        let id = try XCTUnwrap(store.create(course: "Test", count: 9))
        XCTAssertTrue(store.saveScore(id, hole: 0, score: Score(strokes: 4, putts: 2), expected: .zero))
        let before = try XCTUnwrap(store.round(id))
        XCTAssertTrue(store.delete(id))
        XCTAssertNil(store.round(id))
        XCTAssertFalse(store.saveScore(id, hole: 0, score: Score(strokes: 5, putts: 2), expected: before.holes[0].score.revision))
        let reopened = Store(fileURL: file, connectivity: false)
        XCTAssertNil(reopened.round(id))
        XCTAssertTrue(reopened.library.visibleRounds.isEmpty)
        XCTAssertTrue(reopened.library.rounds[0].isDeleted)
        XCTAssertTrue(reopened.commit(before))
        XCTAssertNil(reopened.round(id))
    }
    func testDeletionRevisionAdvancesFutureEdits() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = Store(fileURL: folder.appendingPathComponent("scores.json"), connectivity: false)
        var imported = Round(course: "Test", count: 9)
        imported.deletion = Value(value: true, revision: Revision(counter: 50, device: "other"))
        XCTAssertTrue(store.commit(imported))
        let id = try XCTUnwrap(store.create(course: "New", count: 9))
        XCTAssertTrue(store.saveScore(id, hole: 0, score: Score(strokes: 1, putts: 0), expected: .zero))
        XCTAssertGreaterThan(try XCTUnwrap(store.round(id)).maxCounter, 50)
    }
    func testInvalidDeletionRevisionRejected() {
        var round = Round(course: "Test", count: 9)
        round.deletion = Value(value: true, revision: Revision(counter: -1, device: "bad"))
        XCTAssertFalse(round.isValid)
    }
}
