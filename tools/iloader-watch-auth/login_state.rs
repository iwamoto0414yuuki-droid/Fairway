// Backport: Apple may already have sent the code without the older `au` field.
// This runs only after the password proof and SPD decryption have succeeded.
fn auth_backport_login_state(status: &plist::Dictionary) -> LoginState {
    if let Some(plist::Value::String(value)) = status.get("au") {
        return match value.as_str() {
            "trustedDeviceSecondaryAuth" => LoginState::NeedsDevice2FA,
            "secondaryAuth" => LoginState::NeedsSMS2FA(1),
            "repair" => LoginState::LoggedIn,
            other => LoginState::NeedsExtraStep(other.to_string()),
        };
    }
    if status.get("hsc").and_then(plist::Value::as_signed_integer) == Some(409) {
        return LoginState::NeedsDevice2FAVerification;
    }
    LoginState::LoggedIn
}

#[cfg(test)]
mod auth_backport_login_state_tests {
    use super::*;
    use plist_macro::plist;
    #[test]
    fn auth_backport_already_pushed_code_without_au_is_verified_directly() {
        assert!(matches!(auth_backport_login_state(&plist!(dict {"hsc":409})),LoginState::NeedsDevice2FAVerification));
    }
    #[test]
    fn auth_backport_legacy_device_challenge_is_preserved() {
        assert!(matches!(auth_backport_login_state(&plist!(dict {"au":"trustedDeviceSecondaryAuth"})),LoginState::NeedsDevice2FA));
    }
    #[test]
    fn auth_backport_success_without_challenge_remains_logged_in() {
        assert!(matches!(auth_backport_login_state(&plist!(dict {"hsc":200})),LoginState::LoggedIn));
    }
    #[test]
    fn auth_backport_sms_challenge_is_preserved() {
        assert!(matches!(auth_backport_login_state(&plist!(dict {"au":"secondaryAuth"})),LoginState::NeedsSMS2FA(1)));
    }
    #[test]
    fn auth_backport_legacy_au_takes_precedence() {
        assert!(matches!(auth_backport_login_state(&plist!(dict {"au":"trustedDeviceSecondaryAuth","hsc":409})),LoginState::NeedsDevice2FA));
    }
    #[test]
    fn auth_backport_unknown_challenge_is_not_assumed_success() {
        assert!(matches!(auth_backport_login_state(&plist!(dict {"au":"unknown-step"})),LoginState::NeedsExtraStep(value) if value=="unknown-step"));
    }
    #[test]
    fn auth_backport_repair_state_preserves_upstream_behavior() {
        assert!(matches!(auth_backport_login_state(&plist!(dict {"au":"repair"})),LoginState::LoggedIn));
    }
}
