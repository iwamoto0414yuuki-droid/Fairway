# Fairway Watch Loader auth experiment

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
