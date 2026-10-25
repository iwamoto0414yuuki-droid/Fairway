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
        XCTAssertTrue(store.saveScore(id, hole: 0, score: Score(strokes: 5, putts: 2, clubs: [.driver, .iron7, .sw, .putter, .putter]), expected: .zero))
        XCTAssertTrue(store.saveScore(id, hole: 9, score: Score(strokes: 4, putts: nil), expected: .zero))
        snapshot(HomeView().environmentObject(store), name: "native-home")
        snapshot(NavigationStack { RoundView(id: id) }.environmentObject(store), name: "native-card")
        let round = try XCTUnwrap(store.round(id))
        snapshot(NavigationStack { ScoreEntry(id: id, holeIndex: 0, initial: round.holes[0]) }.environmentObject(store), name: "native-score")
        let selected: [Club?] = [.driver, .iron7, .sw, .putter, .putter] + Array<Club?>(repeating: nil, count: 25)
        snapshot(NavigationStack { ClubEditor(clubs: .constant(selected), strokes: 5) }, name: "native-clubs")
        snapshot(NavigationStack { ClubChoiceGrid(stroke: 1, selected: .driver, onSelect: { _ in true }) }, name: "native-club-grid")
        snapshot(NavigationStack { SavedRoundView(id: id) }.environmentObject(store), name: "native-saved")
    }
    private func snapshot<V: View>(_ view: V, name: String) {
        let controller = UIHostingController(rootView: view.tint(fairwayGreen).preferredColorScheme(.dark))
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            XCTFail("A connected UIWindowScene is required for a native screenshot"); return
        }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.rootViewController = controller; window.makeKeyAndVisible()
        controller.view.frame = window.bounds; controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        XCTAssertGreaterThan(image.size.width, 0)
        if let cg = image.cgImage, let bytes = cg.dataProvider?.data,
           let pointer = CFDataGetBytePtr(bytes) {
            var colors = Set<UInt32>()
            for y in stride(from: 0, to: cg.height, by: 7) {
                for x in stride(from: 0, to: cg.width, by: 7) {
                    let offset = y * cg.bytesPerRow + x * 4
                    if offset + 3 < CFDataGetLength(bytes) {
                        colors.insert(UInt32(pointer[offset]) << 16 | UInt32(pointer[offset + 1]) << 8 | UInt32(pointer[offset + 2]))
                    }
                }
            }
            XCTAssertGreaterThan(colors.count, 16, "Blank or unrendered screenshot: \(name)")
        } else { XCTFail("Could not inspect rendered pixels") }
        let attachment = XCTAttachment(image: image); attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment); window.isHidden = true
    }
}
