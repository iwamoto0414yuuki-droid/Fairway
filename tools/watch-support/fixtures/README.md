# Frozen real application signing fixture

`Fairway-0.3.0-unsigned.ipa` is the exact unsigned Fairway build from
[run 40140421334](https://github.com/iwamoto0414yuuki-droid/Fairway/actions/runs/40140421334),
source `ad565069f56d6b8e645a6581eb829b0363aa1cbf`.

SHA256: `1b3e3c21f3f21ce2e7fb716c14bcc35f52a4200cbf0e7e6e88c97e31e15d572e`.
Size: 444064 bytes. It contains no account credentials, device identifiers,
provisioning profiles or personal scores. Corresponding Fairway source is
available at that commit in this repository under its existing license.

Keeping this small fixture allows the actual application signing regression
test to run after CI artifact retention expires, without rebuilding Fairway.
The test signs only a temporary extracted copy with a temporary test identity.
Its synthetic profiles do not authorize installation on any physical device.
