
// Personal experimental Watch installation overlay.
extension IdeviceGateway {
    private static let watchQueue = DispatchQueue(label: "Fairway.WatchInstallation", qos: .utility)
    private static let watchKeychainService = "Fairway.SideStore.WatchPairing.v1"

    public func prepareWatchPairing(expectedUDID: String) async throws {
        try await withFFIDispatch(on: Self.watchQueue) {
            try self.withWatchTunnel { tunnel, phoneUDID in
                let query = Self.watchPairingQuery(phoneUDID: phoneUDID, watchUDID: expectedUDID)
                if let saved = try Self.readWatchKeychainItem(query) {
                    try Self.withWatchPairingData(saved) { _ in }
                    return
                }
                let (hostID, systemBUID) = try Self.watchPairingIdentity(for: query)
                var pairing: OpaquePointer?
                let error = expectedUDID.withCString { watch in
                    hostID.withCString { host in
                        systemBUID.withCString { system in
                            fairway_watch_prepare_pairing(tunnel.adapter, tunnel.handshake, watch, host, system, &pairing)
                        }
                    }
                }
                defer { if let pairing { idevice_pairing_file_free(pairing) } }
                try Self.checkWatchNative(error, code: 3, message: "Watchとのペアリングに失敗しました。Watchを解除して接続を確認してください。")
                guard let pairing else { throw Self.watchPairingStorageError }

                var bytes: UnsafeMutablePointer<UInt8>?
                var size: UInt = 0
                let serializationError = idevice_pairing_file_serialize(pairing, &bytes, &size)
                defer { if let bytes { idevice_data_free(bytes, size) } }
                if let serializationError {
                    idevice_error_free(serializationError)
                    throw Self.watchPairingStorageError
                }
                guard let bytes, size > 0, let count = Int(exactly: size) else {
                    throw Self.watchPairingStorageError
                }
                try Self.addWatchKeychainItem(Data(bytes: bytes, count: count), query: query)
            }
        }
    }

    public func requireWatchPairing(expectedUDID: String) async throws {
        try await withFFIDispatch(on: Self.watchQueue) {
            try self.withWatchTunnel { _, phoneUDID in
                try Self.withSavedWatchPairing(phoneUDID: phoneUDID, watchUDID: expectedUDID) { _ in }
            }
        }
    }

    public func installWatchApp(expectedUDID: String, signedAppURL: URL) async throws {
        try await withFFIDispatch(on: Self.watchQueue) {
            try self.withWatchTunnel { tunnel, phoneUDID in
                try Self.withSavedWatchPairing(phoneUDID: phoneUDID, watchUDID: expectedUDID) { pairing in
                    let error = expectedUDID.withCString { watch in
                        signedAppURL.path.withCString { path in
                            fairway_watch_install(tunnel.adapter, tunnel.handshake, watch, pairing, path)
                        }
                    }
                    try Self.checkWatchNative(error, code: 5, message: "Watchへの導入に失敗しました。Watchの接続とペアリング設定を確認してください。")
                }
            }
        }
    }

    private func withWatchTunnel<T>(_ body: (IdeviceGateway, String) throws -> T) throws -> T {
        let tunnel = IdeviceGateway()
        defer {
            tunnel.invalidateConnection()
            tunnel.cleanup()
        }

        let phoneUDID: String
        do {
            try verifyInitialized()
            guard pairingFileType == .rppairing, let bytes = pairingFileData,
                  let content = String(data: bytes, encoding: .utf8), let endpoint = deviceEndpointIp else {
                throw Self.watchConnectionError
            }
            try tunnel.syncStart(pairingFileContent: content, preferred: .rppairing)
            tunnel.setDeviceEndpointIp(endpoint)
            tunnel.setPort(getPort(for: .rppairing), for: .rppairing)
            try tunnel.ensureRPConnection()
            phoneUDID = try tunnel.readWatchPairingPhoneUDID()
        } catch {
            // Pairing values and opaque native error strings stay out of UI errors.
            throw Self.watchConnectionError
        }
        return try body(tunnel, phoneUDID)
    }

    private func readWatchPairingPhoneUDID() throws -> String {
        var client: OpaquePointer?
        let connectError = lockdownd_connect_rsd(adapter, handshake, &client)
        defer { if let client { lockdownd_client_free(client) } }
        if let connectError {
            idevice_error_free(connectError)
            throw Self.watchConnectionError
        }
        guard let client else { throw Self.watchConnectionError }
        var value: plist_t?
        let readError = lockdownd_get_value(client, "UniqueDeviceID", nil, &value)
        defer { if let value { safeFreePlist(value) } }
        if let readError {
            idevice_error_free(readError)
            throw Self.watchConnectionError
        }
        guard let value, let id = getRustPlistString(value), !id.isEmpty else {
            throw Self.watchConnectionError
        }
        return id.lowercased()
    }

    private static func withSavedWatchPairing<T>(
        phoneUDID: String,
        watchUDID: String,
        _ body: (OpaquePointer) throws -> T
    ) throws -> T {
        let query = watchPairingQuery(phoneUDID: phoneUDID, watchUDID: watchUDID)
        guard let data = try readWatchKeychainItem(query) else {
            throw watchError(code: 4, message: "このWatchのペアリングをSideStoreのWatch設定で準備してください。")
        }
        return try withWatchPairingData(data, body)
    }

    private static func withWatchPairingData<T>(_ data: Data, _ body: (OpaquePointer) throws -> T) throws -> T {
        var pairing: OpaquePointer?
        let error = data.withUnsafeBytes { buffer in
            idevice_pairing_file_from_bytes(buffer.bindMemory(to: UInt8.self).baseAddress, UInt(data.count), &pairing)
        }
        defer { if let pairing { idevice_pairing_file_free(pairing) } }
        if let error {
            idevice_error_free(error)
            throw watchPairingStorageError
        }
        guard let pairing else { throw watchPairingStorageError }
        return try body(pairing)
    }

    private static func watchPairingIdentity(for pairingQuery: [String: Any]) throws -> (String, String) {
        var query = pairingQuery
        query[kSecAttrService as String] = watchKeychainService + ".identity"
        if let saved = try readWatchKeychainItem(query) {
            guard let value = String(data: saved, encoding: .utf8) else { throw watchPairingStorageError }
            let identifiers = value.split(separator: ",")
            guard identifiers.count == 2,
                  let host = UUID(uuidString: String(identifiers[0])),
                  let system = UUID(uuidString: String(identifiers[1])) else { throw watchPairingStorageError }
            return (host.uuidString, system.uuidString)
        }
        let host = UUID().uuidString
        let system = UUID().uuidString
        try addWatchKeychainItem(Data((host + "," + system).utf8), query: query)
        return (host, system)
    }

    private static func readWatchKeychainItem(_ key: [String: Any]) throws -> Data? {
        var query = key
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else { throw watchPairingStorageError }
        return data
    }

    private static func addWatchKeychainItem(_ data: Data, query: [String: Any]) throws {
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw watchPairingStorageError }
    }

    private static func watchPairingQuery(phoneUDID: String, watchUDID: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: watchKeychainService,
            kSecAttrAccount as String: phoneUDID + ":" + watchUDID.lowercased()
        ]
    }

    private static func checkWatchNative(_ error: UnsafeMutablePointer<IdeviceFfiError>?, code: Int, message: String) throws {
        guard let error else { return }
        defer { idevice_error_free(error) }
        let knownCodes = [
            "WI_INSTALLED_CLEANUP", "WI_SETUP_TIMEOUT", "WI_PAIR_TIMEOUT", "WI_ZIP_SETUP_TIMEOUT",
            "WI_INSTALL_TIMEOUT", "WI_ZIP_SERVICE", "WI_ZIP_TLS", "WI_REGISTRY", "WI_IDENTITY",
            "WI_SESSION", "WI_CONNECT", "WI_FORWARD", "WI_SERVICE", "WI_INPUT", "WI_APP",
            "WI_PAIR", "WI_INSTALL"
        ]
        let diagnostic = error.pointee.message.map { String(cString: $0) } ?? ""
        let tokens = diagnostic.split { !$0.isLetter && !$0.isNumber && $0 != "_" }
        let stage = knownCodes.first { tokens.contains(Substring($0)) }
        if stage == "WI_INSTALLED_CLEANUP" {
            throw watchError(code: 6, message: "WI_INSTALLED_CLEANUP: Watchへの導入は完了しましたが、接続の終了に失敗しました。")
        }
        throw watchError(code: code, message: stage.map { $0 + ": " + message } ?? message)
    }

    private static var watchConnectionError: NSError {
        watchError(code: 1, message: "IDevice / Remote PairingとiPhoneへのVPN接続を確認してください。")
    }

    private static var watchPairingStorageError: NSError {
        watchError(code: 2, message: "Watchのペアリング情報をキーチェーンで利用できません。")
    }

    private static func watchError(code: Int, message: String) -> NSError {
        NSError(domain: "FairwayWatchInstall", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
