//! Direct Watch install over the iPhone companion proxy, on the RSD adapter's owning thread.
use std::{
    ffi::{CStr, c_char},
    path::{Path, PathBuf},
    ptr::null_mut,
    time::Duration,
};

use idevice::{
    Idevice, IdeviceError, RsdService, companion_proxy::CompanionProxy,
    lockdown::LockdownClient, pairing_file::PairingFile,
};
use plist::{Dictionary, Value};

use crate::{
    IdeviceFfiError, core_device_proxy::AdapterHandle, ffi_err,
    pairing_file::IdevicePairingFile, rsd::RsdHandshakeHandle, run_sync_local,
};

const LOCKDOWN_PORT: u16 = 62078;
const LOCKDOWN_SERVICE: &str = "com.apple.mobile.lockdownd";
const ZIP_SERVICE: &str = "com.apple.streaming_zip_conduit";
const PROXY_SERVICE: &str = "com.apple.companion_proxy.shim.remote";
const CONTROL_TIMEOUT: Duration = Duration::from_secs(45);
const INSTALL_TIMEOUT: Duration = Duration::from_secs(180);

type Failure = &'static str;

enum Operation<'a> {
    Prepare { host_id: String, system_buid: String },
    Install { pairing: &'a PairingFile, app: &'a Path },
}

fn normalized_udid(text: &str) -> Option<String> {
    let bytes = text.as_bytes();
    let valid = (bytes.len() == 40 && bytes.iter().all(u8::is_ascii_hexdigit))
        || (bytes.len() == 25 && bytes[8] == b'-'
            && bytes[..8].iter().chain(&bytes[9..]).all(u8::is_ascii_hexdigit));
    valid.then(|| text.to_ascii_lowercase())
}

fn is_uuid(text: &str) -> bool {
    text.len() == 36 && text.bytes().enumerate().all(|(index, byte)| {
        if matches!(index, 8 | 13 | 18 | 23) { byte == b'-' } else { byte.is_ascii_hexdigit() }
    })
}

async fn connect_forwarded(adapter: &mut AdapterHandle, port: u16) -> Result<Idevice, Failure> {
    if port == 0 {
        return Err("WI_FORWARD");
    }
    for attempt in 0..3 {
        if let Ok(Ok(stream)) = tokio::time::timeout(Duration::from_secs(5), adapter.0.connect(port)).await {
            return Ok(Idevice::new(Box::new(stream), "FairwayWatchInstall"));
        }
        if attempt < 2 {
            tokio::time::sleep(Duration::from_millis(400)).await;
        }
    }
    Err("WI_CONNECT")
}

async fn run_operation(
    adapter: &mut AdapterHandle,
    handshake: &mut RsdHandshakeHandle,
    expected: &str,
    operation: Operation<'_>,
) -> Result<Option<PairingFile>, Failure> {
    let mut lockdown_attempted = false;
    let mut zip_forward_attempted = None;
    let setup = tokio::time::timeout(CONTROL_TIMEOUT, async {
        if !handshake.0.services.contains_key(PROXY_SERVICE) {
            return Err("WI_SERVICE");
        }
        let mut proxy = CompanionProxy::connect_rsd(&mut adapter.0, &mut handshake.0)
            .await.map_err(|_| "WI_SERVICE")?;
        let registry = proxy.get_device_registry().await.map_err(|_| "WI_REGISTRY")?;
        if registry.len() != 1 || normalized_udid(&registry[0]).as_deref() != Some(expected) {
            return Err("WI_REGISTRY");
        }
        drop(proxy);

        let mut proxy = CompanionProxy::connect_rsd(&mut adapter.0, &mut handshake.0)
            .await.map_err(|_| "WI_SERVICE")?;
        lockdown_attempted = true;
        let port = proxy.start_forwarding_service_port(LOCKDOWN_PORT, Some(LOCKDOWN_SERVICE), None)
            .await.map_err(|_| "WI_FORWARD")?;
        drop(proxy);
        let mut lockdown = LockdownClient::new(connect_forwarded(adapter, port).await?);
        let identity = lockdown.get_value(Some("UniqueDeviceID"), None).await.map_err(|_| "WI_IDENTITY")?;
        if identity.as_string().and_then(normalized_udid).as_deref() != Some(expected) {
            return Err("WI_IDENTITY");
        }

        Ok(lockdown)
    }).await.unwrap_or(Err("WI_SETUP_TIMEOUT"));

    let result = match (setup, operation) {
        (Err(code), _) => Err(code),
        (Ok(mut lockdown), Operation::Prepare { host_id, system_buid }) => {
            tokio::time::timeout(CONTROL_TIMEOUT, async {
                let pairing = lockdown.pair(host_id, system_buid, Some("FairwayWatchInstall"))
                    .await.map_err(|_| "WI_PAIR")?;
                Ok(Some(pairing))
            }).await.unwrap_or(Err("WI_PAIR_TIMEOUT"))
        }
        (Ok(mut lockdown), Operation::Install { pairing, app }) => {
            let connection = tokio::time::timeout(CONTROL_TIMEOUT, async {
                let legacy = lockdown.start_session(pairing).await.map_err(|_| "WI_SESSION")?;
                let (remote_port, ssl) = lockdown.start_service(ZIP_SERVICE)
                    .await.map_err(|_| "WI_ZIP_SERVICE")?;
                if remote_port == 0 || remote_port == LOCKDOWN_PORT {
                    return Err("WI_ZIP_SERVICE");
                }
                let mut proxy = CompanionProxy::connect_rsd(&mut adapter.0, &mut handshake.0)
                    .await.map_err(|_| "WI_SERVICE")?;
                zip_forward_attempted = Some(remote_port);
                let port = proxy.start_forwarding_service_port(remote_port, Some(ZIP_SERVICE), None)
                    .await.map_err(|_| "WI_FORWARD")?;
                drop(proxy);
                let mut connection = connect_forwarded(adapter, port).await?;
                if ssl {
                    connection.start_session(pairing, legacy).await.map_err(|_| "WI_ZIP_TLS")?;
                }
                Ok(connection)
            }).await.unwrap_or(Err("WI_ZIP_SETUP_TIMEOUT"));

            match connection {
                Ok(mut connection) => tokio::time::timeout(INSTALL_TIMEOUT, stream_watch_app(&mut connection, app))
                    .await.map_err(|_| "WI_INSTALL_TIMEOUT")
                    .and_then(|status| status.map(|_| None).map_err(|_| "WI_INSTALL")),
                Err(code) => Err(code),
            }
        }
    };

    // Try both forwards even if the first cleanup fails. A request can take effect
    // before its reply arrives, so track the remote port before sending the request.
    let mut cleanup_ok = true;
    let lockdown_port = lockdown_attempted.then_some(LOCKDOWN_PORT);
    for port in [zip_forward_attempted, lockdown_port].into_iter().flatten() {
        let mut stopped = false;
        for _ in 0..2 {
            let cleanup = tokio::time::timeout(Duration::from_secs(5), async {
                let mut proxy = CompanionProxy::connect_rsd(&mut adapter.0, &mut handshake.0).await?;
                proxy.stop_forwarding_service_port(port).await
            }).await;
            if matches!(cleanup, Ok(Ok(()))) {
                stopped = true;
                break;
            }
        }
        cleanup_ok &= stopped;
    }
    // Returning the successful pairing record allows the caller to preserve the
    // credential even if cleanup fails after the device accepted the pairing.
    match result {
        Ok(None) if !cleanup_ok => Err("WI_INSTALLED_CLEANUP"),
        result => result,
    }
}

fn ffi_result(result: Result<(), Failure>) -> *mut IdeviceFfiError {
    match result {
        Ok(()) => null_mut(),
        Err(code) => ffi_err!(IdeviceError::InternalError(code.into())),
    }
}

/// Prepare a Watch pairing record after verifying the device identity. Borrow both handles exclusively on
/// their owning thread. All input pointers must be live for the whole call.
/// Release the returned record with idevice_pairing_file_free.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn fairway_watch_prepare_pairing(
    adapter: *mut AdapterHandle,
    handshake: *mut RsdHandshakeHandle,
    watch_udid: *const c_char,
    host_id: *const c_char,
    system_buid: *const c_char,
    watch_pairing: *mut *mut IdevicePairingFile,
) -> *mut IdeviceFfiError {
    if watch_pairing.is_null() {
        return ffi_result(Err("WI_INPUT"));
    }
    unsafe { *watch_pairing = null_mut(); }
    if adapter.is_null() || handshake.is_null() || watch_udid.is_null() || host_id.is_null() || system_buid.is_null() {
        return ffi_result(Err("WI_INPUT"));
    }
    let Some(expected) = unsafe { CStr::from_ptr(watch_udid) }.to_str().ok().and_then(normalized_udid) else {
        return ffi_result(Err("WI_INPUT"));
    };
    let Ok(host_id) = unsafe { CStr::from_ptr(host_id) }.to_str() else {
        return ffi_result(Err("WI_INPUT"));
    };
    let Ok(system_buid) = unsafe { CStr::from_ptr(system_buid) }.to_str() else {
        return ffi_result(Err("WI_INPUT"));
    };
    if !is_uuid(host_id) || !is_uuid(system_buid) {
        return ffi_result(Err("WI_INPUT"));
    }

    let operation = Operation::Prepare { host_id: host_id.into(), system_buid: system_buid.into() };
    let _quiet = tracing::subscriber::set_default(tracing::subscriber::NoSubscriber::default());
    let result = run_sync_local(run_operation(unsafe { &mut *adapter }, unsafe { &mut *handshake }, &expected, operation));
    match result {
        Ok(Some(pairing)) => {
            unsafe { *watch_pairing = Box::into_raw(Box::new(IdevicePairingFile(pairing))); }
            null_mut()
        }
        Ok(None) => ffi_result(Err("WI_PAIR")),
        Err(code) => ffi_result(Err(code)),
    }
}

/// Install a locally staged signed Watch .app using a previously prepared pairing.
/// Borrow both handles exclusively on their owning thread. All input pointers and
/// the staged bundle must remain valid and stable for the whole call.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn fairway_watch_install(
    adapter: *mut AdapterHandle,
    handshake: *mut RsdHandshakeHandle,
    watch_udid: *const c_char,
    watch_pairing: *const IdevicePairingFile,
    signed_app_path: *const c_char,
) -> *mut IdeviceFfiError {
    if adapter.is_null() || handshake.is_null() || watch_udid.is_null() || watch_pairing.is_null() || signed_app_path.is_null() {
        return ffi_result(Err("WI_INPUT"));
    }
    let Some(expected) = unsafe { CStr::from_ptr(watch_udid) }.to_str().ok().and_then(normalized_udid) else {
        return ffi_result(Err("WI_INPUT"));
    };
    let Ok(path) = unsafe { CStr::from_ptr(signed_app_path) }.to_str() else {
        return ffi_result(Err("WI_INPUT"));
    };
    let app = Path::new(path);
    if app.extension().and_then(|value| value.to_str()) != Some("app")
        || !std::fs::symlink_metadata(app).is_ok_and(|metadata| metadata.is_dir())
        || !app.join("Info.plist").is_file()
    {
        return ffi_result(Err("WI_APP"));
    }

    let operation = Operation::Install { pairing: unsafe { &(*watch_pairing).0 }, app };
    let _quiet = tracing::subscriber::set_default(tracing::subscriber::NoSubscriber::default());
    ffi_result(run_sync_local(run_operation(unsafe { &mut *adapter }, unsafe { &mut *handshake }, &expected, operation)).map(|_| ()))
}

// Sparse ZIP framing follows the working Windows Loader Watch conduit implementation.
const CENTRAL_DIRECTORY_HEADER: &[u8] = &[0x50, 0x4b, 0x01, 0x02];
const ZIP_EXTRA: &[u8] = &[
    0x55, 0x54, 0x0d, 0x00, 0x07, 0xf3, 0xa2, 0xec, 0x60, 0xf6, 0xa2, 0xec, 0x60, 0xf3,
    0xa2, 0xec, 0x60, 0x75, 0x78, 0x0b, 0x00, 0x01, 0x04, 0xf5, 0x01, 0x00, 0x00, 0x04,
    0x14, 0x00, 0x00, 0x00,
];

async fn stream_watch_app(
    connection: &mut Idevice,
    app: &Path,
) -> Result<(), ()> {
    let app_name = app
        .file_name()
        .ok_or(())?
        .to_str().ok_or(())?;

    let mut files = Vec::new();
    collect_files(app, &mut files)?;
    files.sort();

    let mut entries = Vec::with_capacity(files.len());
    let mut total_uncompressed = 0u64;

    for source in files {
        let relative = source
            .strip_prefix(app).map_err(|_| ())?;
        let relative = relative.to_str().ok_or(())?;
        let destination = format!("Payload/{app_name}/{relative}");
        let size = std::fs::metadata(&source).map_err(|_| ())?.len();
        u32::try_from(size).map_err(|_| ())?;
        u16::try_from(destination.len()).map_err(|_| ())?;
        total_uncompressed = total_uncompressed.checked_add(size).ok_or(())?;
        entries.push((source, destination));
    }

    let media_subdir = format!("PublicStaging/{app_name}.ipa");
    let mut install_options = Dictionary::new();
    insert_integer(&mut install_options, "DisableDeltaTransfer", 1);
    insert_string(
        &mut install_options,
        "InstallDeltaTypeKey",
        "InstallDeltaTypeSparseIPAFiles",
    );
    insert_integer(&mut install_options, "IsUserInitiated", 1);
    insert_string(&mut install_options, "PackageType", "Customer");
    insert_integer(&mut install_options, "PreferWifi", 1);

    let mut init_transfer = Dictionary::new();
    init_transfer.insert(
        "InstallOptionsDictionary".to_string(),
        Value::Dictionary(install_options),
    );
    insert_integer(&mut init_transfer, "InstallTransferredDirectory", 1);
    insert_string(&mut init_transfer, "MediaSubdir", media_subdir);
    insert_integer(&mut init_transfer, "UserInitiatedTransfer", 0);


    let mut metadata = Dictionary::new();
    insert_integer(&mut metadata, "StandardDirectoryPerms", 16877);
    insert_integer(&mut metadata, "StandardFilePerms", -32348);
    insert_integer(
        &mut metadata,
        "RecordCount",
        i64::try_from(entries.len() + 2).map_err(|_| ())?,
    );
    insert_integer(
        &mut metadata,
        "TotalUncompressedBytes",
        i64::try_from(total_uncompressed).map_err(|_| ())?,
    );
    insert_integer(&mut metadata, "Version", 2);

    let mut metadata_bytes = Vec::new();
    Value::Dictionary(metadata).to_writer_xml(&mut metadata_bytes).map_err(|_| ())?;

    send_prefixed_plist(connection, init_transfer).await?;
    send_zip_directory(connection, "META-INF/").await?;
    send_zip_file(
        connection,
        "META-INF/com.apple.ZipMetadata.plist",
        &metadata_bytes,
    )
    .await?;

    for (source, destination) in entries {
        let data = tokio::fs::read(&source).await.map_err(|_| ())?;
        send_zip_file(connection, &destination, &data).await?;
    }

    connection
        .send_raw(CENTRAL_DIRECTORY_HEADER)
        .await
        .map_err(|_| ())?;

    wait_for_watch_install(connection).await
}

async fn wait_for_watch_install(
    connection: &mut Idevice,
) -> Result<(), ()> {
    loop {
        let response = read_prefixed_plist(connection).await?;

        if install_complete(&response)? {
            return Ok(());
        }
    }
}

fn install_complete(response: &Dictionary) -> Result<bool, ()> {
    let complete = response.get("Status").and_then(Value::as_string) == Some("DataComplete");
    if response.contains_key("Error") {
        return Err(());
    }
    match response.get("InstallProgressDict") {
        Some(Value::Dictionary(progress)) if !progress.contains_key("Error") => Ok(complete),
        None if complete => Ok(true),
        _ => Err(()),
    }
}

fn collect_files(dir: &Path, files: &mut Vec<PathBuf>) -> Result<(), ()> {
    for entry in std::fs::read_dir(dir).map_err(|_| ())? {
        let entry = entry.map_err(|_| ())?;
        let path = entry.path();
        let metadata = entry.file_type().map_err(|_| ())?;
        if metadata.is_symlink() { return Err(()); }

        if metadata.is_dir() {
            collect_files(&path, files)?;
        } else if metadata.is_file() {
            files.push(path);
        }
    }

    Ok(())
}

async fn send_prefixed_plist(
    connection: &mut Idevice,
    dictionary: Dictionary,
) -> Result<(), ()> {
    let mut payload = Vec::new();
    Value::Dictionary(dictionary).to_writer_xml(&mut payload).map_err(|_| ())?;
    let payload_len = u32::try_from(payload.len()).map_err(|_| ())?;

    let mut frame = Vec::with_capacity(payload.len() + 4);
    frame.extend_from_slice(&payload_len.to_be_bytes());
    frame.extend_from_slice(&payload);

    connection
        .send_raw(&frame)
        .await
        .map_err(|_| ())?;
    Ok(())
}

async fn read_prefixed_plist(connection: &mut Idevice) -> Result<Dictionary, ()> {
    let len = connection
        .read_raw(4)
        .await
        .map_err(|_| ())?;
    let payload_len = u32::from_be_bytes([len[0], len[1], len[2], len[3]]) as usize;
    if !(1..=1048576).contains(&payload_len) { return Err(()); }
    let payload = connection
        .read_raw(payload_len)
        .await
        .map_err(|_| ())?;
    let value: Value = plist::from_bytes(&payload).map_err(|_| ())?;

    match value {
        Value::Dictionary(dictionary) => Ok(dictionary),
        _ => Err(()),
    }
}

async fn send_zip_directory(connection: &mut Idevice, name: &str) -> Result<(), ()> {
    let header = zip_header(name, 0, 0)?;
    connection
        .send_raw(&header)
        .await
        .map_err(|_| ())?;
    Ok(())
}

async fn send_zip_file(connection: &mut Idevice, name: &str, data: &[u8]) -> Result<(), ()> {
    let size = u32::try_from(data.len()).map_err(|_| ())?;
    let header = zip_header(name, size, crc32_ieee(data))?;

    connection
        .send_raw(&header)
        .await
        .map_err(|_| ())?;
    connection
        .send_raw(data)
        .await
        .map_err(|_| ())?;
    Ok(())
}

fn zip_header(name: &str, size: u32, crc32: u32) -> Result<Vec<u8>, ()> {
    let name_bytes = name.as_bytes();
    let name_len = u16::try_from(name_bytes.len()).map_err(|_| ())?;
    let extra_len = u16::try_from(ZIP_EXTRA.len()).map_err(|_| ())?;

    let mut header = Vec::with_capacity(30 + name_bytes.len() + ZIP_EXTRA.len());
    push_u32_le(&mut header, 0x04034b50);
    push_u16_le(&mut header, 20);
    // Preserve the Loader framing for ASCII entries and mark UTF-8 names per ZIP.
    push_u16_le(&mut header, if name.is_ascii() { 0 } else { 1 << 11 });
    push_u16_le(&mut header, 0);
    push_u16_le(&mut header, 0xbdef);
    push_u16_le(&mut header, 0x52ec);
    push_u32_le(&mut header, crc32);
    push_u32_le(&mut header, size);
    push_u32_le(&mut header, size);
    push_u16_le(&mut header, name_len);
    push_u16_le(&mut header, extra_len);
    header.extend_from_slice(name_bytes);
    header.extend_from_slice(ZIP_EXTRA);
    Ok(header)
}

fn push_u16_le(buffer: &mut Vec<u8>, value: u16) {
    buffer.extend_from_slice(&value.to_le_bytes());
}

fn push_u32_le(buffer: &mut Vec<u8>, value: u32) {
    buffer.extend_from_slice(&value.to_le_bytes());
}

fn insert_string(dictionary: &mut Dictionary, key: &str, value: impl Into<String>) {
    dictionary.insert(key.to_string(), Value::String(value.into()));
}

fn insert_integer(dictionary: &mut Dictionary, key: &str, value: i64) {
    dictionary.insert(key.to_string(), Value::Integer(value.into()));
}

fn crc32_ieee(data: &[u8]) -> u32 {
    let mut crc = 0xffff_ffffu32;

    for byte in data {
        crc ^= u32::from(*byte);
        for _ in 0..8 {
            let mask = (crc & 1).wrapping_neg();
            crc = (crc >> 1) ^ (0xedb8_8320 & mask);
        }
    }

    !crc
}



#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn zip_header_uses_sparse_loader_framing_and_ieee_crc() {
        let crc = crc32_ieee(b"123456789");
        assert_eq!(crc, 0xcbf4_3926);
        let name = "Payload/Test.app/Info.plist";
        let header = zip_header(name, 9, crc).unwrap();
        assert_eq!(&header[..4], b"PK\x03\x04");
        assert_eq!(&header[4..10], &[20, 0, 0, 0, 0, 0]);
        assert_eq!(&header[14..18], &crc.to_le_bytes());
        assert_eq!(&header[18..26], &[9, 0, 0, 0, 9, 0, 0, 0]);
        assert_eq!(&header[26..28], &(name.len() as u16).to_le_bytes());
        assert_eq!(&header[30..30 + name.len()], name.as_bytes());
        assert_eq!(&header[30 + name.len()..], ZIP_EXTRA);

        let unicode = zip_header("Payload/Test.app/名前", 0, 0).unwrap();
        assert_eq!(&unicode[6..8], &[0, 8]);
        assert!(zip_header(&"a".repeat(usize::from(u16::MAX) + 1), 0, 0).is_err());
    }

    #[test]
    fn install_requires_terminal_success_and_rejects_errors() {
        let mut response = Dictionary::new();
        assert!(install_complete(&response).is_err());
        response.insert("InstallProgressDict".into(), Value::Dictionary(Dictionary::new()));
        assert_eq!(install_complete(&response), Ok(false));
        insert_string(&mut response, "Status", "DataComplete");
        assert_eq!(install_complete(&response), Ok(true));

        let mut progress = Dictionary::new();
        insert_string(&mut progress, "Error", "Failed");
        response.insert("InstallProgressDict".into(), Value::Dictionary(progress));
        assert!(install_complete(&response).is_err());
        response.remove("InstallProgressDict");
        assert_eq!(install_complete(&response), Ok(true));
        insert_string(&mut response, "Error", "Failed");
        assert!(install_complete(&response).is_err());
    }

    #[test]
    fn validates_identity_and_host_inputs() {
        let udid = "01234567-0123456789ABCDEF";
        assert_eq!(normalized_udid(udid).as_deref(), Some("01234567-0123456789abcdef"));
        assert!(normalized_udid(&"A".repeat(40)).is_some());
        assert!(normalized_udid("01234567-0123456789ABCDEG").is_none());
        assert!(normalized_udid("0123456789012345678901234").is_none());
        assert!(is_uuid("0e3d72f1-22df-4fd5-a37c-10ebd419384a"));
        assert!(!is_uuid("0e3d72f1-22df-4fd5-a37c-10ebd419384x"));
        assert!(!is_uuid(udid));
    }
}
