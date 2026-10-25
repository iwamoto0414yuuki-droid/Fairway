"""Add an explicit local key reuse command to the pinned experimental build."""
from pathlib import Path

HERE = Path(__file__).resolve().parent


def apply_certificate_reuse(app, lib):
    path = lib/'isideload/src/sideload/cert_identity.rs'
    text = path.read_text(encoding='utf-8')
    start = text.index('    async fn find_matching(')
    end = text.index('    async fn request_certificate(', start)
    text = text[:start] + '''    async fn find_matching(
        private_key: &RsaPrivateKey,
        _machine_name: &str,
        developer_session: &mut DeveloperSession,
        team: &DeveloperTeam,
    ) -> Result<Option<(DevelopmentCertificate, Certificate)>, Report> {
        let certificates = developer_session.list_ios_certs(team).await?;
        Self::matching_existing_key(private_key, &certificates)
    }

''' + text[end:]
    text += '\n' + (HERE/'certificate_reuse.rs').read_text(encoding='utf-8')
    path.write_text(text, encoding='utf-8', newline='\n')

    path = app/'src-tauri/src/account.rs'
    text = path.read_text(encoding='utf-8')
    text += '''
#[tauri::command]
pub async fn reuse_original_certificate(
    sideloader_state: State<'_, SideloaderMutex>,
) -> Result<(), AppError> {
    // Require secure Windows keyring for the destination; never copy a private
    // key into the filesystem fallback or return it to the webview.
    if !crate::secure_storage::keyring_available() {
        return Err(AppError::Misc("Windowsの資格情報ストアが無効です。鍵のコピーは行っていません。".into()));
    }
    let mut sideloader = SideloaderGuard::take(&sideloader_state)?;
    let email = sideloader.get_mut().get_email().to_string();
    let team = sideloader.get_mut().get_team().await?;
    let developer = sideloader.get_mut().get_dev_session();
    let source = isideload::util::keyring_storage::KeyringStorage::new("iloader".into());
    let target = isideload::util::keyring_storage::KeyringStorage::new("fairway-watch-loader-auth-20261025".into());
    isideload::sideload::cert_identity::CertificateIdentity::reuse_key_from_storage(
        &email, developer, &team, &source, &target,
    ).await?;
    Ok(())
}
'''
    path.write_text(text, encoding='utf-8', newline='\n')
    path = app/'src-tauri/src/lib.rs'
    text = path.read_text(encoding='utf-8')
    text = text.replace('logged_in_as, login_new,', 'reuse_original_certificate, logged_in_as, login_new,')
    text = text.replace('            login_new,', '            reuse_original_certificate,\n            login_new,')
    path.write_text(text, encoding='utf-8', newline='\n')

    path = app/'src/App.tsx'
    text = path.read_text(encoding='utf-8')
    text = text.replace('  const [loggedInAs,', '  const [reusingKey, setReusingKey] = useState(false);\n  const [loggedInAs,')
    anchor = '<div className="action-row single-row">'
    assert text.count(anchor) == 1
    text = text.replace(anchor, '''<p className="settings-hint">証明書上限（7460）の場合：認証後に「通常版iloaderの署名鍵を再利用」を押し、成功してからImport IPAへ進みます。同じアカウントの有効な証明書と鍵を照合します。取消・新規発行は行いません。</p>
              <button disabled={!loggedInAs || reusingKey || !!operationState?.current}
                onClick={async () => {
                  if (!ensuredLoggedIn()) return;
                  setReusingKey(true);
                  try {
                    await invoke("reuse_original_certificate");
                    toast.success("元の署名鍵と有効な証明書が一致しました。Import IPAへ進めます。");
                  } catch (error: any) {
                    toast.error(error?.message ?? String(error));
                  } finally { setReusingKey(false); }
                }}>
                {reusingKey ? "照合中…" : "通常版iloaderの署名鍵を再利用"}
              </button>
              ''' + anchor)
    # Prevent an install while this command owns the session.
    text = text.replace('if (!ensuredLoggedIn() || !ensureSelectedDevice()) return;',
                        'if (reusingKey || !ensuredLoggedIn() || !ensureSelectedDevice()) return;')
    path.write_text(text, encoding='utf-8', newline='\n')
