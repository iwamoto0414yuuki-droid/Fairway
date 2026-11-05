# Fairway Refresh failure: repeated App Group team suffix

## Confirmed evidence

The device-owner's console log shows `Failed to create new App Group` followed by `group.local.fairway.score` with the same current team identifier repeated many times. Anisette retrieval succeeded in the same attempt. The diagnostic result was `FWDIAG_PHONE_PROFILE`; the Watch transfer had not started.

## Source cause and scope

Pinned `FetchProvisioningProfilesOperation.adjustedGroupIdentifier` unconditionally returns `groupIdentifier + "." + team.identifier` on its normal path. Refresh uses already signed app entitlements, so repeated signing can append the suffix repeatedly. Apple rejected creation of the accumulated group; the precise server rejection reason (for example length or another constraint) is not exposed by error -1.

## Repair

`tools/watch-support/apply_group_refresh_fix.py` adds an idempotent group transformation. It preserves existing suffixes for general applications. For the exact Fairway group base and repeated current-team suffixes, it collapses the sequence to a single suffix. It changes neither host bundle ID nor team and does not delete apps or revoke certificates.

Fairway `Shared/Store.swift` stores rounds in its Application Support directory (`rounds-v1.json`), not an App Group container. This supports preserving score data during an in-place update, subject to physical verification.

The added Swift test covers initial signing, repair of 14 repeated suffixes, 30 repeated refresh transformations, and preservation of another app's existing group ID. Existing Watch install code is retained.

Build: https://github.com/iwamoto0414yuuki-droid/Fairway/actions/runs/42030957798
Commit: cc13860 (build branch fairway-watch-direct-ci-20261104).

## Physical gate

Install repaired SideStore over existing SideStore, then Refresh Fairway once. Check scores and launch on both devices. Repeat Refresh to verify recurrence is fixed. Automatic execution and profile-expiry survival remain separate unverified checks. Do not delete Fairway or switch accounts as part of this repair.
