# Contributing to Steady Through

Thank you for helping make Steady Through clearer and more reliable. Keep changes small enough to review and explain the behavior they change.

## Development checks

Use Flutter **3.47.9** and the native toolchain for the platform you are testing. From the repository root:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Build on the relevant host with the commands in [README.md](README.md). The GitHub Actions workflow is configured to compile all five platform targets; its artifacts are development outputs, not signed store releases. Check the actual run for the revision being reviewed. Note the exact platform and whether you ran on a device, simulator, or only compiled. Do not mark a native source validated on a device based on a successful build, mocked platform channel or previous release alone. Record current evidence and remaining gaps in [quality status](docs/quality-status.md).

## Changes that need particular care

- Keep the whole app free and usable offline without accounts, analytics, advertising, cloud emotion services or personal-data transmission. Every learning source starts off. Device permissions must stay optional; planning, tools, people and help remain available if all sources or permissions are declined. Do not add permissions or data collection without explaining the need and updating [PRIVACY.md](PRIVACY.md).
- Treat game moves as observable actions within a game. Do not claim they measure stress, diagnose a condition, or support a clinical score. Ask the player how a round felt before tailoring a suggestion. Avoid saving raw tap traces.
- Keep Help now reachable during tools and game play. Label 988 as a U.S. option and direct people elsewhere to local services. Keep Stop visible on exercises and Skip visible in grounding. Do not require breath holding, closed eyes, or rapid/deep breathing.
- Preserve import safety: authenticate encrypted `.steady` files or validate complete legacy JSON before asking to replace local data. Invalid, unauthenticated or cancelled imports must leave existing data untouched. New exports are encrypted and use their own chosen passphrase. Confirm full replacement, vault reset, delete-all, learning clearing and game-history clearing.
- Test large text, screen readers, keyboard focus, narrow layouts, light/dark appearance, and phone/SMS fallback where the platform has no handler. [W3C mobile accessibility guidance](https://www.w3.org/TR/wcag2mobile-22/) is a useful review reference.
- Use original copy and cite authoritative sources for health, crisis, privacy, or platform claims. The [WHO stress guide](https://www.who.int/thailand/activities/doing-what-matters-in-times-of-stress), [NIMH help guidance](https://www.nimh.nih.gov/health/publications/my-mental-health-do-i-need-help), and [988 Lifeline](https://988lifeline.org/get-help/) inform the current content; they do not endorse this app.

## Vault and consent boundaries

All durable app records and settings belong in the authenticated encrypted vault, including recovery/staging copies, learning labels and calibration parameters. Use the existing AES-256-GCM codec and bounded envelope parsing. Keep random salts, fresh per-save nonces, authenticated format metadata and the PBKDF2-HMAC-SHA256 work factor intact. Derive keys outside the UI isolate. Never add a plaintext fallback, save a passphrase, silently reset a damaged vault or log decrypted records. Closing a key object is not proof that every runtime or OS memory copy was erased.

Tests for storage changes should expose wrong-passphrase and tampering failures, independent export passphrases, nonce changes, interrupted saves, authenticated recovery, permission/storage errors and bounded untrusted metadata. Legacy migration must authenticate and read back its encrypted document before removing known plaintext primary/backup/temporary files. A failed cleanup needs a visible, retryable warning; authentication failure must preserve files. Successful Clear learning must remove its active and known local recovery data and reset source choices while preserving other records. Cleanup failure must not claim that every copy was removed. Exports and OS backups are outside app deletion controls.

Keep in-app consent separate from OS permission and support detection. Enabling a system source requires device-owner confirmation, with any system grant requested only by a separate explicit action. A supported source without a grant is missing evidence. An enabled source that becomes unsupported must still be individually revocable. Turning off a source, user pause, backgrounding or locking must stop its collector and invalidate late callbacks/readings. An unlock finishing in the background must not uncover records or start collectors. Resume must preserve a user's deliberate pause.

Only whitelisted aggregate counts, durations and uncertain vehicle context cross a native channel. Never send or persist app/package names, window titles, typed content, screenshots, raw key/touch traces, location or routes. Android may use package identifiers transiently to deduplicate UsageStats events; those identifiers must remain inside the native function. Use exact event windows rather than treating an expanded daily UsageStats bucket as the last hour. Preserve null for unsupported, denied, invalid and absent readings. Windows/Linux system sources and iOS cross-app usage remain unavailable until separately implemented and verified; do not bypass Apple's entitlement or extension requirements.

Possible vehicle movement suppresses interactive reflection prompts across Insights and other learning feedback; help stays available. It cannot establish who is driving. Follow each API's update contract: [Core Motion updates](https://developer.apple.com/documentation/coremotion/cmmotionactivitymanager/startactivityupdates(to:withhandler:)) are delivered on classification changes, so an arbitrary heartbeat timeout cannot establish that a known vehicle state ended. Unknown readings must not create a diagnosis, score or reassuring claim. Stop/unsubscribe, permission revocation, backgrounding and late callback races need native/device review as well as Dart tests.

## Personal model review

Train and evaluate only on explicit labels and consented, bounded aggregate features. Manual-only input can support a self-reported trend without a predictive claim. Personal matching currently needs 20 eligible examples over seven distinct UTC observation days, at least five examples of each of two concrete labels and at least two comparable features. Unsure does not become a concrete training class. Test missing data, one-class and sparse histories, overlap/contradiction, changed recent patterns, disabled features and corrections before changing these gates.

The 60-day calibration uses an earlier training set and a later held-out set with no shared observation day. Current coverage gates include at least 30 training examples over 14 observation days and at least 12 later examples over seven observation days, with class and comparable-feature coverage on both sides. A candidate must improve on the majority-label baseline and any incumbent before adoption. Keep the chronological split and coverage checks independent of candidate selection. Internal label-agreement checks do not justify publishing a clinical or real-world accuracy claim. Preserve the current revision if evidence or improvement is insufficient, and show the reason.

Retain at most 180 days or 1,000 learning examples, whichever limit is reached first. Enforce retention at storage/read boundaries and when labelling/reviewing, and keep old/future observations from creating a current confident match. Review all inference wording independently before publishing a preview. Follow the [private-learning specification](docs/superpowers/specs/2026-11-05-private-learning.md), while verifying it against the final code and actual platform behavior.

## Pull requests and issues

Include a short description, the reason for the change, commands run and their results, and any platform limitation. Add focused tests for behavior changes. Never commit signing credentials, tokens, passphrases, real user records, vault/recovery files, `.steady` or JSON exports, or private contact information. Use fictional sample data in issues, captures and tests. For a security or privacy concern, describe a minimal reproduction without exposing someone's data. Do not publish a preview until its current security/inference review and required native build checks have been recorded; physical source and accessibility validation remain separate evidence.

Contributions are licensed under the [MIT License](LICENSE).
