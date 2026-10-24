import XCTest
@testable import Fairway

final class UpdateTests: XCTestCase {
    func testFrontBackAndIncompletePutts() {
        var round = Round(course: "Test", count: 18)
        for index in 0..<9 { round.holes[index].score.value = Score(strokes: 4, putts: index == 1 ? nil : 2) }
        round.holes[9].score.value = Score(strokes: 5, putts: 0)
        round.holes[17].score.value = Score(strokes: 3, putts: nil)
        XCTAssertEqual(round.frontSummary.strokes, 36)
        XCTAssertEqual(round.frontSummary.putts, 16)
        XCTAssertEqual(round.frontSummary.puttsRecorded, 8)
        XCTAssertEqual(round.backSummary?.strokes, 8)
        XCTAssertEqual(round.backSummary?.played, 2)
        XCTAssertEqual(round.backSummary?.puttsRecorded, 1)
        XCTAssertEqual(round.summary.strokes, 44)
        XCTAssertEqual(round.summary.puttsRecorded, 9)
    }
    func testNoPuttsIsNotZeroPutts() {
        var round = Round(course: "Test", count: 9)
        XCTAssertEqual(round.summary.strokesText, "—")
        XCTAssertEqual(round.summary.puttsText, "未記録")
        round.holes[0].score.value = Score(strokes: 1, putts: 0)
        XCTAssertEqual(round.summary.puttsText, "0")
        XCTAssertEqual(round.summary.puttsRecorded, 1)
    }
    func testNineHolesHasNoBackNine() {
        let round = Round(course: "Test", count: 9)
        XCTAssertNil(round.backSummary)
        XCTAssertEqual(round.frontSummary, round.summary)
    }
    func testLegacyLibraryWithoutClubFieldDecodes() throws {
        var library = Library()
        var old = Round(course: "既存コース", count: 18)
        old.holes[0].score = Value(value: Score(strokes: 5, putts: 2), revision: Revision(counter: 7, device: "old"))
        library.merge(old)
        let data = try JSONEncoder().encode(library)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains("clubs"))
        let decoded = try JSONDecoder().decode(Library.self, from: data)
        XCTAssertEqual(decoded, library)
        XCTAssertNil(decoded.rounds[0].holes[0].score.value?.clubs)
        XCTAssertEqual(decoded.rounds[0].total, 5)
    }
    func testClubRoundTripAndOfflineMerge() throws {
        var phone = Round(course: "Test", count: 18), watch: Round
        watch = phone
        phone.holes[0].score = Value(value: Score(strokes: 4, putts: 2, clubs: [.driver, .iron7, .putter, .putter]), revision: Revision(counter: 1, device: "phone"))
        watch.holes[9].score = Value(value: Score(strokes: 3, putts: nil, clubs: [.iron8, nil, .penalty]), revision: Revision(counter: 1, device: "watch"))
        let copy = phone; phone.merge(watch); watch.merge(copy)
        XCTAssertEqual(phone, watch)
        XCTAssertEqual(phone.holes[0].score.value?.clubsRecorded, 4)
        XCTAssertEqual(phone.holes[9].score.value?.clubsRecorded, 2)
        XCTAssertEqual(try JSONDecoder().decode(Round.self, from: JSONEncoder().encode(phone)), phone)
    }
    func testClubCountMustMatchStrokesAndCanBePartial() {
        XCTAssertFalse(Score(strokes: 2, putts: nil, clubs: [.driver]).isValid)
        XCTAssertTrue(Score(strokes: 2, putts: nil, clubs: [.driver, nil]).isValid)
        XCTAssertTrue(Score(strokes: 2, putts: nil).isValid)
    }
    func testCSVIncludesClubsAndSummaryCoverage() {
        var round = Round(course: "Test", count: 18)
        round.holes[0].score.value = Score(strokes: 3, putts: 1, clubs: [.driver, nil, .putter])
        XCTAssertTrue(round.csv.contains("1,4,3,1,1W / — / PT"))
        XCTAssertTrue(round.csv.contains("Front9,1,3,1,1"))
        XCTAssertTrue(round.csv.contains("Back9,0,,,0"))
        XCTAssertTrue(round.csv.contains("Total,1,3,1,1"))
    }
    func testFullyRecordedClubPayloadStaysSmall() throws {
        var round = Round(course: "Test", count: 18)
        for index in round.holes.indices {
            round.holes[index].score.value = Score(strokes: 30, putts: 2, clubs: Array(repeating: .driver, count: 30))
        }
        XCTAssertTrue(round.isValid)
        XCTAssertLessThan(try JSONEncoder().encode(round).count, 60_000)
    }
    func testSavedClubsAndSummariesSurviveRestart() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("rounds.json")
        let store = Store(fileURL: file, connectivity: false)
        let id = try XCTUnwrap(store.create(course: "Test", count: 18))
        XCTAssertTrue(store.saveScore(id, hole: 9, score: Score(strokes: 4, putts: 2, clubs: [.driver, .sw, .putter, .putter]), expected: .zero))
        let reopened = Store(fileURL: file, connectivity: false)
        XCTAssertEqual(reopened.round(id)?.backSummary?.strokes, 4)
        XCTAssertEqual(reopened.round(id)?.summary.putts, 2)
        XCTAssertEqual(reopened.round(id)?.holes[9].score.value?.clubs, [.driver, .sw, .putter, .putter])
    }
    func testOldFileCanBeUpdatedWithoutLosingHistory() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("rounds.json")
        var library = Library(), old = Round(course: "Old", count: 9)
        old.holes[0].score.value = Score(strokes: 4, putts: nil)
        library.merge(old); try JSONEncoder().encode(library).write(to: file)
        let store = Store(fileURL: file, connectivity: false)
        XCTAssertNil(store.error)
        XCTAssertTrue(store.saveScore(old.id, hole: 1, score: Score(strokes: 3, putts: 1, clubs: [.iron7, .sw, .putter]), expected: .zero))
        let updated = Store(fileURL: file, connectivity: false)
        XCTAssertEqual(updated.round(old.id)?.total, 7)
        XCTAssertEqual(updated.round(old.id)?.holes[0].score.value?.strokes, 4)
    }
}
