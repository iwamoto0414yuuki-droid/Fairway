# Personal SideStore Watch experiment

Current result: the device owner confirmed SideStore-origin iPhone/Watch installation and successful Fairway Refresh followed by Watch operation after the final App Group fix (runtime source cc13860). The public main branch contains the corresponding patches and build workflow. Automatic execution over time and post-expiry operation remain separate validation items. See the [reuse guide](../../docs/watch-sideloading/REUSE_GUIDE.md).

The completed native bridge modifies SideStore/idevice at 3e55c8486b2057e40c1f74aaaa1155c82341cf76. WatchInstall.rs adds Watch pairing and streaming installation; WatchConnectionProbe.rs is still a non-destructive diagnostic. Upstream source and original license notices accompany the corresponding-source archive.

This is independent personal development for Fairway, not an official SideStore release or an upstream contribution. No maintainer review, issue, comment, PR, or endorsement is requested or implied.

Upstream SideStore: https://github.com/SideStore/SideStore at `d97ec133719d79916675bdaf722b82a8d091d545`, under its AGPL-3.0 license. SideSign dependency: https://github.com/SideStore/SideSign at `752d1ef602aa792a432ffa1e71646dc1ecf7363c`, under its included license. All original copyright/license notices are retained. Generated IPA packages must include the corresponding modified source and original license texts.

The patch overlays and build scripts in this directory are provided under AGPL-3.0-or-later for this personal derivative. The independent Windows `watch_info.py` helper is GPL-3.0-or-later and uses the GPL-3.0-or-later pymobiledevice3 package. Its source archive and license accompany the distributed helper. This is AI-assisted experimental code. It has not been tested on the recipient's physical devices. Existing account storage, app identifiers, authentication code and certificate selection are intentionally retained. Installation and manual refresh were confirmed in the reported Fairway environment; other devices/apps require their own validation.

Watch developer-service parameter conventions were checked against the independent MIT-licensed implementation at https://github.com/Rzbck/isideload/tree/f7b9f3da570edd6824c29680545e710846d07df5/isideload/src/dev . No credentials, profiles, keys, pairing records, account IDs, or device identifiers belong in source control or build artifacts.

The user explicitly requested that Codex implement this personal derivative. This is not submission of AI-generated contribution content to the upstream SideStore project. Upstream contribution and automated-maintainer-contact restrictions are respected; CI and publication are confined to the user's existing Fairway repository.

## iOS-family profile correction

The recipient's diagnostic showed only a Platform mismatch, with Apple's returned
array containing iOS and visionOS. Apple's development-profile documentation says
iOS App Development covers iOS and watchOS apps:
https://developer.apple.com/help/account/provisioning-profiles/create-a-development-provisioning-profile

The prior literal watchOS requirement rejected this observed profile. The companion
workflow now explicitly allows an iOS-family array after watch-scoped registration
and retrieval. A Watch UDID match, exact child bundle ID, team, expiry and current
signing certificate remain required. Generic validation defaults to rejecting the
iOS-family alternative. Empty/foreign platform arrays remain rejected. Real-device installation and manual renewal were subsequently confirmed for Fairway.
