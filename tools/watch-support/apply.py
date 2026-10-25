"""Apply narrow, fail-closed Watch support changes to pinned personal source trees."""
from pathlib import Path
import shutil
import sys

OVERLAYS = Path(__file__).resolve().parent


def replace(root, path, before, after):
    target = root / path
    text = target.read_text(encoding='utf-8')
    assert text.count(before) == 1, f'Unexpected upstream source: {path}: {before[:60]}'
    target.write_text(text.replace(before, after), encoding='utf-8', newline='\n')


def apply(store, sign):
    shutil.copyfile(OVERLAYS/'SideSign/WatchBundleSupport.swift', sign/'Sources/Models/WatchBundleSupport.swift')
    shutil.copyfile(OVERLAYS/'SideSign/WatchSupportTests.swift', sign/'Tests/SideSignTests/WatchSupportTests.swift')
    shutil.copyfile(OVERLAYS/'SideStore/WatchSupportSettings.swift', store/'SideStore/Core/WatchSupportSettings.swift')
    # The pinned upstream tests use Foundation types without importing Foundation.
    replace(sign, 'Tests/SideSignTests/SideSignTests.swift', 'import Testing', 'import Foundation\nimport Testing')
    replace(sign, 'Sources/Models/ProvisioningProfile.swift',
            'private static func dictionary(fromEncodedData', 'static func dictionary(fromEncodedData')
    path = 'Sources/CodeSigning/CodeSignerAPI.swift'
    replace(sign, path, '        var entitlementsByURL: [URL: String] = [:]',
            '        _ = try WatchBundleSupport.applications(in: appBundle)\n'
            '        var entitlementsByURL: [URL: String] = [:]')
    replace(sign, path, 'return profiles.first',
            'return appBundle.watchSigningBundles.contains(where: { $0.fileURL == app.fileURL }) ? nil : profiles.first')
    replace(sign, path, 'for ext in appBundle.appExtensions {',
            'for ext in Array(appBundle.appExtensions) + appBundle.watchSigningBundles {')
    replace(sign, path, 'appBundle.appExtensions.first(where: { ext in',
            '(Array(appBundle.appExtensions) + appBundle.watchSigningBundles).sorted { $0.fileURL.path.count > $1.fileURL.path.count }.first(where: { ext in')
    # Frameworks and dylibs inside Watch apps must not receive Watch executable entitlements.
    replace(sign, path, '} else if let matchedExt = ',
            '} else if resolved.path.contains(".framework") || resolved.pathExtension == "dylib" {\n'
            '                            targetType = .framework; xml = ""\n'
            '                        } else if let matchedExt = ')
    replace(sign, path, '            debugLog("[SideSign] AppBundleSigner.signApp completed successfully")',
            '            for watch in appBundle.watchSigningBundles {\n'
            '                guard let matching = profile(for: watch) else { throw SignerError.missingProvisioningProfile(bundleIdentifier: watch.bundleIdentifier) }\n'
            '                let xml = try MachOParser.entitlements(at: watch.fileURL)\n'
            '                guard let data = xml.data(using: .utf8), let values = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],\n'
            '                      values["application-identifier"] as? String == matching.entitlements["application-identifier"] as? String,\n'
            '                      FileManager.default.fileExists(atPath: watch.fileURL.appendingPathComponent("_CodeSignature/CodeResources").path) else {\n'
            '                    throw SignerError.invalidApp(cause: "Watchの実行ファイル署名と専用profileが一致しません。インストールを停止しました。")\n'
            '                }\n'
            '            }\n'
            '            debugLog("[SideSign] AppBundleSigner.signApp completed successfully")')
    path = 'SideStore/Core/Operations/PipelineOperations/FetchProvisioningProfilesOperation.swift'
    replace(store, path, '        let appExtensions = targetAppBundle.appExtensions',
            '        let watches = try WatchBundleSupport.applications(in: targetAppBundle)\n'
            '        if !watches.isEmpty {\n'
            '            guard context.overrideProvisioningProfile == nil else {\n'
            '                throw WatchSupportError.invalid("Watchを含むアプリには専用profileの自動取得が必要です。手動profileの指定を解除してください。")\n'
            '            }\n'
            '            context.useMainProfile = false\n'
            '        }\n'
            '        let appExtensions = targetAppBundle.appExtensions')
    replace(store, path, '        var profiles = [effectiveBundleId: profile]',
            '        var profiles = [effectiveBundleId: profile]\n'
            '        if !watches.isEmpty {\n'
            '            guard let certificate = context.targetSigningCertificate else { throw WatchSupportError.invalid("署名証明書がありません。") }\n'
            '            let watchProfiles = try await WatchSupportSettings.prepare(host: targetAppBundle, hostProfile: profile, certificate: certificate)\n'
            '            profiles.merge(watchProfiles) { _, new in new }\n'
            '        }')
    path = 'SideStore/Core/Operations/PipelineOperations/ResignAppOperation.swift'
    replace(store, path, '        return appBundleURL\n    }',
            '        let watches = try WatchBundleSupport.applications(in: targetAppBundle)\n'
            '        if !watches.isEmpty {\n'
            '            guard let hostProfile = profiles[bundleIdentifier] else { throw WatchSupportError.invalid("iPhone用profileがありません。") }\n'
            '            for original in targetAppBundle.watchSigningBundles {\n'
            '                let relative = String(original.fileURL.path.dropFirst(targetAppBundle.fileURL.path.count + 1))\n'
            '                guard let child = ALTApplication(fileURL: appBundleURL.appendingPathComponent(relative)) else { throw WatchSupportError.invalid("Watchアプリを読み込めません。") }\n'
            '                let newID = try WatchBundleSupport.identifier(original.bundleIdentifier, from: targetAppBundle.bundleIdentifier, to: hostProfile.bundleIdentifier)\n'
            '                let values = try WatchBundleSupport.relationships(in: original.infoPlist, from: targetAppBundle.bundleIdentifier, to: hostProfile.bundleIdentifier)\n'
            '                try self.prepare(child, bundleID: newID, additionalInfoDictionaryValues: values, profiles: profiles, appexBundleIds: [:])\n'
            '            }\n'
            '        }\n'
            '        return appBundleURL\n    }')
    path = 'SideStore/Views/Settings/Advanced/DeveloperServices/DeveloperServicesView.swift'
    replace(store, path, '                Section(header: Text("Developer Portal Services")) {',
            '                Section("個人用Watch試験版") {\n'
            '                    NavigationLink("Watch対応", destination: WatchSupportSettingsView())\n'
            '                }\n'
            '                Section(header: Text("Developer Portal Services")) {')
    # Phone-only refresh injects profiles into the iPhone, not its paired Watch.
    # Re-sign/reinstall the embedded companion instead, retaining normal app data.
    path = 'SideStore/Core/Operations/PipelineRunner.swift'
    replace(store, path,
            '    private func performPipeline(for operation: AppOperation, handler: PipelineExecutionHandler, group: RefreshGroup, operationsCount: Int = 1) async throws -> InstalledApp\n    {\n        let pipelineSteps',
            '    private func performPipeline(for requestedOperation: AppOperation, handler: PipelineExecutionHandler, group: RefreshGroup, operationsCount: Int = 1) async throws -> InstalledApp\n    {\n'
            '        let operation: AppOperation\n'
            '        if case .refresh(let app) = requestedOperation, let host = ALTApplication(fileURL: app.fileURL), !((try WatchBundleSupport.applications(in: host)).isEmpty) {\n'
            '            operation = .resign(app)\n'
            '        } else { operation = requestedOperation }\n'
            '        let pipelineSteps')
    replace(store, path, '        let operationProgress = progress.progress(for: operation)',
            '        let operationProgress = progress.progress(for: requestedOperation)')


if __name__ == '__main__':
    apply(Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve())
