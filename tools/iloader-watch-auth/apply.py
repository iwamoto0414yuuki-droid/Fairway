"""Narrow auth backport to the pinned, independently developed Watch fork."""
from pathlib import Path
import hashlib
import json
import shutil
import sys

HERE = Path(__file__).resolve().parent
APP_REF = '09332620405e321936b25f0f381256bde08e4f86'
LIB_REF = '06248a85a1b34ab6278b8849474bef6cc798dcf6'
SERVICE = 'fairway-watch-loader-auth-20261025'


def replace(root, name, before, after, count=1):
    path = root / name
    text = path.read_text(encoding='utf-8')
    assert text.count(before) == count, (name, before[:70], text.count(before))
    path.write_text(text.replace(before, after), encoding='utf-8', newline='\n')


def apply(app, lib):
    # Preserve exact Watch implementation files; auth changes must not replace them.
    watch = {p.relative_to(lib).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
             for p in (lib/'isideload/src/sideload').glob('*.rs')}
    path = 'isideload/src/anisette/mod.rs'
    replace(lib, path, '#[cfg_attr(feature = "wasm", async_trait::async_trait(?Send))]',
            '#[derive(Debug, Clone)]\npub enum AnisetteDataResponse {\n    Data(AnisetteData),\n    NeedsProvisioning,\n    IncorrectlyProvisioned,\n}\n\n#[cfg_attr(feature = "wasm", async_trait::async_trait(?Send))]')
    replace(lib, path, 'async fn get_anisette_data(&self) -> Result<AnisetteData, Report>;',
            'async fn get_anisette_data(&self) -> Result<AnisetteDataResponse, Report>;')
    replace(lib, path, 'async fn provision(&mut self, gs: Arc<GrandSlam>) -> Result<(), Report>;\n\n    fn needs_provisioning(&self) -> Result<bool, Report>;',
            'async fn provision(&mut self, gs: Arc<GrandSlam>, force_reset: bool) -> Result<(), Report>;')
    file = lib/path
    text = file.read_text(encoding='utf-8')
    start = text.index('        // trying to avoid locking as write')
    end = text.index('    pub async fn get_client_info', start)
    replacement = (HERE/'generator.rs').read_text(encoding='utf-8')
    file.write_text(text[:start] + replacement + '\n' + text[end:], encoding='utf-8', newline='\n')
    with file.open('a', encoding='utf-8') as output:
        output.write('\n' + (HERE/'generator_tests.rs').read_text(encoding='utf-8'))

    path = 'isideload/src/anisette/remote_v3/mod.rs'
    replace(lib, path, 'use crate::anisette::{AnisetteClientInfo, AnisetteData, AnisetteProvider};',
            'use crate::anisette::{AnisetteClientInfo, AnisetteData, AnisetteDataResponse, AnisetteProvider};')
    replace(lib, path, '"https://ani.stikstore.app"', '"https://ani.jkcoxson.com"')
    replace(lib, path, '    pub state: Option<AnisetteState>,',
            '    pub state: Option<AnisetteState>,\n    client_info: tokio::sync::OnceCell<AnisetteClientInfo>,')
    replace(lib, path, '            state: None,', '            state: None,\n            client_info: tokio::sync::OnceCell::new(),')
    replace(lib, path, '        self.url = url.to_string();',
            '        self.url = url.trim_end_matches(\'/\').to_string();\n        self.state = None;\n        self.client_info = tokio::sync::OnceCell::new();')
    replace(lib, path, 'ClientBuilder::new().build()?;',
            'ClientBuilder::new().connect_timeout(std::time::Duration::from_secs(15)).timeout(std::time::Duration::from_secs(30)).build()?;', count=2)
    file = lib/path
    text = file.read_text(encoding='utf-8')
    start = text.index('    async fn get_client_info(&self)')
    end = text.index('\n}\n\nimpl RemoteV3AnisetteProvider', start)
    text = text[:start] + (HERE/'metadata.rs').read_text(encoding='utf-8') + text[end:]
    file.write_text(text, encoding='utf-8', newline='\n')
    replace(lib, path, 'async fn get_anisette_data(&self) -> Result<AnisetteData, Report> {\n        let state = self\n            .state\n            .as_ref()\n            .ok_or(SideloadError::AnisetteNotProvisioned)?;\n        let adi_pb = state\n            .adi_pb\n            .as_ref()\n            .ok_or(SideloadError::AnisetteNotProvisioned)?;',
            'async fn get_anisette_data(&self) -> Result<AnisetteDataResponse, Report> {\n        let Some(state) = self.state.as_ref() else { return Ok(AnisetteDataResponse::NeedsProvisioning); };\n        let Some(adi_pb) = state.adi_pb.as_ref() else { return Ok(AnisetteDataResponse::NeedsProvisioning); };')
    replace(lib, path, '                Ok(data)', '                Ok(AnisetteDataResponse::Data(data))')
    replace(lib, path, '            AnisetteHeaders::GetHeadersError { message } => {\n                Err(report!("Failed to get anisette headers").attach(message))',
            '            AnisetteHeaders::GetHeadersError { message } => {\n                if message.contains("-45061") { return Ok(AnisetteDataResponse::IncorrectlyProvisioned); }\n                Err(report!("Failed to get anisette headers").attach(message))')
    replace(lib, path, 'async fn get_state(&mut self, gs: Arc<GrandSlam>) -> Result<&mut AnisetteState, Report> {\n        if self.state.is_none() {',
            'async fn get_state(&mut self, gs: Arc<GrandSlam>, force_reset: bool) -> Result<&mut AnisetteState, Report> {\n        if force_reset { self.state = Some(AnisetteState::new()); }\n        if self.state.is_none() {')
    replace(lib, path, 'retrieve_data("anisette_state")', 'retrieve_data(&self.storage_key())')
    replace(lib, path, '        let state = self.state.as_mut().ok_or_report()?;',
            '        let storage_key = self.storage_key();\n        let state = self.state.as_mut().ok_or_report()?;')
    replace(lib, path, '.store_data("anisette_state", &writer.into_inner()?)?',
            '.store_data(&storage_key, &writer.into_inner()?)?')
    replace(lib, path, 'impl RemoteV3AnisetteProvider {\n    async fn get_state',
            'impl RemoteV3AnisetteProvider {\n    fn storage_key(&self) -> String {\n        format!("watch_auth_v2_{}", hex::encode(self.url.trim_end_matches(\'/\').as_bytes()))\n    }\n\n    async fn get_state')
    replace(lib, path, 'let Some(msg) = ws.next().await else { continue };',
            'let Some(msg) = tokio::time::timeout(std::time::Duration::from_secs(45), ws.next()).await.context("Anisette provisioning timed out")? else { bail!("Anisette provisioning channel closed"); };')
    with file.open('a', encoding='utf-8') as output:
        output.write('\n' + (HERE/'metadata_tests.rs').read_text(encoding='utf-8'))

    # A network-free constructor exists only in cargo test builds.
    replace(lib, 'isideload/src/auth/grandslam.rs', 'impl GrandSlam {',
            'impl GrandSlam {\n    #[cfg(test)]\n    pub(crate) fn offline_auth_fixture() -> Self {\n        Self { client: Self::build_reqwest_client(false, None).unwrap(), client_info: AnisetteClientInfo { client_info: "offline".into(), user_agent: "offline".into() }, url_bag: Dictionary::new() }\n    }')
    replace(lib, 'isideload/src/auth/grandslam.rs', '        Ok(headers)\n    }',
            '        headers.insert(reqwest::header::CONNECTION, HeaderValue::from_static("close"));\n        Ok(headers)\n    }')
    path='isideload/src/auth/apple_account.rs'
    p=lib/path;s=p.read_text(encoding='utf-8')
    start=s.index('        if let Some(plist::Value::String(s)) = status.get("au") {')
    end=s.index('\n    pub async fn get_app_token',start)
    s=s[:start]+'''        let state = auth_backport_login_state(status);
        if matches!(state, LoginState::NeedsDevice2FAVerification) {
            self.update_trusted_numbers().await;
        }
        Ok(state)
    }
''' +s[end:]
    s+='\n'+(HERE/'login_state.rs').read_text(encoding='utf-8')
    p.write_text(s,encoding='utf-8',newline='\n')

    # App identity, keyring service and app-data directory are distinct from stock iloader.
    for path in ('src-tauri/src/account.rs', 'src-tauri/src/secure_storage.rs'):
        p=app/path;s=p.read_text(encoding='utf-8');assert '"iloader"' in s
        p.write_text(s.replace('"iloader"', json.dumps(SERVICE)), encoding='utf-8', newline='\n')
    # Reset only this build's active-server ADI key, including its filesystem fallback.
    p=app/'src-tauri/src/account.rs';s=p.read_text(encoding='utf-8')
    start=s.index('pub fn reset_anisette_state()')
    end=s.index('\nasync fn login(',start)
    s=s[:start]+'''pub fn reset_anisette_state(handle: AppHandle, anisette_server: String) -> Result<bool, AppError> {
    let url = if anisette_server.starts_with("http") { anisette_server } else { format!("https://{}", anisette_server) };
    let key = format!("watch_auth_v2_{}", hex::encode(url.trim_end_matches('/').as_bytes()));
    let storage = create_sideloading_storage(&handle)?;
    storage.delete(&key)?;
    Ok(true)
}
''' + s[end:]
    p.write_text(s,encoding='utf-8',newline='\n')
    replace(app, 'src/pages/Settings.tsx', 'invoke("reset_anisette_state")',
            'invoke("reset_anisette_state", { anisetteServer })')
    # hex is already used by the library; declare it explicitly for this app helper.
    replace(app, 'src-tauri/Cargo.toml', '[dependencies]', '[dependencies]\nhex = "0.4.3"')
    replace(app, 'src-tauri/Cargo.toml',
            'isideload = { version = "0.3.17", features = ["fs-storage"], git = "https://github.com/Rzbck/isideload", package = "isideload", rev = "'+LIB_REF+'" }',
            'isideload = { path = "../../isideload/isideload", features = ["fs-storage"] }')
    replace(app, 'src-tauri/src/account.rs', '.max_certs_behavior(MaxCertsBehavior::Prompt(Box::new(max_certs_callback)))',
            '.max_certs_behavior(MaxCertsBehavior::Error)')
    replace(app, 'src-tauri/src/account.rs', '.storage(create_sideloading_storage(app)?)',
            '.machine_name("Fairway Watch Loader Auth".to_string())\n        .storage(create_sideloading_storage(app)?)')
    p=app/'src-tauri/src/account.rs';s=p.read_text(encoding='utf-8')
    start=s.index('    let max_certs_callback = {');end=s.index('    // TODO: Team Selection',start)
    p.write_text(s[:start]+s[end:], encoding='utf-8', newline='\n')
    replace(app, 'src-tauri/src/lib.rs', '        .plugin(tauri_plugin_updater::Builder::new().build())\n', '')
    replace(app, 'src-tauri/src/lib.rs', 'LevelFilter::DEBUG', 'LevelFilter::WARN', count=2)
    (app/'src/update.ts').write_text('export async function checkForUpdates() { /* Personal build: updates are provided manually. */ }\n',encoding='utf-8')
    config=app/'src-tauri/tauri.conf.json';c=json.loads(config.read_text())
    c.update(productName='Fairway Watch Loader', identifier='local.fairway.watchloader.auth20261025', version='2.3.1-auth.20261025.1')
    c['app']['windows'][0]['title']='Fairway Watch Loader — 認証更新試験版'
    c['plugins']={};c['bundle']['active']=False;c['bundle']['createUpdaterArtifacts']=False
    config.write_text(json.dumps(c,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    replace(app, 'src/App.tsx', '<h1 className="title">iloader</h1>',
            '<h1 className="title">Fairway Watch Loader</h1>')
    p=app/'src/App.tsx';s=p.read_text(encoding='utf-8')
    start=s.index('<div className="action-row single-row">')
    first=s.index('                <button',start)
    last=s.index('                <button\n                  onClick={async () => {',first)
    assert s[first:last].count('<button')==4
    s=s[:first]+s[last:]
    s=s.replace('  installSideStoreOperation,\n','').replace('  installLiveContainerOperation,\n','')
    s=s.replace('{t("app.installers")}','Fairwayを導入').replace('{t("app.choose_build")}','認証成功後にIPAを選択')
    p.write_text(s,encoding='utf-8',newline='\n')
    # All default server references follow the provider whose metadata was checked.
    for p in (app/'src').rglob('*'):
        if p.suffix in ('.ts','.tsx'):
            s=p.read_text(encoding='utf-8')
            if '"ani.sidestore.io"' in s:p.write_text(s.replace('"ani.sidestore.io"','"ani.jkcoxson.com"'),encoding='utf-8',newline='\n')
    replace(app, 'src/AppleID.tsx', '<button type="submit">{t("apple_id.login")}</button>',
            '<p className="settings-hint">個人用Watch試験版です。最初は「認証を確認」だけを実行してください。この操作では証明書の作成・取消やアプリ導入は行いません。</p>\n              <button type="submit">認証を確認（Login）</button>')
    after={p.relative_to(lib).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
           for p in (lib/'isideload/src/sideload').glob('*.rs')}
    assert watch==after, 'Watch signing/install implementation unexpectedly changed'
    (app.parent/'watch-auth-patch.json').write_text(json.dumps({
        'iloader_base':APP_REF,'isideload_base':LIB_REF,'keyring_service':SERVICE,
        'watch_signing_install_files_unchanged':watch,'automatic_certificate_revocation':False,
        'physical_login_verified':False,'physical_watch_install_verified':False},indent=2)+'\n')


if __name__=='__main__':
    apply(Path(sys.argv[1]).resolve(),Path(sys.argv[2]).resolve())
