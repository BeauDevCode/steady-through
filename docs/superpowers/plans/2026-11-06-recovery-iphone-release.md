# Recovery Help and iPhone Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Root owns Git and all Flutter/Dart/native commands; workers edit scoped files, write tests first and wait for root RED before behavior edits. Steps use checkbox syntax.

**Goal:** Provide constructive forgotten-passphrase help and a verified unsigned iPhoneOS Release compilation alongside the existing five tested platforms.

**Architecture:** A vault-unlock dialog delegates destructive continuation to the unchanged gate reset owner. A portable Mach-O parser and bundle/archive validator gate a fresh device-only CI build; release evidence keeps compilation, native runtime and signing separate.

**Tech Stack:** Flutter3.47.9 / Dart3.13.7, stdlib Python, existing SwiftPM project and Xcode26.5 CI. No app dependency or schema change.

**Spec:** docs/superpowers/specs/2026-11-06-recovery-iphone-release-design.md

## Global Constraints

- All support remains free/offline with every learning source off; no new permissions, account, data collection or age inference.
- Recovery help never reads/decrypts/replaces records, discovers backups or invokes reset on opening/dismissal. Only explicit Start over… delegates to unchanged typed-DELETE confirmation and reset/open serialization.
- No forgotten-key recovery promise; export passphrase is separate, and a usable backup must be checked before discarding a locked vault.
- iPhone artifact is unsigned, not installable and not physically validated. No credentials, signing identity, provisioning, payments or license/account acceptance.
- Device targeting requires every Mach-O slice to declare platform2/iOS, not arm64 alone; preserve Simulator/runtime checks independently.
- Version1.2.1+6, schema3/envelope unchanged; production lib/main.dart and archive-before-integration ordering remain.
- Fictional owned fixtures only; native three exact names/assertions/source-off behavior preserved. Root serializes Git/Flutter/Dart/native work.

## Review Focus

- Help opened during failed unlock, dismissal/back and Start over cancellation preserve the vault and input; no unexpected reset invocation.
- Large text and keyboard leave safe dismissal and destructive continuation reachable, with no help-dialog resize animation trap.
- Device-looking plist plus arm64 Simulator binary must reject; every fat slice and embedded image matters.
- Static SwiftPM plugins and FFI mappings must be validated from actual generated resources rather than assumed dynamic frameworks.
- Package paths, bytes, source/version and unsigned labels must survive archiving and publication without fixture/stale-artifact substitution.

### Task 1: Non-destructive forgotten-passphrase help

**Files:** modify lib/features/vault/vault_unlock_screen.dart; existing test/widget/vault_unlock_test.dart and vault_gate_test.dart; create tool/capture_recovery_ui_test.dart. New focused recovery helper widget file allowed if it keeps screen responsibility clear, with exact path recorded before edits.

**Interface:** retain VaultUnlockScreen constructor/onReset Future<void> callback. Link label `Forgot your passphrase?`; dialog `Help with your passphrase`; safe primary `Back to unlock` default focus; `Start over…` returns an explicit continuation before invoking onReset. No extra fields, no Gate/store/codec/controller behavior changes. Exact explanatory meaning is in spec; use short original copy.

- [x] Add tests driving actual visible controls: help opens without reset/deletion; back/escape/cancel keeps input/data; Start over opens existing DELETE guard; incorrect confirmation and Keep vault preserve; pending unlock disables help; narrow200% keyboard/semantics. Root confirms missing/new behavior RED.
- [x] Implement scrollable help and deliberate continuation, preserving existing gate/reset tests by updating their navigation through help rather than weakening assertions.
- [x] Capture locked/help light/dark and320px200% plus desktop using empty synthetic fields; root inspects images and runs focused/full/analyze. Task review, fixes and commit.

### Task 2: Strict iPhoneOS Release build and archive gate

**Files:** create tool/ci/apple_macho.py, tool/ci/verify_ios_device_bundle.py and their test_*.py files; modify .github/workflows/verify.yml only by adding independent ios_device_release job and required evidence. No existing platform command changes.

**Interfaces:** frozen MachOSlice records from `read_macho(data: bytes) -> list[MachOSlice]`, carrying cputype/subtype, filetype, platform, minimum_os and sdk. `validate_bundle(app: Path, *, expected_version: str, expected_build: str) -> dict`; `verify_archive(archive: Path, report: dict) -> dict`. CLI `python tool/ci/verify_ios_device_bundle.py APP --pubspec pubspec.yaml --report REPORT [--archive ZIP]` derives exact version/build, fails nonzero and emits JSON only after validation. Main required constants, exact report schema and CLI prior-report behavior are in spec. Main minimum iOS15.0; embedded image minimums may be older but not newer. Reject extras as well as missing ZIP members; no Mac-only metadata. Exact pinned privacy and native-assets paths/shapes are in the spec, observed in the existing CI bundle and SDK. Confirm/freeze against first device build. Allow extra architecture metadata keys (including ios_x64) without treating them as binary architecture; require all actual images platform2/arm64. The objective_c framework plist lacks platform fields; inspect its binary.

- [x] Write portable semantic fixtures for valid device, arm64 Simulator with device plist, mixed fat platforms, x86, malformed headers/commands/ranges, wrong main identity/version, missing framework/asset/privacy/native mapping, unsafe paths/symlinks/archive duplicates and fixture markers. Root observes initial missing behavior, then focused negative/positive gates before implementation completion.
- [x] Implement bounded parser and directory/archive validation with all-file hashes, explicit unsigned/physical-not-run reports. No subprocess native tools in portable validator/tests.
- [x] Add fresh ios_device_release job: pinned macos26/Xcode26.5/Flutter3.47.9, `flutter build ios --release --no-codesign --target lib/main.dart`, bounded30m; validate directory, ditto full Runner.app, validate archive, upload `ios-device-release-unsigned-not-installable` and separate always-preserved logs/report/source/toolchain evidence. Retain six existing jobs.
- [x] Root runs helper tests, actual Simulator rejection and real unsigned device build/validation locally or CI. Task review, fixes and commit.

### Task 3: Verified 1.2.1 preview and distribution handoff

**Files:** pubspec.yaml version1.2.1+6; README/CONTRIBUTING/PRIVACY only where changed behavior matters; docs/quality-status.md, docs/device-validation.md, new docs/ios-distribution.md, recovery screenshots and plan checkboxes.

**Interface:** archive name `steady-through-1.2.1-preview.1-ios-device-release-unsigned.zip`, unchanged five existing package naming shapes for1.2.1, ten release assets total (six app packages + BUILD-INFO, SHA256SUMS, Android JUnit, native/device report bundle). Signing guide distinguishes current unsigned app ZIP, a separately generated signed Xcode archive/IPA and Simulator package; no fabricated TeamID/profile, credentials or store submission.

- [ ] Update version/docs with current source and accurate pending gates. Root formatter/analyzer/full Flutter/helpers and scoped task review, then one whole-branch review; resolve material findings with evidence.
- [ ] Run all seven jobs at final intended source; inspect three actual native cases on each original target, Android12JUnit, new device parser/report/archive/platform metadata and all versions/hashes. Signing and physical execution remain separate.
- [ ] Publish v1.2.1-preview.1 under existing authorization; verify publicmain/tag/tenasset serverhashes and anonymous access. Update evidence only after observation. Finish clean checkout and preserve physical/signing prerequisites concretely.
