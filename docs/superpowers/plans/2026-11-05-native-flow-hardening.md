# Native Flow Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or executing-plans to implement this plan task-by-task. Root owns the serialized Flutter/Dart/native test and Git lanes; implementers edit disjoint files and wait for root RED evidence before production fixes.

**Goal:** Correct existing persistence/journey races and prove the free encrypted app's core flow in native runtimes across its five targets.

**Architecture:** VaultGate serializes storage operations. AppController distinguishes saved state from residual-cleanup warnings. SupportEvent supplies one shared stage-aware selector. A temporary-vault integration suite runs on the CI native hosts without enabling personal-data sources.

**Tech Stack:** Flutter 3.47.9, Dart 3.13.7, integration_test from the Flutter SDK, existing cryptography 2.9.0, GitHub Actions native toolchains.

**Spec:** docs/superpowers/specs/2026-11-05-native-flow-hardening-design.md

## Global Constraints

- App stays free, offline and usable with every learning source off.
- No real records, passwords, phone activity, permission grants, notifications, contacts, or locations enter tests.
- Tests own uniquely created temporary directories; never read production records or delete a path they did not create.
- Preserve pre-commit failure behavior and authenticated encryption/recovery guarantees.
- No OS file chooser or permission UI is automated; native tests cannot establish granted-permission, physical sensor or accessibility behavior.

## Review Focus

- Delayed/failed reset must not race unlock or leave an interactive stale form.
- Post-commit cleanup failure must not claim data was kept or invite duplicate saves.
- A previously raised cleanup warning must not disappear without confirmed cleanup.
- Late-added early-stage actions, completed events and empty action lists must produce consistent recommendations.
- Native test cleanup, platform selection and result reporting must not touch user data, swallow failures or pass without executing named tests.

### Task 1: Serialize vault reset and open

**Files:** lib/app/vault_gate.dart; test/widget/vault_gate_test.dart.

**Interfaces:** Preserve VaultGate(store:) and VaultUnlockScreen APIs. Reuse the existing DELETE confirmation. No test-only methods in production.

- [x] Add delayed/failing VaultStore.reset widget regressions that attempt unlock during deletion and verify recovery after failure.
- [x] Root runs the focused test and confirms meaningful RED before product edits.
- [x] Guard both directions of competing operations and repeated confirmations, show deletion progress, and clear state in finally; recheck actual files after errors.
- [x] Root runs focused GREEN and stages only task-owned files for review.

### Task 2: Report committed saves and cleanup accurately

**Files:** lib/app/app_controller.dart; lib/app/steady_through_app.dart; lib/features/settings/settings_screen.dart; lib/features/insights/insights_screen.dart; test/app/learning_retention_test.dart; focused new app/widget warning tests as needed.

**Interfaces:** Add `String? get cleanupWarning`. Mutation futures complete successfully after a successful save even when residual cleanup fails. Pre-commit errors still throw. Only confirmed cleanup clears the warning. Existing sources, storageWarning and onLock interfaces remain.

- [x] Add regressions for import and event save that commit before cleanup fails; assert new records, successful result and visible warning. Pin pre-commit failure and retry behavior.
- [x] Root confirms RED; implement warning state and truthful import/clear feedback, including the global app banner.
- [x] Update the old residual-failure regression to the new explicit committed-with-warning contract; do not weaken unchanged-data assertions for genuine save failures.
- [x] Run focused GREEN and review failure copy at narrow/large text using existing UI checks.

### Task 3: Recommend actions in stage order

**Files:** lib/model/app_data.dart; lib/features/home/home_screen.dart; lib/features/journey/journey_screen.dart; test/model/app_data_test.dart; focused journey/Home widget regression.

**Interfaces:** `PlanAction? get SupportEvent.nextPendingAction`. It uses JourneyStage.values order and stored order within each stage; null when nothing remains or the event is completed even with unfinished actions.

- [x] Write tests for late-added Orient action after its original is done, stable same-stage order and completed/empty events; show the same recommended stage in Home and Path.
- [x] Root observes RED; add shared selector and use it in both screens.
- [x] Root runs model/widget GREEN, then task review.

### Task 4: Native runtime suite and CI

**Files:** pubspec.yaml/lock; integration_test/native_smoke_test.dart and test-owned helpers if needed; .github/workflows/verify.yml; small CI simulator/report helpers under tool/ if justified.

**Interfaces:** Use the real VaultGate/VaultStore in owned temporary directories. Supported native channel is `steady_through/device_signals`; directly assert its registration without requesting permissions. Windows/Linux verify the supported wrapper fallback. Use `flutter test integration_test/native_smoke_test.dart -d <target> --reporter expanded --file-reporter json:build/native-<platform>-results.json --timeout 5m`.

- [x] Add SDK dev dependency and a small shared native suite covering real encrypted setup, persisted event, lock/wrong/correct unlock, sources off, encrypted portability and paused native bridge.
- [x] Preserve existing unit/widget coverage; no production dependency injection solely for tests.
- [x] Add runtime checks to native CI jobs: Android emulator with pinned action/KVM; available iPhone simulator chosen from simctl JSON; macOS/Windows direct; Linux xvfb-run. Keep release build artifacts intact.
- [x] Retain JSON/log evidence on success and failure and require actual named tests with zero failures; root fixes concrete runtime failures before calling any host validated.

### Task 5: Review, verification and public update

**Files:** README.md; PRIVACY.md; CONTRIBUTING.md; docs/quality-status.md; plan checkboxes.

- [x] Run formatting, static analysis, full local suite, targeted task checks and current five-platform CI/native runtime gates; inspect every result.
- [x] Obtain fresh source review of the whole branch, resolve material findings with regression evidence, and verify app-code equality for any later documentation-only commit.
- [ ] Update quality evidence and limitations, publish the next patch preview and verify remote source/assets/checksums. User publication authorization persists from the original request.
