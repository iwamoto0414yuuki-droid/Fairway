import XCTest
@testable import SideSign

final class WatchSupportTests: XCTestCase {
    private let team = "TESTTEAM00"
    private let udid = "00000000-0000000000000001"
    private func profile(platform: String = "watchOS", bundle: String = "local.test.watch", target: String? = nil, expires: Date = Date().addingTimeInterval(3600)) throws -> ProvisioningProfile {
        let data: [String: Any] = ["Name": "Synthetic test", "UUID": UUID().uuidString,
            "TeamIdentifier": [team], "TeamName": "Synthetic", "CreationDate": Date(), "ExpirationDate": expires,
            "Entitlements": ["application-identifier": team + "." + bundle],
            "ProvisionedDevices": [target ?? udid], "Platform": [platform], "LocalProvision": true]
        let xml = try PropertyListSerialization.data(fromPropertyList: data, format: .xml, options: 0)
        // Parsing fixture only. This is deliberately not a cryptographically valid profile.
        return try ProvisioningProfile(data: Data("fixture-prefix".utf8) + xml)
    }
    private func host(at root: URL, companion: String = "local.test", child: String = "local.test.watch") throws -> AppBundle {
        let host = root.appendingPathComponent("Host.app")
        let watch = host.appendingPathComponent("Watch/Watch.app")
        try FileManager.default.createDirectory(at: watch, withIntermediateDirectories: true)
        for (url, id, extra) in [(host, "local.test", [:] as [String: Any]),
                                 (watch, child, ["WKApplication": true, "WKCompanionAppBundleIdentifier": companion])] {
            var dict: [String: Any] = ["CFBundleIdentifier": id, "CFBundleName": "Fixture", "CFBundlePackageType": "APPL", "CFBundleExecutable": "Fixture"]
            dict.merge(extra) { _, new in new }
            try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0).write(to: url.appendingPathComponent("Info.plist"))
        }
        return try XCTUnwrap(AppBundle(fileURL: host))
    }
    func testModernUDID() throws { XCTAssertEqual(try WatchBundleSupport.validateUDID(" " + udid + "\n"), udid) }
    func testLegacyUDID() throws { XCTAssertEqual(try WatchBundleSupport.validateUDID(String(repeating: "a", count: 40)).count, 40) }
    func testSerialNumberRejected() { XCTAssertThrowsError(try WatchBundleSupport.validateUDID("WATCHSERIAL123")) }
    func testEmptyUDIDRejected() { XCTAssertThrowsError(try WatchBundleSupport.validateUDID("")) }
    func testParentRewriteOnce() throws {
        XCTAssertEqual(try WatchBundleSupport.identifier("local.test.watch", from: "local.test", to: "local.test.TEAM"), "local.test.TEAM.watch")
    }
    func testPrefixCollisionRejected() { XCTAssertThrowsError(try WatchBundleSupport.identifier("local.testing.watch", from: "local.test", to: "new.id")) }
    func testUnrelatedBundleRejected() { XCTAssertThrowsError(try WatchBundleSupport.identifier("other.watch", from: "local.test", to: "new.id")) }
    func testValidWatchProfile() throws { try WatchBundleSupport.validate(profile(), bundleID: "local.test.watch", teamID: team, udid: udid) }
    func testPhoneProfileCannotSignWatch() throws { XCTAssertThrowsError(try WatchBundleSupport.validate(profile(platform: "iOS"), bundleID: "local.test.watch", teamID: team, udid: udid)) }
    func testWrongWatchRejected() throws { XCTAssertThrowsError(try WatchBundleSupport.validate(profile(target: "00000000-0000000000000002"), bundleID: "local.test.watch", teamID: team, udid: udid)) }
    func testExpiredProfileRejected() throws { XCTAssertThrowsError(try WatchBundleSupport.validate(profile(expires: Date().addingTimeInterval(-1)), bundleID: "local.test.watch", teamID: team, udid: udid)) }
    func testWrongTeamRejected() throws { XCTAssertThrowsError(try WatchBundleSupport.validate(profile(), bundleID: "local.test.watch", teamID: "OTHER", udid: udid)) }
    func testWrongIDRejected() throws { XCTAssertThrowsError(try WatchBundleSupport.validate(profile(), bundleID: "local.test.wrong", teamID: team, udid: udid)) }
    func testWatchGraph() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try host(at: root)
        XCTAssertEqual(try WatchBundleSupport.applications(in: app).count, 1)
        XCTAssertEqual(app.allAppBundles.count, 2)
    }
    func testWrongCompanionRejected() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertThrowsError(try WatchBundleSupport.applications(in: host(at: root, companion: "wrong.host")))
    }
    func testWrongChildIDRejected() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertThrowsError(try WatchBundleSupport.applications(in: host(at: root, child: "other.watch")))
    }
    func testWatchSymlinkOutsideHostRejected() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try host(at: root)
        let watch = app.fileURL.appendingPathComponent("Watch/Watch.app")
        let external = root.appendingPathComponent("Outside.app")
        try FileManager.default.moveItem(at: watch, to: external)
        try FileManager.default.createSymbolicLink(at: watch, withDestinationURL: external)
        XCTAssertThrowsError(try WatchBundleSupport.applications(in: app))
    }
}
