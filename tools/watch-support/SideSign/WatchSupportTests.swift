import XCTest
import CodeSignKit
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
        XCTAssertEqual(app.watchSigningBundles.count, 1)
        // Keep the existing phone customization pipeline's bundle set unchanged.
        XCTAssertEqual(app.allAppBundles.count, 1)
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

    #if os(macOS)
    func testNestedWatchReceivesItsOwnSignedEntitlements() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try host(at: root)
        func command(_ executable: String, _ arguments: [String]) throws -> Data {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            let output = Pipe(); let errors = Pipe()
            process.standardOutput = output; process.standardError = errors
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            let error = errors.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw WatchSupportError.invalid("Offline fixture command failed: " + String(decoding: error, as: UTF8.self))
            }
            if arguments.contains("--entitlements") {
                let combined = String(decoding: data + error, as: UTF8.self)
                guard let begin = combined.range(of: "<?xml"), let end = combined.range(of: "</plist>") else {
                    throw WatchSupportError.invalid("Apple codesign did not return XML entitlements: " + String(combined.prefix(2000)))
                }
                return Data(combined[begin.lowerBound..<end.upperBound].utf8)
            }
            return data
        }
        let source = root.appendingPathComponent("fixture.c")
        try Data("int main(void) { return 0; }".utf8).write(to: source)
        let phoneSDK = String(decoding: try command("/usr/bin/xcrun", ["--sdk", "iphoneos", "--show-sdk-path"]), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let watchSDK = String(decoding: try command("/usr/bin/xcrun", ["--sdk", "watchos", "--show-sdk-path"]), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try command("/usr/bin/xcrun", ["clang", "-target", "arm64-apple-ios17.0", "-isysroot", phoneSDK, source.path, "-o", app.fileURL.appendingPathComponent("Fixture").path])
        let watchURL = app.fileURL.appendingPathComponent("Watch/Watch.app")
        _ = try command("/usr/bin/xcrun", ["clang", "-target", "arm64_32-apple-watchos10.0", "-isysroot", watchSDK, source.path, "-o", watchURL.appendingPathComponent("Fixture").path])
        let key = root.appendingPathComponent("fixture-key.pem")
        let cert = root.appendingPathComponent("fixture-cert.pem")
        let p12 = root.appendingPathComponent("fixture.p12")
        let config = root.appendingPathComponent("fixture.cnf")
        try """
        [req]
        distinguished_name = dn
        x509_extensions = code_signing
        prompt = no
        [dn]
        CN = Offline Watch Test
        OU = \(team)
        [code_signing]
        basicConstraints = critical,CA:FALSE
        keyUsage = critical,digitalSignature
        extendedKeyUsage = critical,codeSigning
        """.write(to: config, atomically: true, encoding: .utf8)
        _ = try command("/usr/bin/openssl", ["req", "-x509", "-newkey", "rsa:2048", "-sha256", "-nodes", "-days", "1", "-config", config.path, "-keyout", key.path, "-out", cert.path])
        _ = try command("/usr/bin/openssl", ["pkcs12", "-export", "-inkey", key.path, "-in", cert.path, "-out", p12.path, "-passout", "pass:fixture"])
        let identity = try KeyStore(p12Data: Data(contentsOf: p12), password: "fixture")
        let signer = AppBundleSigner(team: Team(identifier: team, name: "Offline", type: .free), keyStore: identity)
        try await signer.signApp(at: app.fileURL, provisioningProfiles: [profile(platform: "iOS", bundle: "local.test"), profile()])
        let rawEntitlements = try MachOParser.entitlements(at: watchURL)
        XCTAssertFalse(rawEntitlements.isEmpty, "Watch executable has no entitlements after signing")
        let embedded = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(rawEntitlements.utf8), options: [], format: nil) as? [String: Any])
        XCTAssertEqual(embedded["application-identifier"] as? String, team + ".local.test.watch")
        // Verifies nested Mach-O signatures and resource seals; this is not Apple provisioning approval.
        _ = try command("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.fileURL.path])
        let watchEntitlements = try command("/usr/bin/codesign", ["--display", "--entitlements", "-", "--xml", watchURL.path])
        let values = try XCTUnwrap(PropertyListSerialization.propertyList(from: watchEntitlements, options: [], format: nil) as? [String: Any])
        XCTAssertEqual(values["application-identifier"] as? String, team + ".local.test.watch")
    }
    #endif
}
