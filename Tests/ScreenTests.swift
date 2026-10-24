import XCTest
import SwiftUI
@testable import Fairway

@MainActor
final class ScreenTests: XCTestCase {
    func testNativeScreens() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = Store(fileURL: directory.appendingPathComponent("rounds.json"), connectivity: false)
        let id = try XCTUnwrap(store.create(course: "サンプルコース", count: 18))
        XCTAssertTrue(store.configure(id, hole: 0, par: 4, green: Coordinate(latitude: 35.6, longitude: 140.1)))
        XCTAssertTrue(store.saveScore(id, hole: 0, score: Score(strokes: 5, putts: 2), expected: .zero))
        snapshot(HomeView().environmentObject(store), name: "native-home")
        snapshot(NavigationStack { RoundView(id: id) }.environmentObject(store), name: "native-card")
        let round = try XCTUnwrap(store.round(id))
        snapshot(NavigationStack { ScoreEntry(id: id, holeIndex: 0, initial: round.holes[0]) }.environmentObject(store), name: "native-score")
    }
    private func snapshot<V: View>(_ view: V, name: String) {
        let controller = UIHostingController(rootView: view.tint(fairwayGreen).preferredColorScheme(.dark))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller; window.makeKeyAndVisible()
        controller.view.frame = window.bounds; controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        XCTAssertGreaterThan(image.size.width, 0)
        let attachment = XCTAttachment(image: image); attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment); window.isHidden = true
    }
}
