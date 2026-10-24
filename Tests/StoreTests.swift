import XCTest
@testable import Fairway

final class StoreTests: XCTestCase {
    var directory: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }
    func testSaveAndReload() throws {
        let file = directory.appendingPathComponent("rounds.json")
        let store = Store(fileURL: file, connectivity: false)
        let id = try XCTUnwrap(store.create(course: "Test", count: 9))
        XCTAssertTrue(store.saveScore(id, hole: 0, score: Score(strokes: 5, putts: 2), expected: .zero))
        let reopened = Store(fileURL: file, connectivity: false)
        XCTAssertEqual(reopened.round(id)?.total, 5)
    }
    func testStaleEditorRejected() throws {
        let store = Store(fileURL: directory.appendingPathComponent("rounds.json"), connectivity: false)
        let id = try XCTUnwrap(store.create(course: "Test", count: 9))
        XCTAssertTrue(store.saveScore(id, hole: 0, score: Score(strokes: 5, putts: 2), expected: .zero))
        XCTAssertFalse(store.saveScore(id, hole: 0, score: Score(strokes: 6, putts: 2), expected: .zero))
        XCTAssertEqual(store.round(id)?.total, 5)
    }
    func testCorruptFileIsPreserved() throws {
        let file = directory.appendingPathComponent("rounds.json")
        let original = Data("broken".utf8); try original.write(to: file)
        let store = Store(fileURL: file, connectivity: false)
        XCTAssertNotNil(store.error)
        XCTAssertNil(store.create(course: "Do not overwrite", count: 9))
        XCTAssertEqual(try Data(contentsOf: file), original)
    }
    func testTemplateCopiesCourseButNotScores() throws {
        let store = Store(fileURL: directory.appendingPathComponent("rounds.json"), connectivity: false)
        let id = try XCTUnwrap(store.create(course: "Test", count: 9))
        XCTAssertTrue(store.configure(id, hole: 0, par: 3, green: Coordinate(latitude: 35, longitude: 140)))
        XCTAssertTrue(store.saveScore(id, hole: 0, score: Score(strokes: 4, putts: 2), expected: .zero))
        let source = try XCTUnwrap(store.round(id))
        let newID = try XCTUnwrap(store.create(course: "", count: 9, template: source))
        let copy = try XCTUnwrap(store.round(newID))
        XCTAssertNotEqual(id, newID); XCTAssertEqual(copy.played, 0)
        XCTAssertEqual(copy.holes[0].par.value, 3); XCTAssertEqual(copy.holes[0].green.value, source.holes[0].green.value)
    }
}
