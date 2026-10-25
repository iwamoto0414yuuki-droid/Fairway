#[cfg(test)]
mod auth_backport_generator_tests {
    use super::*;
    use std::collections::VecDeque;
    use std::sync::{Mutex, atomic::{AtomicUsize, Ordering}};

    #[derive(Clone, Copy)]
    enum Event { Valid, Missing, Invalid, OtherError }
    struct Fake {
        events: Mutex<VecDeque<Event>>,
        resets: Arc<Mutex<Vec<bool>>>,
        requests: Arc<AtomicUsize>,
    }
    #[async_trait::async_trait]
    impl AnisetteProvider for Fake {
        async fn get_anisette_data(&self) -> Result<AnisetteDataResponse, Report> {
            self.requests.fetch_add(1, Ordering::SeqCst);
            match self.events.lock().unwrap().pop_front().unwrap() {
                Event::Valid => Ok(AnisetteDataResponse::Data(AnisetteData {
                    machine_id: "synthetic".into(), one_time_password: "synthetic".into(),
                    routing_info: "0".into(), _device_description: "offline".into(),
                    device_unique_identifier: "synthetic".into(), _local_user_id: "synthetic".into(),
                    generated_at: SystemTime::now(),
                })),
                Event::Missing => Ok(AnisetteDataResponse::NeedsProvisioning),
                Event::Invalid => Ok(AnisetteDataResponse::IncorrectlyProvisioned),
                Event::OtherError => Err(report!("synthetic unrelated error")),
            }
        }
        async fn get_client_info(&self) -> Result<AnisetteClientInfo, Report> {
            Ok(AnisetteClientInfo { client_info: "offline".into(), user_agent: "offline".into() })
        }
        async fn provision(&mut self, _: Arc<GrandSlam>, reset: bool) -> Result<(), Report> {
            self.resets.lock().unwrap().push(reset); Ok(())
        }
    }
    fn run(events: &[Event], twice: bool) -> (bool, Vec<bool>, usize) {
        let _ = rustls::crypto::ring::default_provider().install_default();
        let resets = Arc::new(Mutex::new(Vec::new()));
        let requests = Arc::new(AtomicUsize::new(0));
        let mut generator = AnisetteDataGenerator::new(Arc::new(RwLock::new(Fake {
            events: Mutex::new(events.iter().copied().collect()), resets: resets.clone(), requests: requests.clone(),
        })));
        let gs = Arc::new(GrandSlam::offline_auth_fixture());
        let runtime = tokio::runtime::Runtime::new().unwrap();
        let success = runtime.block_on(async {
            let result = generator.get_anisette_data(gs.clone()).await;
            if result.is_ok() && twice { generator.get_anisette_data(gs).await.is_ok() } else { result.is_ok() }
        });
        let recorded = resets.lock().unwrap().clone();
        (success, recorded, requests.load(Ordering::SeqCst))
    }
    #[test]
    fn auth_backport_valid_data_is_cached() { assert_eq!(run(&[Event::Valid], true), (true, vec![], 1)); }
    #[test]
    fn auth_backport_missing_state_is_prepared() { assert_eq!(run(&[Event::Missing, Event::Valid], false), (true, vec![false], 2)); }
    #[test]
    fn auth_backport_rejected_state_forces_new_preparation() { assert_eq!(run(&[Event::Invalid, Event::Valid], false), (true, vec![true], 2)); }
    #[test]
    fn auth_backport_stale_persisted_state_can_recover() { assert_eq!(run(&[Event::Missing, Event::Invalid, Event::Valid], false), (true, vec![false, true], 3)); }
    #[test]
    fn auth_backport_repeated_rejection_is_bounded() { assert_eq!(run(&[Event::Invalid, Event::Invalid, Event::Invalid], false), (false, vec![true,true,true], 3)); }
    #[test]
    fn auth_backport_unrelated_error_does_not_reset() { assert_eq!(run(&[Event::OtherError], false), (false, vec![], 1)); }
}
