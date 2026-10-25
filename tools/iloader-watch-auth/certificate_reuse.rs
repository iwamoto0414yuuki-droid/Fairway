// Explicit, local-only migration. The source is never modified and no certificate
// is requested/revoked. Only Apple's current team's matching public key permits a copy.
impl CertificateIdentity {
    pub async fn reuse_key_from_storage(
        email: &str,
        developer: &mut DeveloperSession,
        team: &DeveloperTeam,
        source: &dyn SideloadingStorage,
        target: &dyn SideloadingStorage,
    ) -> Result<(), Report> {
        let key = format!("{}/key", hex::encode(Sha256::digest(email.as_bytes())));
        let der = source.retrieve_data(&key)?.ok_or_else(|| report!(
            "元のiloaderの署名鍵が見つかりません。証明書は取り消していません。"))?;
        let certificates = developer.list_ios_certs(team).await?;
        Self::copy_verified_key(&key, &der, &certificates, target)
    }

    fn matching_existing_key(
        private_key: &RsaPrivateKey,
        certificates: &[DevelopmentCertificate],
    ) -> Result<Option<(DevelopmentCertificate, Certificate)>, Report> {
        let public = private_key.to_public_key().to_pkcs1_der()?;
        for cert in certificates.iter().filter(|c| c.machine_id.is_some()) {
            let Some(data) = &cert.cert_content else { continue; };
            let Ok(parsed) = Certificate::from_der(data.as_ref()) else { continue; };
            let validity = &parsed.tbs_certificate.validity;
            let now = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH)?;
            if now < validity.not_before.to_unix_duration() || now > validity.not_after.to_unix_duration() {
                continue;
            }
            if parsed.tbs_certificate.subject_public_key_info.subject_public_key.as_bytes()
                == Some(public.as_bytes()) {
                return Ok(Some((cert.clone(), parsed)));
            }
        }
        Ok(None)
    }

    fn copy_verified_key(
        key: &str, der: &[u8], certificates: &[DevelopmentCertificate],
        target: &dyn SideloadingStorage,
    ) -> Result<(), Report> {
        let private = RsaPrivateKey::from_pkcs8_der(der)
            .context("元の署名鍵を読み取れません。コピーは行っていません。")?;
        if Self::matching_existing_key(&private, certificates)?.is_none() {
            bail!("このアカウントの有効な証明書と元の署名鍵が一致しません。コピー・取消・新規発行は行っていません。");
        }
        target.store_data(key, der)?;
        Ok(())
    }
}

#[cfg(test)]
mod certificate_reuse_tests {
    use super::*;
    use crate::util::storage::InMemoryStorage;

    fn fixture() -> (RsaPrivateKey, DevelopmentCertificate) {
        let private = RsaPrivateKey::new(&mut rand::thread_rng(), 2048).unwrap();
        let pem = private.to_pkcs8_pem(LineEnding::LF).unwrap();
        let pair = KeyPair::from_pkcs8_pem_and_sign_algo(&pem, &PKCS_RSA_SHA256).unwrap();
        let cert = CertificateParams::new(vec![]).unwrap().self_signed(&pair).unwrap();
        let data = plist::Value::Dictionary(plist::Dictionary::from_iter([
            ("machineId".into(), plist::Value::String("offline".into())),
            ("machineName".into(), plist::Value::String("original iloader".into())),
            ("certContent".into(), plist::Value::Data(cert.der().to_vec())),
        ]));
        (private, plist::from_value(&data).unwrap())
    }

    #[test]
    fn certificate_reuse_accepts_public_key_with_original_machine_name() {
        let (key, cert) = fixture();
        assert!(CertificateIdentity::matching_existing_key(&key, &[cert]).unwrap().is_some());
    }

    #[test]
    fn certificate_reuse_wrong_key_keeps_target_unchanged() {
        let (_, cert) = fixture();
        let other = RsaPrivateKey::new(&mut rand::thread_rng(), 2048).unwrap();
        let target = InMemoryStorage::new();
        target.store_data("key", b"keep").unwrap();
        assert!(CertificateIdentity::copy_verified_key("key", other.to_pkcs8_der().unwrap().as_bytes(), &[cert], &target).is_err());
        assert_eq!(target.retrieve_data("key").unwrap().unwrap(), b"keep");
    }

    #[test]
    fn certificate_reuse_copies_only_validated_key() {
        let (key, cert) = fixture();
        let target = InMemoryStorage::new();
        let der = key.to_pkcs8_der().unwrap();
        CertificateIdentity::copy_verified_key("key", der.as_bytes(), &[cert], &target).unwrap();
        assert_eq!(target.retrieve_data("key").unwrap().unwrap(), der.as_bytes());
        assert!(target.retrieve_data("anisette_state").unwrap().is_none());
    }

    #[test]
    fn certificate_reuse_invalid_key_keeps_target_unchanged() {
        let target = InMemoryStorage::new();
        assert!(CertificateIdentity::copy_verified_key("key", b"invalid", &[], &target).is_err());
        assert!(target.retrieve_data("key").unwrap().is_none());
    }

    #[test]
    fn certificate_reuse_missing_certificate_keeps_target_unchanged() {
        let (key, _) = fixture();
        let target = InMemoryStorage::new();
        assert!(CertificateIdentity::copy_verified_key("key", key.to_pkcs8_der().unwrap().as_bytes(), &[], &target).is_err());
        assert!(target.retrieve_data("key").unwrap().is_none());
    }
}
