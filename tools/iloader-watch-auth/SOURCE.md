# Fairway Watch Loader auth experiment

Subsequent user report (2026-10-25): the `.2` build reused the original stock
iloader key and successfully installed Fairway, which launched on the Watch.
The user later confirmed manual refresh and Watch launch through the modified
SideStore. See the maintained [reuse guide](../../docs/watch-sideloading/README.md).
Earlier CI verification statements below retain their original scope.

Independent personal derivative; not an official iloader release or an upstream contribution.
Original iloader: https://github.com/nab138/iloader and https://iloader.app/ .
No affiliation or endorsement is implied. Original license and copyright notices are retained.

Pinned application: Rzbck/iloader `09332620405e321936b25f0f381256bde08e4f86`.
Pinned library: Rzbck/isideload `06248a85a1b34ab6278b8849474bef6cc798dcf6`.
The pinned application/library are MIT-licensed. These personal patch scripts and Rust
snippets are provided under the MIT LICENSE included in this directory.
Third-party dependency licenses still apply; the distribution includes dependency
notices and the corresponding sources for dependencies identified as MPL/GPL-family.

Authentication changes backport the dynamic client metadata and bounded ADI reprovisioning
approach from nab138/isideload, examined at `065e852b2092f1386c88195ea3a6506f6b917742`.
The app uses a separate identifier and keyring service, server-scoped ADI state,
metadata cached for one session, the `hsc=409` already-pushed 2FA-code handling,
a finite provisioning timeout, WARN-level logs,
and no automatic updater or certificate revocation. Its login action obtains
authentication and an Xcode app token; app signing/installation occurs separately.

No Apple credentials, personal certificate, device UDID, pairing file, or ADI blob
is passed to CI or included in artifacts. CI uses synthetic fixtures and local
HTTP servers. Real account login, Watch provisioning/installation and renewal
remain unverified until tested by the recipient. This is AI-assisted code created
at the user's explicit request. No upstream issue, PR or maintainer message is sent.

## Explicit signing-key reuse (20261025.2)

The recipient reported that the prior build reached certificate preparation and
stopped with Apple's error 7460. This is evidence of progress beyond login on that
occasion, not proof of Watch provisioning or renewal.

A new explicit button reads only the logged-in email's SHA256/key entry from the
stock `iloader` Windows keyring service. After listing the current developer team's
iOS certificates, it requires an unexpired certificate whose public key matches.
Only then does it copy the PKCS#8 private key to the isolated experimental keyring.
It does not modify the source, copy passwords/ADI, request/revoke a certificate,
return key bytes to the webview, or export a key file. It refuses the insecure
filesystem fallback. Missing/malformed/nonmatching keys stop without a copy.

`cert_identity.rs` is intentionally modified to match an existing certificate by
its actual public key rather than a tool-specific machine name. Other files in
the pinned sideload directory remain hash-identical; the manifest lists them.
Five synthetic offline reuse tests are added. No real key or account goes to CI.
