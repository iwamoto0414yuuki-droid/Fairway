from pathlib import Path
import sys

def change(path, before, after):
    text = path.read_text(encoding='utf-8')
    if text.count(before) != 1:
        raise RuntimeError('unexpected source: '+str(path)+' '+before[:60])
    path.write_text(text.replace(before, after), encoding='utf-8', newline='\n')

def apply(store):
    op=store/'SideStore/Core/Operations/PipelineOperations/FetchProvisioningProfilesOperation.swift'
    change(op, '        let profile = try await self.provisionAndFetchProfile(for: targetAppBundle, parentAppBundle: nil, team: team)', '''        let profile: ALTProvisioningProfile
        do {
            profile = try await self.provisionAndFetchProfile(for: targetAppBundle, parentAppBundle: nil, team: team)
        } catch {
            if !watches.isEmpty { throw WatchSupportError.invalid("FWDIAG_PHONE_PROFILE: iPhone版のApp IDまたはプロファイル取得で失敗しました。") }
            throw error
        }''')
    change(op, '            let watchProfiles = try await WatchSupportSettings.prepare(host: targetAppBundle, hostProfile: profile, certificate: certificate)', '''            let watchProfiles: [String: ALTProvisioningProfile]
            do { watchProfiles = try await WatchSupportSettings.prepare(host: targetAppBundle, hostProfile: profile, certificate: certificate) }
            catch let error as WatchSupportError { throw error }
            catch { throw WatchSupportError.invalid("FWDIAG_WATCH_PREPARE: Watchの署名準備で失敗しました。") }''')
    p=store/'Dependencies/SideSign/Sources/Models/WatchBundleSupport.swift'
    change(p, '        let list: ListAppIDsResponse = try await sendRequest(url: Constants.URLs.listAppIDs,\n            additionalParameters: ["DTDK_Platform": "watchos"], session: session, team: team)', '''        let list: ListAppIDsResponse
        do { list = try await sendRequest(url: Constants.URLs.listAppIDs,
            additionalParameters: ["DTDK_Platform": "watchos"], session: session, team: team) }
        catch { throw WatchSupportError.invalid("FWDIAG_WATCH_APPID_LIST: Watch用App IDの一覧取得で失敗しました。") }''')
    change(p, '            let added: AppIDResponse = try await sendRequest(url: Constants.URLs.addAppID,\n                additionalParameters: ["DTDK_Platform": "watchos", "name": name, "identifier": bundleID], session: session, team: team)', '''            let added: AppIDResponse
            do { added = try await sendRequest(url: Constants.URLs.addAppID,
                additionalParameters: ["DTDK_Platform": "watchos", "name": name, "identifier": bundleID], session: session, team: team) }
            catch { throw WatchSupportError.invalid("FWDIAG_WATCH_APPID_ADD: Watch用App IDの登録で失敗しました。") }''')
    change(p, '        let result: ProfileResponse = try await sendRequest(url: Constants.URLs.downloadProvisioningProfile,\n            additionalParameters: ["DTDK_Platform": "watchos", "appIdId": appID.identifier], session: session, team: team)', '''        let result: ProfileResponse
        do { result = try await sendRequest(url: Constants.URLs.downloadProvisioningProfile,
            additionalParameters: ["DTDK_Platform": "watchos", "appIdId": appID.identifier], session: session, team: team) }
        catch { throw WatchSupportError.invalid("FWDIAG_WATCH_PROFILE: Watch用プロファイルの取得で失敗しました。") }''')
    s=store/'SideStore/Core/WatchSupportSettings.swift'
    change(s, '        try await ALTAppleAPI.shared.registerWatch(name: "Fairway Watch", udid: udid, team: team, session: session)\n        var profiles', '''        do { try await ALTAppleAPI.shared.registerWatch(name: "Fairway Watch", udid: udid, team: team, session: session) }
        catch { throw WatchSupportError.invalid("FWDIAG_WATCH_REGISTER: Watchの登録確認で失敗しました。") }
        var profiles''')

if __name__ == '__main__': apply(Path(sys.argv[1]).resolve())
