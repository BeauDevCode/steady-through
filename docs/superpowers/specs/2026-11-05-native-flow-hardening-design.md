# Native flow validation and journey hardening

The user asked to continue building the complete, free, private life-event app and has delegated routine design and implementation choices. This pass makes existing flows reliable and adds native runtime evidence before expanding the product.

## Approach and scope

Use Flutter's SDK integration-test package on the existing GitHub Actions hosts: Android emulator, iOS Simulator, macOS, Windows, and Linux under Xvfb. This is the builder's choice. Manual local walkthroughs remain useful but the computer-use capture service failed, and installing full native SDKs locally adds setup without giving five-platform coverage. Existing unit/widget tests remain the fast regression gate; they cannot establish installed-app or native-channel behavior alone.

The app remains Flutter 3.47.9, offline, free, passphrase encrypted, and usable with every source off. No real records, passwords, phone activity, permission grants, notifications, contacts, or locations enter these tests. No production data directory is opened for records. A test may ask path_provider for a path to verify registration, but stores all fixtures in a uniquely created temporary directory and deletes only that owned directory after unmount/cleanup.

## Required behavior

1. Vault reset and open are mutually exclusive. Confirmation still requires DELETE. While deletion is pending, the unlock form is unavailable and clear progress is visible. Failures retain recovery choices and release the busy state. A delayed reset regression must prove that unlock never starts during deletion.
2. A successful repository save is reported as saved even if deletion of older recovery copies fails afterward. Pre-commit save/validation failures still reject and keep active records unchanged. Expose `AppController.cleanupWarning` until cleanup is confirmed; display it globally and in destructive/import success feedback. The warning must explain that older local copies may remain and how to retry. Never imply that all copies were removed. No subsequent form retry should create a duplicate event after an already committed save.
3. `SupportEvent.nextPendingAction` returns the first unfinished action in `JourneyStage.values` order, preserving stored order within a stage. Home and Path use this same selector. Empty events, events with no remaining action, and events whose completedAt is set return null. Adding an early-stage action after defaults must correctly return the person to that stage.
4. A shared native suite exercises real VaultGate, VaultStore, encryption/KDF/isolate, filesystem persistence, event creation and lock/wrong-unlock/correct-unlock. It verifies offline use with sources off, a separately encrypted portability round-trip without operating a system file chooser, and native bridge registration/paused readings on supported hosts. Windows/Linux intentionally use the unsupported bridge fallback. Do not request OS permissions or assume any sensor exists.
5. Every native runtime result is retained as JSON with bounded timeouts. CI must fail on a test failure and preserve failure evidence. Existing five production-target builds and Android Kotlin regressions continue passing. Signed distribution and real permission/motion/accessibility checks remain outside this evidence.

## Presentation and release

Reuse the existing sage/forest theme and reduced-motion rules. Warnings wrap at narrow widths and enlarged text. Update README, privacy/contribution guidance and quality status with exact commands, counts, CI source and limits. Publish the next preview only after review, automated gates and available native runtime checks pass. Keep physical-device and signing gaps explicit; simulator/emulator/desktop automation does not establish health outcomes or real motion accuracy.
