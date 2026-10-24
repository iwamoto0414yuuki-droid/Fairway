import XCTest
@testable import Fairway

final class CoreTests: XCTestCase {
    func stamp(_ counter: Int, _ device: String = "phone") -> Revision { Revision(counter: counter, device: device) }
    func testUnplayedIsNotPar() {
        let round = Round(course: "Test", count: 18)
        XCTAssertEqual(round.played, 0); XCTAssertEqual(round.total, 0); XCTAssertEqual(round.relative, 0)
    }
    func testPlayedHolesOnlyContributeToRelativeScore() {
        var round = Round(course: "Test", count: 9)
        round.holes[0].score = Value(value: Score(strokes: 5, putts: 2), revision: stamp(1))
        round.holes[1].par.value = 3
        round.holes[1].score = Value(value: Score(strokes: 2, putts: nil), revision: stamp(2))
        XCTAssertEqual(round.played, 2); XCTAssertEqual(round.total, 7); XCTAssertEqual(round.relativeText, "E")
    }
    func testDifferentHoleEditsSurviveOfflineMerge() {
        let original = Round(course: "Test", count: 18)
        var phone = original, watch = original
        phone.holes[0].score = Value(value: Score(strokes: 4, putts: nil), revision: stamp(1, "phone"))
        watch.holes[1].score = Value(value: Score(strokes: 5, putts: 2), revision: stamp(1, "watch"))
        let phoneCopy = phone; phone.merge(watch); watch.merge(phoneCopy)
        XCTAssertEqual(phone, watch); XCTAssertEqual(phone.total, 9)
    }
    func testSameHoleConflictHasDeterministicWinner() {
        var a = Round(course: "Test", count: 9), b: Round
        b = a
        a.holes[0].score = Value(value: Score(strokes: 4, putts: nil), revision: stamp(3, "a"))
        b.holes[0].score = Value(value: Score(strokes: 6, putts: nil), revision: stamp(3, "b"))
        let before = a; a.merge(b); b.merge(before)
        XCTAssertEqual(a, b); XCTAssertEqual(a.total, 6)
    }
    func testMapUpdateDoesNotEraseScore() {
        var a = Round(course: "Test", count: 9), b: Round; b = a
        a.holes[0].score = Value(value: Score(strokes: 4, putts: 2), revision: stamp(1, "a"))
        b.holes[0].green = Value(value: Coordinate(latitude: 35, longitude: 140), revision: stamp(1, "b"))
        a.merge(b); XCTAssertEqual(a.total, 4); XCTAssertNotNil(a.holes[0].green.value)
    }
    func testClearTombstoneSurvivesOldTransfer() {
        var a = Round(course: "Test", count: 9)
        a.holes[0].score = Value(value: Score(strokes: 4, putts: 2), revision: stamp(1))
        let old = a
        a.holes[0].score = Value(value: nil, revision: stamp(2))
        a.merge(old); XCTAssertEqual(a.played, 0)
    }
    func testDuplicateTransferIsIdempotent() {
        var library = Library(); let round = Round(course: "Test", count: 9)
        library.merge(round); let before = library; library.merge(round)
        XCTAssertEqual(library, before)
    }
    func testReorderedTransfersConverge() {
        var older = Round(course: "Test", count: 9)
        older.holes[0].score = Value(value: Score(strokes: 5, putts: nil), revision: stamp(1))
        var newer = older
        newer.holes[0].score = Value(value: Score(strokes: 4, putts: nil), revision: stamp(2))
        var a = Library(), b = Library()
        a.merge(older); a.merge(newer); b.merge(newer); b.merge(older)
        XCTAssertEqual(a, b)
    }
    func testScoresValidate() {
        XCTAssertFalse(Score(strokes: 0, putts: nil).isValid)
        XCTAssertFalse(Score(strokes: 31, putts: nil).isValid)
        XCTAssertFalse(Score(strokes: 3, putts: 4).isValid)
        XCTAssertTrue(Score(strokes: 1, putts: 0).isValid)
        XCTAssertTrue(Score(strokes: 30, putts: nil).isValid)
    }
    func testCoordinatesValidate() {
        XCTAssertFalse(Coordinate(latitude: 91, longitude: 0).isValid)
        XCTAssertFalse(Coordinate(latitude: .nan, longitude: 0).isValid)
        XCTAssertTrue(Coordinate(latitude: 0, longitude: 0).isValid)
    }
    func testKnownDistance() {
        let a = Coordinate(latitude: 0, longitude: 0), b = Coordinate(latitude: 0, longitude: 0.001)
        XCTAssertEqual(a.meters(to: b), 111.195, accuracy: 0.01)
        XCTAssertEqual(a.meters(to: a), 0, accuracy: 0.001)
    }
    func testRoundTripPreservesNilAndRevisions() throws {
        var round = Round(course: "日本語のコース", count: 18)
        round.holes[0].score = Value(value: nil, revision: stamp(8))
        let data = try JSONEncoder().encode(round)
        XCTAssertEqual(try JSONDecoder().decode(Round.self, from: data), round)
    }
    func testInvalidRoundRejected() {
        var round = Round(course: "Test", count: 9); round.holes[0].par.value = 0
        var library = Library(); library.merge(round); XCTAssertTrue(library.rounds.isEmpty)
    }
    func testFinishDoesNotEraseLateScore() {
        var a = Round(course: "Test", count: 9), b: Round; b = a
        a.finished = Value(value: true, revision: stamp(2, "phone"))
        b.holes[0].score = Value(value: Score(strokes: 5, putts: 2), revision: stamp(1, "watch"))
        a.merge(b); XCTAssertTrue(a.finished.value); XCTAssertEqual(a.total, 5)
    }
    func testTransferSize() throws {
        let data = try JSONEncoder().encode(Round(course: String(repeating: "あ", count: 80), count: 18))
        XCTAssertLessThan(data.count, 60_000)
    }
}
