"""Add a non-destructive, opt-in Watch RSD probe to pinned personal sources.

No app installation, pairing, account changes or certificate changes are made by
the probe. The matching native IDevice must be built before archiving SideStore.
"""
from pathlib import Path
import shutil
import sys

from apply import replace

HERE = Path(__file__).resolve().parent


def apply(store: Path, native: Path):
    gateway = store / 'Dependencies/minimuxer/DeviceGateway'
    native_source = native / 'ffi/src/watch_connection_probe.rs'
    shutil.copyfile(HERE / 'idevice/WatchConnectionProbe.rs', native_source)
    replace(native, 'ffi/src/lib.rs',
            'pub mod lockdown;', 'pub mod lockdown;\npub mod watch_connection_probe;')
    # The package is iOS-only for this diagnostic archive. No upstream binary or
    # opaque pointer is reinterpreted as a different native handle type.
    replace(gateway, 'Package.swift',
            'url: "https://github.com/SideStore/idevice/releases/download/v0.1.68-ss-3e55c84/idevice-xcframework-v0.1.68-ss-3e55c84.zip#DeviceGateway",\n'
            '             checksum: "445702d53942597deb4cdec2c4122d16a3f4ac124ce26cd75b68dab3dad92416"',
            'path: "../../../NativeIDevice.xcframework"')
    path = 'DeviceGatewayAPI.swift'
    replace(gateway, path, '    func fetchUDID() async throws -> String',
            '    func probeWatchConnection(expectedUDID: String) async throws -> String\n\n'
            '    func fetchUDID() async throws -> String')
    replace(gateway, path, 'public extension DeviceGatewayAPI {',
            'public extension DeviceGatewayAPI {\n'
            '    func probeWatchConnection(expectedUDID: String) async throws -> String {\n'
            '        throw NSError(domain: "WatchConnectionProbe", code: 1, userInfo: [NSLocalizedDescriptionKey: "WCP_BACKEND: IDevice / Remote Pairingを選んでください。"] )\n'
            '    }\n')
    with (gateway / 'idevice/IdeviceGateway.swift').open('a', encoding='utf-8', newline='\n') as out:
        out.write((HERE / 'idevice/WatchConnectionProbe.swift').read_text(encoding='utf-8'))
    settings = store / 'SideStore/Core/WatchSupportSettings.swift'
    text = settings.read_text(encoding='utf-8')
    text = text.replace('    @State private var busy = false',
                        '    @State private var busy = false\n    @State private var probeResult = ""')
    text = text.replace('            Section("使い方") {', '''            Section("Watch通信の診断") {
                Text("Watchへの通信を確認します。アプリの導入・削除やペアリングの変更は行いません。")
                SwiftUI.Button("Watch通信を診断") { probe() }.disabled(busy)
                if !probeResult.isEmpty {
                    Text(probeResult).font(.system(.footnote, design: .monospaced)).textSelection(.enabled)
                }
            }
            Section("使い方") {''')
    text = text.replace('    private func register() {', '''    private func probe() {
        busy = true; probeResult = "通信を確認中…"
        Task { @MainActor in
            defer { busy = false }
            do {
                let normalized = try WatchBundleSupport.validateUDID(udid)
                try await ensureMinimuxerReady()
                probeResult = try await minimuxer.gateway.probeWatchConnection(expectedUDID: normalized)
            } catch {
                // Do not surface arbitrary FFI messages containing pairing data.
                probeResult = "WCP_SETUP_FAILED: Remote PairingとVPN接続、WatchのUDID設定を確認してください。"
            }
        }
    }
    private func register() {''')
    assert text.count('private func probe()') == 1
    settings.write_text(text, encoding='utf-8', newline='\n')
    # Inspect production-prepared plists, rather than relying solely on tests that
    # construct rewritten fixtures directly. This still is not Apple trust proof.
    replace(store / 'Dependencies/SideSign', 'Sources/CodeSigning/CodeSignerAPI.swift',
            '        _ = try WatchBundleSupport.applications(in: appBundle)\n',
            '        _ = try WatchBundleSupport.applications(in: appBundle)\n'
            '        for watch in appBundle.watchApplications {\n'
            '            guard watch.infoPlist["WKCompanionAppBundleIdentifier"] as? String == appBundle.bundleIdentifier else {\n'
            '                throw SignerError.invalidApp(cause: "WCP_SIGNED_RELATIONSHIP: Watchの親アプリIDが一致しません。")\n'
            '            }\n'
            '        }\n')


if __name__ == '__main__':
    apply(Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve())
