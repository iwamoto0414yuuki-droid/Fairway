# Contributing

Fairway improvements, Watch installation fixes, power-use measurements, and reproducible device reports are welcome. Open an issue for a proposal or submit a pull request against main. This repository accepts AI-assisted contributions if the contributor reviews and tests them and explains the validation performed.

## Reports

Include app/SideStore version and commit, device models, OS versions, free/paid account category, manual or automated refresh, the safe stage code, and whether Watch launch and existing data survived. Use fictional sample data. Do not upload Apple Account addresses, passwords, tokens, certificates, real provisioning profiles, pairing records, UDIDs, or full console logs. A small redacted excerpt is sufficient.

## Development

- Fairway: XcodeGen project.yml, Shared/, iPhone/, Watch/, Tests/. Run relevant native tests and check small Watch screens.
- SideStore: tools/watch-support/ overlays and pinned build workflow. Preserve profile identity/certificate checks and companion bundle relationships.
- Never treat iPhone install, Watch transport connectivity, successful upload, final Watch install, and post-refresh Watch launch as interchangeable results.
- Keep existing app data during updates. For an App Group change, assess the actual data container before migration; the Fairway-specific repair is not a generic migration for other apps.
- Protect native handle ownership, serialize companion forwarding, bound timeouts, and release forwards on error. Never pair again silently during a background refresh.
- Keep the corresponding source and original third-party notices with any binary distribution.

For a new application, follow docs/watch-sideloading/REUSE_GUIDE.md. Explain what was tested on real hardware and what was only checked offline. Contributions must be compatible with the applicable project and third-party licenses; existing rights are not reassigned by submission.
