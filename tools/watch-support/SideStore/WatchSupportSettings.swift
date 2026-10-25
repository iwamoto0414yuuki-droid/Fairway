// Personal experimental build; not an official SideStore release.
import SwiftUI
import SideSign

enum WatchSupportSettings {
    static let udidKey = "FairwayWatchSupportUDID"
    static var udid: String { UserDefaults.standard.string(forKey: udidKey) ?? "" }

    static func prepare(host: ALTApplication, hostProfile: ALTProvisioningProfile, certificate: ALTCertificate) async throws -> [String: ALTProvisioningProfile] {
        let watches = try WatchBundleSupport.applications(in: host)
        guard !watches.isEmpty else { return [:] }
        let udid = try WatchBundleSupport.validateUDID(Self.udid)
        let session = try await AuthManager.shared.getAuthenticatedSession()
        let team = try await AuthManager.shared.getAuthenticatedTeam()
        try await ALTAppleAPI.shared.registerWatch(name: "Fairway Watch", udid: udid, team: team, session: session)
        var profiles: [String: ALTProvisioningProfile] = [:]
        for app in host.watchSigningBundles {
            let id = try WatchBundleSupport.identifier(app.bundleIdentifier, from: host.bundleIdentifier, to: hostProfile.bundleIdentifier)
            let profile = try await ALTAppleAPI.shared.watchProfile(bundleID: id, name: "Fairway Watch", team: team, session: session)
            try WatchBundleSupport.validate(profile, bundleID: id, teamID: team.identifier, udid: udid, allowIOSFamily: true)
            guard profile.certificates.contains(where: { $0.serialNumberHex == certificate.certificate.serialNumberHex }) else {
                throw WatchSupportError.invalid("Watch用プロファイルに現在の署名証明書が含まれていません。証明書は変更せず停止しました。")
            }
            profiles[id] = profile
        }
        return profiles
    }
}

struct WatchSupportSettingsView: View {
    @State private var udid = WatchSupportSettings.udid
    @State private var message = ""
    @State private var busy = false
    var body: some View {
        SwiftUI.Form {
            Section("Watch対応・個人用試験版") {
                Text("既存のログインと証明書を利用します。無料アカウントでのWatch実機導入は検証中です。")
                TextField("WatchのUDID", text: $udid)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                SwiftUI.Button("Watchの登録を確認") { register() }.disabled(busy)
                if busy { ProgressView() }
                if !message.isEmpty { Text(message).font(.footnote) }
            }
            Section("使い方") {
                Text("WindowsのWatch情報ツールで表示されたWatchのUDIDを入力してください。値はこの端末だけに保存します。")
                Text("登録後、My Appsの＋からFairwayの元の完全版IPAを選択します。Watchには専用のプロファイルを取得し、Refresh時にも再署名します。")
                Text("iPhoneへの導入後、WatchアプリからFairwayをインストールしてください。Watchで起動できるまでは導入成功とは扱いません。")
            }
        }.navigationTitle("Watch対応")
    }
    private func register() {
        busy = true; message = ""
        Task { @MainActor in
            defer { busy = false }
            do {
                let normalized = try WatchBundleSupport.validateUDID(udid)
                let session = try await AuthManager.shared.getAuthenticatedSession()
                let team = try await AuthManager.shared.getAuthenticatedTeam()
                try await ALTAppleAPI.shared.registerWatch(name: "Fairway Watch", udid: normalized, team: team, session: session)
                UserDefaults.standard.set(normalized, forKey: WatchSupportSettings.udidKey)
                message = "Watch登録を確認しました。次にFairwayのIPAを導入してください。"
            } catch { message = error.localizedDescription }
        }
    }
}
