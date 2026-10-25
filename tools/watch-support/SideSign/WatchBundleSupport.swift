// Personal experimental Watch support. See SOURCE.md for upstream and license.
import Foundation

public enum WatchSupportError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? {
        switch self { case .invalid(let message): return message }
    }
}

public enum WatchBundleSupport {
    public static func applications(in host: AppBundle) throws -> [AppBundle] {
        let directory = host.fileURL.appendingPathComponent("Watch")
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        let root = host.fileURL.resolvingSymlinksInPath().path + "/"
        let children = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        return try children.filter { $0.pathExtension == "app" }.sorted { $0.path < $1.path }.map { url in
            guard url.resolvingSymlinksInPath().path.hasPrefix(root), let app = AppBundle(fileURL: url),
                  app.infoPlist["WKCompanionAppBundleIdentifier"] as? String == host.bundleIdentifier,
                  app.bundleIdentifier.hasPrefix(host.bundleIdentifier + ".") else {
                throw WatchSupportError.invalid("Watchアプリの構成または親子IDが一致していません。元の完全版IPAを使用してください。")
            }
            return app
        }
    }

    public static func identifier(_ child: String, from original: String, to rewritten: String) throws -> String {
        guard child.hasPrefix(original + ".") else {
            throw WatchSupportError.invalid("WatchのBundle IDがiPhoneアプリの配下にありません。")
        }
        return rewritten + child.dropFirst(original.count)
    }

    public static func validateUDID(_ text: String) throws -> String {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let oldStyle = value.range(of: "^[a-fA-F0-9]{40}$", options: .regularExpression) != nil
        let newStyle = value.range(of: "^[a-fA-F0-9]{8}-[a-fA-F0-9]{16}$", options: .regularExpression) != nil
        guard oldStyle || newStyle else {
            throw WatchSupportError.invalid("WatchのUDIDを入力してください。シリアル番号とは異なります。")
        }
        return value
    }

    /// Values shared by the install pipeline and offline real-IPA signing tests.
    public static func relationships(in info: [String: Any], from original: String, to rewritten: String) throws -> [String: Any] {
        var values: [String: Any] = [:]
        if let companion = info["WKCompanionAppBundleIdentifier"] as? String {
            guard companion == original else { throw WatchSupportError.invalid("Watchの親アプリIDが一致しません。") }
            values["WKCompanionAppBundleIdentifier"] = rewritten
        }
        if var ext = info["NSExtension"] as? [String: Any], var attrs = ext["NSExtensionAttributes"] as? [String: Any], let parent = attrs["WKAppBundleIdentifier"] as? String {
            attrs["WKAppBundleIdentifier"] = try identifier(parent, from: original, to: rewritten)
            ext["NSExtensionAttributes"] = attrs
            values["NSExtension"] = ext
        }
        return values
    }

    public static func validate(_ profile: ProvisioningProfile, bundleID: String, teamID: String, udid: String, now: Date = Date(), allowIOSFamily: Bool = false) throws {
        let dictionary = try ProvisioningProfile.dictionary(fromEncodedData: profile.data)
        let platforms = dictionary["Platform"] as? [String] ?? []
        var failures: [String] = []
        // iOS development profiles also cover watchOS. The companion workflow
        // enables this only after watch-scoped registration/profile retrieval.
        // Watch UDID, exact child ID, team, expiry and signing cert still gate use.
        let normalized = Set(platforms.map { $0.lowercased() })
        let watchPlatform = normalized.contains("watchos")
        let scopedIOSFamily = allowIOSFamily && normalized.contains("ios")
            && normalized.isSubset(of: Set(["ios", "xros", "visionos"]))
        if !watchPlatform && !scopedIOSFamily {
            // OS names are public metadata; never expose arbitrary profile values.
            let known = platforms.compactMap { value -> String? in
                ["iOS", "watchOS", "tvOS", "macOS", "visionOS"].first { $0.caseInsensitiveCompare(value) == .orderedSame }
            }.joined(separator: ",")
            failures.append("WPF_PLATFORM（OS種別: " + (known.isEmpty ? "不明または欠落" : known) + "）")
        }
        if profile.bundleIdentifier != bundleID { failures.append("WPF_APP_ID（アプリID）") }
        if profile.teamIdentifier != teamID { failures.append("WPF_TEAM（チーム）") }
        if !profile.deviceIDs.contains(where: { $0.caseInsensitiveCompare(udid) == .orderedSame }) {
            failures.append("WPF_DEVICE（Watch端末）")
        }
        if profile.expirationDate <= now { failures.append("WPF_EXPIRED（期限）") }
        if !failures.isEmpty {
            throw WatchSupportError.invalid("Watch用プロファイルの検査NG: " + failures.joined(separator: " / ") + "。インストールを停止しました。")
        }
    }
}

public extension AppBundle {
    var watchApplications: [AppBundle] { (try? WatchBundleSupport.applications(in: self)) ?? [] }
    var watchSigningBundles: [AppBundle] {
        watchApplications.flatMap { [$0] + Array($0.appExtensions).sorted { $0.fileURL.path < $1.fileURL.path } }
    }
}

public extension DeveloperPortal {
    // Existing SideStore sessions are supplied by the caller; this does not authenticate or revoke certificates.
    func registerWatch(name: String, udid: String, team: Team, session: Session) async throws {
        let udid = try WatchBundleSupport.validateUDID(udid)
        let listed: ListDevicesResponse = try await sendRequest(url: Constants.URLs.listDevices,
            additionalParameters: ["DTDK_Platform": "watchos"], session: session, team: team)
        if listed.devices?.contains(where: { $0.identifier.caseInsensitiveCompare(udid) == .orderedSame }) == true { return }
        let _: DeviceResponse = try await sendRequest(url: Constants.URLs.addDevice,
            additionalParameters: ["DTDK_Platform": "watchos", "deviceNumber": udid, "name": name], session: session, team: team)
    }

    func watchProfile(bundleID: String, name: String, team: Team, session: Session) async throws -> ProvisioningProfile {
        let list: ListAppIDsResponse = try await sendRequest(url: Constants.URLs.listAppIDs,
            additionalParameters: ["DTDK_Platform": "watchos"], session: session, team: team)
        let appID: AppID
        if let existing = list.appIds?.first(where: { $0.bundleIdentifier == bundleID }) {
            appID = existing
        } else {
            let added: AppIDResponse = try await sendRequest(url: Constants.URLs.addAppID,
                additionalParameters: ["DTDK_Platform": "watchos", "name": name, "identifier": bundleID], session: session, team: team)
            guard let value = added.appId else { throw WatchSupportError.invalid("Watch用App IDを取得できませんでした。") }
            appID = value
        }
        let result: ProfileResponse = try await sendRequest(url: Constants.URLs.downloadProvisioningProfile,
            additionalParameters: ["DTDK_Platform": "watchos", "appIdId": appID.identifier], session: session, team: team)
        guard let profile = try result.provisioningProfile?.toProvisioningProfile() else {
            throw WatchSupportError.invalid("Watch用プロファイルを取得できませんでした。")
        }
        return profile
    }
}
