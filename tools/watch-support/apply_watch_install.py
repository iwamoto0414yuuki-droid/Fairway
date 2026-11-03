"""Add explicit Watch pairing and direct Watch installation to the pinned probe overlay."""
from pathlib import Path
import shutil
import sys

HERE = Path(__file__).resolve().parent
GATEWAY = 'Dependencies/minimuxer/DeviceGateway/'
SETTINGS = 'SideStore/Core/WatchSupportSettings.swift'
INSTALL = 'SideStore/Core/Operations/PipelineOperations/InstallAppOperation.swift'


def apply(store: Path, native: Path):
    edits = {}

    def replace(path, before, after):
        text = edits[path] if path in edits else path.read_text(encoding='utf-8')
        if text.count(before) != 1:
            raise ValueError(f'Unexpected upstream source: {path}: {before[:60]}')
        edits[path] = text.replace(before, after)

    replace(native / 'ffi/src/lib.rs', 'pub mod watch_connection_probe;',
            'pub mod watch_connection_probe;\npub mod watch_install;')

    api = store / (GATEWAY + 'DeviceGatewayAPI.swift')
    replace(api, '    func fetchUDID() async throws -> String',
            '''    func prepareWatchPairing(expectedUDID: String) async throws
    func requireWatchPairing(expectedUDID: String) async throws
    func installWatchApp(expectedUDID: String, signedAppURL: URL) async throws

    func fetchUDID() async throws -> String''')
    replace(api, 'public extension DeviceGatewayAPI {',
            '''public extension DeviceGatewayAPI {
    func prepareWatchPairing(expectedUDID: String) async throws {
        throw watchInstallUnsupported
    }

    func requireWatchPairing(expectedUDID: String) async throws {
        throw watchInstallUnsupported
    }

    func installWatchApp(expectedUDID: String, signedAppURL: URL) async throws {
        throw watchInstallUnsupported
    }

    private var watchInstallUnsupported: NSError {
        NSError(domain: "FairwayWatchInstall", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Watchへの直接導入にはIDevice / Remote Pairingが必要です。"
        ])
    }
''')

    idevice = store / (GATEWAY + 'idevice/IdeviceGateway.swift')
    replace(idevice, 'import IDevice\n', 'import IDevice\nimport Security\n')
    replace(idevice, '// Personal diagnostic overlay.',
            (HERE / 'idevice/WatchInstall.swift').read_text(encoding='utf-8-sig')
            + '\n// Personal diagnostic overlay.')

    replace(idevice,
            'func probeWatchConnection(expectedUDID: String) async throws -> String {\n        try await withFFIDispatch {',
            'func probeWatchConnection(expectedUDID: String) async throws -> String {\n        try await withFFIDispatch(on: Self.watchQueue) {')

    settings = store / SETTINGS
    replace(settings, '            Section("Watch通信の診断") {',
            '''            Section("Watchへの直接導入") {
                Text("登録を確認したWatchのロックを解除し、ペアリングを準備してください。Watchに確認が表示された場合は承認します。")
                SwiftUI.Button("Watchペアリングを準備") { prepareWatchPairing() }.disabled(busy)
            }
            Section("Watch通信の診断") {''')
    replace(settings,
            '                Text("iPhoneへの導入後、WatchアプリからFairwayをインストールしてください。Watchで起動できるまでは導入成功とは扱いません。")',
            '                Text("ペアリングの準備後は、iPhoneへの導入に続いてWatchへ直接導入します。")')
    replace(settings, '    private func probe() {',
            '''    private func prepareWatchPairing() {
        busy = true
        message = ""
        Task { @MainActor in
            defer { busy = false }
            do {
                let normalized = try WatchBundleSupport.validateUDID(udid)
                guard normalized.caseInsensitiveCompare(WatchSupportSettings.udid) == .orderedSame else {
                    throw WatchSupportError.invalid("先にこのWatchの登録を確認してください。")
                }
                try await ensureMinimuxerReady()
                try await minimuxer.gateway.prepareWatchPairing(expectedUDID: normalized)
                message = "Watchのペアリングを保存しました。FairwayのIPAを導入できます。"
            } catch let error as WatchSupportError {
                message = error.localizedDescription
            } catch let error as NSError where error.domain == "FairwayWatchInstall" {
                message = error.localizedDescription
            } catch {
                message = "Watchペアリングを準備できませんでした。Remote PairingとVPN接続を確認してください。"
            }
        }
    }

    private func probe() {''')

    install = store / INSTALL
    replace(install, '        let (installedApp, isDifferentSideStore, bundleID, isSelfReinstall, isSideBackup)',
            '''        let watchApps = try WatchBundleSupport.applications(in: resignedAppBundle)
        let watchUDID: String?
        if watchApps.isEmpty {
            watchUDID = nil
        } else {
            let target = try WatchBundleSupport.validateUDID(WatchSupportSettings.udid)
            for app in watchApps {
                guard let profile = app.provisioningProfile else {
                    throw WatchSupportError.invalid("署名済みWatchアプリにプロファイルがありません。")
                }
                try WatchBundleSupport.validate(
                    profile, bundleID: app.bundleIdentifier, teamID: authTeam.identifier,
                    udid: target, allowIOSFamily: true
                )
            }
            do {
                try await ensureMinimuxerReady()
                try await minimuxer.gateway.requireWatchPairing(expectedUDID: target)
            } catch let error as NSError where error.domain == "FairwayWatchInstall" {
                throw WatchSupportError.invalid(error.localizedDescription)
            } catch {
                throw WatchSupportError.invalid("Watchペアリングを確認できませんでした。Remote PairingとVPN接続を確認してください。")
            }
            watchUDID = target
        }

        let (installedApp, isDifferentSideStore, bundleID, isSelfReinstall, isSideBackup)''')
    replace(install, '            if isSelfReinstall {',
            '''            if isSelfReinstall && watchUDID != nil {
                throw WatchSupportError.invalid("Watchを含むSideStoreの自己更新には対応していません。")
            }
            if isSelfReinstall {''')
    replace(install, '        self.setProgress(90)',
            '''        if let watchUDID {
            var completed = 0
            do {
                for app in watchApps {
                    try await minimuxer.gateway.installWatchApp(expectedUDID: watchUDID, signedAppURL: app.fileURL)
                    completed += 1
                }
            } catch {
                let failure = error as NSError
                if failure.domain == "FairwayWatchInstall" && failure.code == 6 {
                    completed += 1
                }
                let reason = failure.domain == "FairwayWatchInstall"
                    ? failure.localizedDescription : "Watchへの直接導入中にエラーが発生しました。"
                throw WatchSupportError.invalid(
                    "iPhoneへの導入は完了しました。Watchで完了を確認したアプリは \\(completed)/\\(watchApps.count) 件です。\\(reason)"
                )
            }
        }

        self.setProgress(90)''')

    native_destination = native / 'ffi/src/watch_install.rs'
    if native_destination.exists():
        raise ValueError(f'Native overlay already exists: {native_destination}')
    native_source = HERE / 'idevice/WatchInstall.rs'
    if not native_source.is_file():
        raise FileNotFoundError(native_source)
    for path, text in edits.items():
        path.write_text(text, encoding='utf-8', newline='\n')
    shutil.copyfile(native_source, native_destination)


if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit('usage: apply_watch_install.py SIDESTORE IDEVICE')
    apply(Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve())
