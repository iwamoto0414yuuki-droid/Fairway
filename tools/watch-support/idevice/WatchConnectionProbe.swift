
// Personal diagnostic overlay. Native handles remain inside their originating
// IDevice library; no casts between stream/provider handle types are used.
extension IdeviceGateway {
    public func probeWatchConnection(expectedUDID: String) async throws -> String {
        try await withFFIDispatch {
            try self.verifyInitialized()
            guard self.pairingFileType == .rppairing else {
                return "WCP_PROTOCOL: Remote Pairingを選んでください。"
            }
            guard let bytes = self.pairingFileData,
                  let content = String(data: bytes, encoding: .utf8),
                  let endpoint = self.deviceEndpointIp else {
                return "WCP_SETUP_FAILED: Remote Pairingを読み直してください。"
            }
            // Heartbeat/install use the shared gateway concurrently. The probe
            // owns a separate tunnel and never borrows or invalidates its handles.
            let isolated = IdeviceGateway()
            try isolated.syncStart(pairingFileContent: content, preferred: .rppairing)
            isolated.setDeviceEndpointIp(endpoint)
            isolated.setPort(self.getPort(for: .rppairing), for: .rppairing)
            defer {
                isolated.invalidateConnection()
                isolated.cleanup()
            }
            try isolated.ensureRPConnection()
            var report: UnsafeMutablePointer<CChar>?
            let error = expectedUDID.withCString { expected in
                fairway_watch_connection_probe(isolated.adapter, isolated.handshake, expected, &report)
            }
            defer {
                if let report { idevice_string_free(report) }
                if let error { idevice_error_free(error) }
            }
            guard let report else { return "WCP_NO_REPORT: 診断結果を取得できませんでした。" }
            return String(cString: report)
        }
    }
}
