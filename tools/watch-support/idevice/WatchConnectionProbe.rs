//! Non-destructive, same-thread Watch connectivity probe for idevice 3e55c84.
use std::{ffi::{c_char, CStr, CString}, ptr::null_mut, time::Duration};
use idevice::{Idevice, IdeviceError, RsdService, companion_proxy::CompanionProxy,
    lockdown::LockdownClient};
use crate::{core_device_proxy::AdapterHandle, rsd::RsdHandshakeHandle,
    IdeviceFfiError, ffi_err, run_sync_local};

const SERVICE: &str = "com.apple.companion_proxy.shim.remote";
const PORT: u16 = 62078;
const STAGES: [&str; 5] = ["WCP_SERVICE", "WCP_REGISTRY", "WCP_FORWARD", "WCP_CONNECT", "WCP_IDENTITY"];

#[derive(Clone, Copy, Debug, PartialEq)]
enum Outcome { Pending, Passed, Failed, Timeout }
impl Outcome {
    fn code(self) -> &'static str {
        match self { Self::Pending => "NOT_RUN", Self::Passed => "OK", Self::Failed => "FAILED", Self::Timeout => "TIMEOUT" }
    }
}

#[derive(Debug)]
struct Report { stages: [Outcome; 5], active: usize, cleanup: Outcome, input: &'static str }
impl Report {
    fn new() -> Self { Self { stages: [Outcome::Pending; 5], active: 0, cleanup: Outcome::Pending, input: "OK" } }
    // Only closed enums and static codes enter the public report. Never format an upstream error.
    fn render(&self) -> String {
        let mut text = format!("WCP_INPUT passed={} code={}\n", self.input == "OK", self.input);
        for (name, outcome) in STAGES.iter().zip(self.stages) {
            text.push_str(&format!("{name} passed={} code={}\n", outcome == Outcome::Passed, outcome.code()));
        }
        text.push_str(&format!("WCP_CLEANUP passed={} code={}\n", self.cleanup == Outcome::Passed, self.cleanup.code()));
        text
    }
    fn finish(&self) -> Result<(), &'static str> {
        if self.cleanup != Outcome::Pending && self.cleanup != Outcome::Passed { return Err("WCP_CLEANUP"); }
        self.stages.iter().position(|x| *x != Outcome::Passed).map_or(Ok(()), |i| Err(STAGES[i]))
    }
}

fn normalize_udid(text: &str) -> Option<String> {
    let text = text.trim();
    let bytes = text.as_bytes();
    let valid = (bytes.len() == 40 && bytes.iter().all(u8::is_ascii_hexdigit))
        || (bytes.len() == 25 && bytes[8] == b'-'
            && bytes[..8].iter().chain(bytes[9..].iter()).all(u8::is_ascii_hexdigit));
    valid.then(|| text.to_ascii_lowercase())
}

fn registry_matches(registry: &[String], expected: &str) -> bool {
    registry.len() == 1 && normalize_udid(&registry[0]).as_deref() == Some(expected)
}

/// Borrow both handles exclusively on their owning FFI thread for the entire call.
/// No pairing/session, transfer, install, uninstall, or credential operations occur.
/// `report` receives an owned string on every path where it is non-null; release it
/// with idevice_string_free. All non-null input pointers must be valid and live.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn fairway_watch_connection_probe(
    adapter: *mut AdapterHandle, handshake: *mut RsdHandshakeHandle,
    expected_udid: *const c_char, report: *mut *mut c_char,
) -> *mut IdeviceFfiError {
    let mut result = Report::new();
    if report.is_null() { return ffi_err!(IdeviceError::InternalError("WCP_INPUT".into())); }
    unsafe { *report = null_mut(); }
    let expected = if adapter.is_null() || handshake.is_null() || expected_udid.is_null() {
        result.input = "NULL_ARGUMENT"; None
    } else {
        match unsafe { CStr::from_ptr(expected_udid) }.to_str() {
            Ok(text) => { let value = normalize_udid(text); if value.is_none() { result.input = "UDID_FORMAT"; } value }
            Err(_) => { result.input = "UTF8"; None }
        }
    };
    let status = if let Some(expected) = expected {
        run_sync_local(async {
            let adapter = unsafe { &mut (*adapter).0 };
            let handshake = unsafe { &mut (*handshake).0 };
            // Set before sending StartForwarding: cancellation can leave a forward
            // active even when its response was never received.
            let mut forward_attempted = false;
            let probe = tokio::time::timeout(Duration::from_secs(50), async {
                result.active = 0;
                if !handshake.services.contains_key(SERVICE) { return Err(()); }
                result.stages[0] = Outcome::Passed;
                result.active = 1;
                let mut proxy = CompanionProxy::connect_rsd(adapter, handshake).await.map_err(|_| ())?;
                let devices = proxy.get_device_registry().await.map_err(|_| ())?;
                if !registry_matches(&devices, &expected) { return Err(()); }
                result.stages[1] = Outcome::Passed;
                drop(proxy);
                result.active = 2;
                let mut proxy = CompanionProxy::connect_rsd(adapter, handshake).await.map_err(|_| ())?;
                forward_attempted = true;
                let port = proxy.start_forwarding_service_port(PORT, Some("com.apple.mobile.lockdownd"), None)
                    .await.map_err(|_| ())?;
                if port == 0 { return Err(()); }
                result.stages[2] = Outcome::Passed;
                drop(proxy);
                result.active = 3;
                // Forward readiness can lag its response. Each attempt is bounded;
                // the outer deadline also bounds all registry/identity traffic.
                let mut connected = None;
                for attempt in 0..3 {
                    if let Ok(Ok(stream)) = tokio::time::timeout(Duration::from_secs(5), adapter.connect(port)).await {
                        connected = Some(stream); break;
                    }
                    if attempt < 2 { tokio::time::sleep(Duration::from_millis(400)).await; }
                }
                let stream = connected.ok_or(())?;
                result.stages[3] = Outcome::Passed;
                result.active = 4;
                // The forwarded endpoint is native Watch lockdown, not an RSD
                // shim. Do not perform rsd_checkin or start a pairing session.
                let mut lockdown = LockdownClient::new(Idevice::new(Box::new(stream), "FairwayWatchProbe"));
                let identity = lockdown.get_value(Some("UniqueDeviceID"), None).await.map_err(|_| ())?;
                if identity.as_string().and_then(normalize_udid).as_deref() != Some(expected.as_str()) { return Err(()); }
                result.stages[4] = Outcome::Passed;
                Ok::<(), ()>(())
            }).await;
            match probe {
                Ok(Ok(())) => {},
                Ok(Err(())) => result.stages[result.active] = Outcome::Failed,
                Err(_) => result.stages[result.active] = Outcome::Timeout,
            }
            // This runs outside the cancelled probe future, after its mutable
            // borrows/connections have dropped. Fresh proxy on each retry.
            if forward_attempted {
                result.cleanup = Outcome::Failed;
                for _ in 0..2 {
                    let cleanup = tokio::time::timeout(Duration::from_secs(5), async {
                        let mut proxy = CompanionProxy::connect_rsd(adapter, handshake).await?;
                        proxy.stop_forwarding_service_port(PORT).await
                    }).await;
                    match cleanup {
                        Ok(Ok(())) => { result.cleanup = Outcome::Passed; break; },
                        Ok(Err(_)) => result.cleanup = Outcome::Failed,
                        Err(_) => result.cleanup = Outcome::Timeout,
                    }
                }
            }
            result.finish()
        })
    } else { Err("WCP_INPUT") };
    // render is made exclusively of static ASCII, booleans, and line breaks.
    unsafe { *report = CString::new(result.render()).expect("static report has no NUL").into_raw(); }
    match status {
        Ok(()) => null_mut(),
        Err(code) => ffi_err!(IdeviceError::InternalError(code.into())),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    const UDID: &str = "01234567-0123456789abcdef";
    #[test] fn udid_boundaries() {
        assert_eq!(normalize_udid(" 01234567-0123456789ABCDEF\n").as_deref(), Some(UDID));
        assert!(normalize_udid(&"a".repeat(40)).is_some());
        for value in ["", "012345670123456789abcdef", "0123456-70123456789abcdef", "01234567-0123456789abcdeg", "日本語"] {
            assert!(normalize_udid(value).is_none());
        }
    }
    #[test] fn registry_requires_one_unambiguous_watch() {
        let watch = UDID.to_uppercase();
        assert!(registry_matches(&[watch.clone()], UDID));
        assert!(!registry_matches(&[], UDID));
        assert!(!registry_matches(&[watch.clone(), watch], UDID));
        assert!(!registry_matches(&["a".repeat(40)], UDID));
    }
    #[test] fn cleanup_failure_overrides_probe_success() {
        let mut report = Report::new(); report.stages = [Outcome::Passed; 5];
        report.cleanup = Outcome::Timeout;
        assert_eq!(report.finish(), Err("WCP_CLEANUP"));
        report.cleanup = Outcome::Passed; assert_eq!(report.finish(), Ok(()));
    }
    #[test] fn preserves_failing_stage_after_successful_cleanup() {
        let mut report = Report::new(); report.stages[..3].fill(Outcome::Passed);
        report.stages[3] = Outcome::Timeout; report.cleanup = Outcome::Passed;
        assert_eq!(report.finish(), Err("WCP_CONNECT"));
        assert!(report.render().contains("WCP_IDENTITY passed=false code=NOT_RUN"));
    }
    #[test] fn report_accepts_no_dynamic_error_or_identity_fields() {
        let mut report = Report::new(); report.stages[1] = Outcome::Failed;
        let rendered = report.render();
        assert!(!rendered.contains(UDID));
        assert!(!rendered.contains("HostID")); assert!(!rendered.contains("BUID"));
        assert!(rendered.is_ascii()); assert!(!rendered.contains('\0'));
        assert_eq!(rendered.lines().count(), 7);
    }
}
