# Quality status

_Private-learning revision in progress: November 5, 2026_

Steady Through is a development preview. The current revision adds a passphrase-protected encrypted local vault, independently encrypted `.steady` exports, explicit learning-source consent, personal pattern comparisons and native aggregate adapters. Its verification record is being refreshed. Earlier build/test results do not establish that these new paths or native sources are verified.

## Current verification record

| Area | Status for this private-learning revision |
| --- | --- |
| Formatter and static analysis | `dart format lib test tool/capture_learning_ui_test.dart` completed; `flutter analyze --no-pub` reported no issues on the current Dart source. |
| Full automated suite | `flutter test --no-pub` passed **195 tests**, including the full vault/KDF/recovery suite, Unicode validation, import-safe consent, live interaction boundaries and fresh motion checks. The separate capture harness passed five additional render checks. |
| Vault security and recovery | Authenticated encryption, tampering/passphrase failure, fresh nonces, migration/cleanup, interrupted-save recovery and encrypted portability have automated regression coverage. Independent source review found no remaining material issues in the reviewed vault, lifecycle and retention boundaries after fixes; final suite record below applies. |
| Consent, lifecycle and inference | The 195-test suite covers optional sources, unavailable readings, explicit labels, persistent pause, uncertain evidence, vehicle suppression, chronological review, bounded retention and cleanup. Material source-review findings were fixed; native collector compilation and Android unit verification remain pending below. |
| Android build | Current native adapter compilation and 12 Kotlin motion-state unit tests pending CI. Device Usage Access and Activity Recognition behavior are not physically validated. |
| iOS build | Current Core Motion adapter compilation result pending. Simulator compilation cannot validate motion hardware, change-only updates or permission dialogs. |
| macOS build | Current NSWorkspace adapter compilation result pending. Actual activation counts, session suspension and permission/lifecycle behavior need a native walkthrough. |
| Windows and Linux builds | Current revision build results pending. System usage/motion adapters are intentionally unsupported. |
| Current vault/Insights captures | `flutter test --no-pub --update-goldens tool/capture_learning_ui_test.dart` passed five captures. All five PNGs were visually inspected: vault mobile, Insights mobile/desktop/dark, and source controls mobile. Bundled fonts and fictional examples; no passphrase, KDF, OS grant or personal data used. |

Before this revision is reported as verified, replace these pending entries with exact commands, counts, target/runtime details and any failure or unavailable toolchain. A successful five-platform CI run is still a compilation check, not physical-source or medical validation.

## What is implemented, and what remains limited

- The whole app stays free. Planning, tools, people and help remain available with every learning source off and every OS permission declined. Manual and in-app learning sources have no device-permission requirement on any of the five target platforms.
- Saved app data/settings and learning records use an authenticated encrypted vault; new exports are independently encrypted `.steady` documents. Legacy JSON is still accepted after validation and replacement confirmation. Migration removes known plaintext files only after authenticated encrypted read-back, and must surface cleanup failures. Source JSON files, exports and OS backups outside known app paths remain under their owner's control.
- macOS implements foreground collector-session activation counts and screen-awake session minutes; these do not measure attention. Its observer stops when the app loses focus, so it cannot observe switching among other apps and the count may stay zero. Android implements aggregates from the last 60 minutes of UsageStats events and optional session-only Play services Activity Recognition. iOS implements optional Core Motion summaries; history may be delayed, and cross-app usage is unavailable without the Family Controls entitlement and Screen Time extensions. Windows/Linux system usage and motion remain unavailable. None of these statements establish hardware validation.
- Core Motion's current classification is change-driven, not a periodic heartbeat. A known vehicle context must remain active until a new known classification or stop; unknown readings cannot establish that movement ended. Possible vehicle movement is uncertain and does not identify a driver or passenger. Interactive reflection prompts are suppressed in this context, with help still available.
- The personal model uses explicit labels and comparable aggregates. It needs at least 20 eligible examples across seven observation days, at least five examples of each of two concrete labels and two comparable features before a tentative match is possible. Insufficient, contradictory or shifted evidence remains insufficient/uncertain. Manual-only labels can describe a self-reported trend. This is not a clinical instrument or an established emotion-accuracy result.
- A review after about 60 days trains only on earlier examples and evaluates on later held-out examples and a majority-label baseline. Coverage and improvement checks must pass before adoption; otherwise the revision stays. Learning is bounded to 180 days/1,000 examples. Time elapsed does not guarantee improvement.
- Readable records and a derived key exist during unlock. Lock closes the owned key object, but runtime/OS memory erasure and protection of an already compromised unlocked endpoint are outside the guarantee. Returning after five minutes away requires unlock; this does not claim a background timer erased a suspended process's key. There is no recovery server for a forgotten passphrase.

## Earlier design-refresh evidence

The prior interface refresh recorded large-text/long-entry layout checks at 320 and 1200 logical pixels, light/dark secondary-text contrast checks and visual inspection of synthetic Home, Path, Tools, game, Check-ins, People and Settings captures. Its independent review led to a contrast regression fix. Those results predate the vault and Insights screens and are not evidence for their current accessibility, security or layouts. Current test counts belong in the table above once the final run completes.

## Still required before a general store release

- Run complete flows on physical iOS and Android devices: vault setup/unlock/lock, wrong passphrase, migration/cleanup warnings, encrypted export/import, file dialogs, phone/SMS handoff, background/resume, interrupted writes, rotation, keyboard and accessibility settings.
- Validate supported sources using real permission grants, denial/revocation, no-data/unsupported states, session stop and late callbacks. Exercise Android with and without usable Google Play services; verify UsageStats observation-window limits. Validate Core Motion's change-only vehicle state over a sustained session and after suspension, and confirm that unknown movement is not treated as emotional evidence.
- Walk through macOS activation/session duration and stop-on-lock/background behavior. Perform Windows and Linux native usability checks in addition to current compilation.
- Review crypto/recovery/deletion boundaries and inference wording independently, resolving material findings and rerunning affected checks. Inspect current vault and Insights captures in light/dark, reduced-motion, narrow and 200% text configurations.
- Perform VoiceOver, TalkBack and keyboard-only walkthroughs on the native apps, including source controls, owner/OS permission dialogs, unavailable readings, errors and safe vehicle-context behavior.
- Observe people using the guidance, including caregivers/helpers and older adults, and revise unclear steps. Automated tests do not establish whether the guidance is understandable for every age or that it improves health outcomes.
- Configure distribution signing, Apple notarization and store records, then test signed packages through their distribution channels. CI artifacts are not store approval, notarized distribution or a signed release guarantee.

The [README](../README.md), [privacy details](../PRIVACY.md) and [contribution guidance](../CONTRIBUTING.md) describe the intended behavior and review boundaries. Any discrepancy with current code or observed runtime behavior is a defect to resolve, not a reason to claim broader validation.
