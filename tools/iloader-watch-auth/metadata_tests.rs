#[cfg(test)]
mod auth_backport_metadata_tests {
    use super::*;
    use crate::util::storage::InMemoryStorage;
    use std::{io::{Read, Write}, net::TcpListener, thread};

    // Local HTTP fixture only: no Apple endpoint, account or provisioning session.
    fn server(status: u16, body: String, expected_path: &'static str) -> (String, thread::JoinHandle<()>) {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let address = format!("http://{}", listener.local_addr().unwrap());
        let worker = thread::spawn(move || {
            let (mut stream, _) = listener.accept().unwrap();
            stream.set_read_timeout(Some(std::time::Duration::from_secs(5))).unwrap();
            let mut request = Vec::new();
            let mut buffer = [0;4096];
            loop {
                let count = stream.read(&mut buffer).unwrap();
                if count == 0 { break; }
                request.extend_from_slice(&buffer[..count]);
                if request.windows(4).any(|part| part == b"\r\n\r\n") { break; }
            }
            assert!(String::from_utf8_lossy(&request).lines().next().unwrap().contains(expected_path));
            write!(stream,"HTTP/1.1 {} Result\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",status,body.len(),body).unwrap();
        });
        (address, worker)
    }
    fn provider(url: &str) -> RemoteV3AnisetteProvider {
        let _ = rustls::crypto::ring::default_provider().install_default();
        RemoteV3AnisetteProvider::new(url, Box::new(InMemoryStorage::new()), "0".into()).unwrap()
    }
    fn metadata(client: &str, ua: &str) -> String {
        serde_json::json!({"client_info":client,"user_agent":ua}).to_string()
    }
    fn check_metadata(body: String, status: u16) -> bool {
        let (url, worker)=server(status, body, "/v3/client_info");
        let p=provider(&url);
        let ok=tokio::runtime::Runtime::new().unwrap().block_on(p.get_client_info()).is_ok();
        worker.join().unwrap(); ok
    }
    #[test]
    fn auth_backport_server_metadata_and_user_agent_are_used_and_cached() {
        let (url,worker)=server(200,metadata("different valid identity","different-agent/2"),"/v3/client_info");
        let p=provider(&url);
        tokio::runtime::Runtime::new().unwrap().block_on(async {
            let first=p.get_client_info().await.unwrap();
            assert_eq!(first.client_info,"different valid identity");
            assert_eq!(first.user_agent,"different-agent/2");
            let second=p.get_client_info().await.unwrap();
            assert_eq!(first.client_info,second.client_info);
            assert_eq!(first.user_agent,second.user_agent);
        });
        worker.join().unwrap();
    }
    #[test]
    fn auth_backport_newline_header_is_rejected() { assert!(!check_metadata(metadata("bad\nidentity","ua"),200)); }
    #[test]
    fn auth_backport_empty_user_agent_is_rejected() { assert!(!check_metadata(metadata("identity",""),200)); }
    #[test]
    fn auth_backport_oversized_header_is_rejected() { assert!(!check_metadata(metadata(&"x".repeat(2049),"ua"),200)); }
    #[test]
    fn auth_backport_metadata_http_failure_has_no_fixed_fallback() { assert!(!check_metadata(metadata("identity","ua"),503)); }
    #[test]
    fn auth_backport_malformed_json_is_rejected() { assert!(!check_metadata("not json".into(),200)); }
    #[test]
    fn auth_backport_state_is_scoped_to_server_and_switch_clears_memory() {
        let mut p=provider("https://first.example");
        let original=p.storage_key();
        p.state=Some(AnisetteState::new());
        p=p.set_url("https://second.example/");
        assert_ne!(original,p.storage_key());
        assert!(p.state.is_none());
        assert!(p.client_info.get().is_none());
    }
    #[test]
    fn auth_backport_get_headers_45061_requests_new_preparation() {
        let (url,worker)=server(200,serde_json::json!({"result":"GetHeadersError","message":"not provisioned (-45061)"}).to_string(),"/v3/get_headers");
        let mut p=provider(&url);
        p.client_info.set(AnisetteClientInfo{client_info:"offline".into(),user_agent:"offline".into()}).unwrap();
        let mut state=AnisetteState::new();state.adi_pb=Some(vec![0,1,2]);p.state=Some(state);
        let result=tokio::runtime::Runtime::new().unwrap().block_on(p.get_anisette_data()).unwrap();
        assert!(matches!(result,AnisetteDataResponse::IncorrectlyProvisioned));
        worker.join().unwrap();
    }
}
