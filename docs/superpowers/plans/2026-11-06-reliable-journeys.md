# Reliable Journeys Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the audited save/learning/deletion defects and verify a complete rendered native support journey before the next public update.

**Architecture:** Queue-time learning transformers and observation ownership guards, explicit residual cleanup, stable submitted form controls, and one additional required native UI case. Retain existing storage, routes and source adapters.

**Tech Stack:** Existing Flutter/Dart/Material/flutter_test/integration_test, Python native-report helpers; no new dependencies.

**Spec:** `docs/superpowers/specs/2026-11-06-reliable-journeys-design.md`

## Global Constraints

- Target1.5.1+10/v1.5.1-preview.1; schema4/read1/2/3/4, crypto/KDF/dependencies/permissions/adapters/learning thresholds unchanged.
- Free/offline/all-sources-off core. Fictional memory or exclusively owned temp vault fixtures only; no real contacts, clipboard, grants, OS choosers or personal support path.
- Root owns SDK/Git/network/release coordination and serial tests; disjoint workers may write specified files after root observes RED. One fresh whole-branch review on the most capable model and one material RED/GREEN fix pass; no duplicate review loop.
- Native required names: retain original3 plus `native support flow preserves focused step and people after reopening`; all4 required on each5runtimes. Preserve strict missing/renamed/hidden/skipped/failed/duplicate/late-error/unfinished rejection.
- Existing7CIjobs/13artifacttypes/6packages/10publicassets and all exact-source/latest-attempt/hash/metadata/device/public-body/main/anonymous gates remain.

## Review Focus

- A queued learning control must preserve evidence committed ahead of it; clear/import/lifecycle boundaries must not restore old evidence, consent or observation snapshots.
- Two ordinary queued source choices must both apply in order; feeling receipt identity and exact-instance Undo must survive concurrent operations.
- Deleted event/check-in/game/import-only records must not remain in known recovery copies without attempted cleanup and an accurate committed-save warning.
- Pending forms must not accept corrections that silently disappear; failure restores input/choices and Help clipboard failure must not show false or late success.
- Native UI evidence must use default real screens, visible mutations and fresh encrypted disk reopen, with honest scope and production archives free of the new fixture.

---

### Task 1: Queue-safe learning and complete residual cleanup

**Files:** modify `lib/app/app_controller.dart`, `lib/learning/learning_session.dart`; create `test/app/reliable_learning_test.dart`, `test/data/reliable_cleanup_test.dart`; migrate updateLearning fixture callers in `test/data/data_portability_test.dart`, `test/widget/insights_test.dart`, `test/app/learning_history_test.dart`, `test/widget/saved_moments_test.dart`.
**Interfaces:** `updateLearning(LearningData Function(LearningData current) change,{int? expectedRevision,bool Function()? isActive})`; optional expectedRevision/isActive named params on `recordLearning(FeelingLabel,SignalSnapshot,...)`. Default revision captured at invocation; guard inside queue. Session controls patch current fields, copy source input, use closed/revision ownership. Session observation captures generation+revision before motion await and requires unchanged ownership/current active conditions inside queued save. Canonical receipt captured from recorded/reviewed examples inside mutation. Explicit purge for deleteEvent/deleteCheckIn/clearGameRounds/replaceData.

- [x] Write behavior regressions using existing public APIs: delayed feeling→Pause/source preserves moment; Clear→source preserves empty evidence/model/review; import/ClearAll rejects old controls/feelings; motion barrier across clear/re-enable or suspend/activate rejects old observation; two queued source choices remain ordered; caller source-set mutation cannot alter queued intent; canonical committed receipt/Undo survives queued clear; primary save failure preserves state. Run `flutter test test/app/reliable_learning_test.dart --reporter expanded` before production changes. Expected: named behavioral failures from lost/stale data, not harness errors.
- [x] Write cleanup regressions for event+associated check-ins, single check-in, game clear and event-only replacement with empty learning/ratings; assert actual purge invocation, committed warning on purge failure, no purge after primary failure. Real encrypted temp vault verifies .bak absence after success and active-data preservation. Run `flutter test test/data/reliable_cleanup_test.dart --reporter expanded`. Expected: failures for missing cleanup.
- [x] Implement queued transformer/guards/receipt and explicit cleanup; migrate4 fixture callers. Run both new files plus existing learning/history/retention/cleanup/portability tests. Expected: PASS. Run full Flutter suite on final Task1 state; commit guarded data changes and ledger actual RED/GREEN/full results.

### Task 2: Stable submitted forms and Help clipboard failure

**Files:** modify `lib/features/vault/vault_unlock_screen.dart`, `lib/features/vault/passphrase_dialog.dart`, `lib/features/journey/event_form.dart`, `lib/features/journey/journey_screen.dart`, `lib/features/check_ins/check_ins_screen.dart`, `lib/features/help/help_screen.dart`; create `test/widget/submitted_forms_test.dart`, `test/widget/help_clipboard_test.dart`, `test/widget/form_label_layout_test.dart`; create `tool/capture_reliable_forms_ui_test.dart` and `docs/screenshots/reliable-journeys/` captures.
**Interfaces:** wrapped fields keep stable keys `vault-confirmation-field` and `event-description-field` with full semantic labels; Task3/capture field finders use those keys. Existing constructors/callbacks remain compatible; set text fields readOnly while existing busy/saving flag; disable event guide/starter controls and check-in intensity changes while saving, restore after failure. Keep current Back/Cancel semantics. Help Copy catches channel failure and uses mounted/current-route/foreground ownership to suppress late feedback; no real external action.

- [x] Write deferred real-widget regressions for vault create/unlock, event create/edit, action add/edit and check-in text/intensity/guide choices while pending. Assert submitted input cannot accept typing/changes, primary failure restores editable controls and corrected retry, and success persists submitted values exactly once. Run `flutter test test/widget/submitted_forms_test.dart --reporter expanded`. Expected: existing busy forms incorrectly keep editable clients/choices.
- [x] Write Help clipboard failure and late-completion route cases with controlled method-channel responses. Run `flutter test test/widget/help_clipboard_test.dart --reporter expanded`. Expected: clipboard exception/no feedback; no real clipboard/action.
- [x] Implement minimal control/failure fixes; root integrates Help, worker owns form files. Run new files and existing vault/event/journey/check-in/layout/tool/Help tests. Expected: PASS. Capture changed form/failure states at mobile light, desktop dark and320px/Simple200%/reduced motion, inspect actual widgets. Full integrated suite then commit and ledger.

### Task 3: Required rendered native journey

**Files:** modify `integration_test/native_smoke_test.dart`, `tool/ci/verify_native_results.py`, `tool/ci/test_verify_native_results.py`, `tool/ci/verify_ios_device_bundle.py`, `tool/ci/test_verify_ios_device_bundle.py` as required; use existing workflow jobs unchanged unless observed evidence requires a justified adjustment.
**Interfaces:** add exact fourth case above; same verifier CLI with dynamic successful required-count output4; hidden loading/teardown fixture positions derive from list length. Add case name and sentinel `Fictional native support journey` to production fixture exclusions. No new production test seam or path selection.

- [x] Add Python report fixtures requiring the fourth visible successful named case, including absent/hidden/skipped/failed rejection, while preserving original gates. Run `python3 -m unittest discover -s tool/ci -p 'test_*.py'`. Expected: missing fourth-case contract failures before verifier changes.
- [x] Implement verifier expected-name/fixture handling and production-fixture marker changes. Run all helper tests. Expected: PASS, exact observed count recorded.
- [x] Add fourth actual native case: default Gate/temp real vault → chosen caregiving guide/explicit starter set → focused Mark/Undo/Mark exact action → People Add/Edit/clear phone → Help/View all/return → lock/unmount → fresh Gate/store disk reopen → rendered event/action/person verification. All mutations through visible controls; assertions may inspect controller. Source/owner consent off; envelope/no sentinel plaintext; lock/unmount/owned cleanup; retain failed fixture. Existing3cases remain untouched in meaning.
- [x] Run native case on an available local safe target if feasible, or final exact-source five-runtime CI. Keep five-minute per-case and existing job budgets until observed failure justifies change. Native source-only addition is not a pass. Run full Flutter/analyzer/format/helpers before commit/review.

### Task 4: Completion review and verified public release

**Files:** pubspec.yaml, README.md, PRIVACY.md, docs quality/device/iOS records; new `docs/releases/1.5.1-decisions.md` and publication snapshot. Operational release helpers outside repository adapt1.5 to1.5.1+10 and4nativecases without weakening gates.

- [x] Set version1.5.1+10 and record current behavior/actual local results with CI/publication pending. Correct stale general device-guide version. Preserve historical1.5 records. Prepare release helpers for4nativecases, source-exported helpers/metadata and new fixture markers.
- [x] Fresh whole-branch review after final green source, using plan/spec/Review Focus and ledger rulings; re-grade findings, fix material issues in one RED/GREEN pass and green full suite; no re-review loop. Expected: no unresolved material findings.
- [x] Push final source and require all7jobs/latest-attemptPASS; read actual Flutter/Python totals,JUnit12 and required4cases each5runtimes. Download all13 artifacts via connector, verify full ZIP/payload/provenance/version/device data and stage10assets. Independent staged-byte audit before draft/upload/publication.
- [ ] Verify exact draft body/source and10uploaded server hashes/sizes/states, publish v1.5.1-preview.1 tag equal testedsource, verify anonymous repository/release/all10downloads. Update main with testedsource+documentation-only successors; verify rename-safe ancestry/path diff, exact public body/tag/assets and sourceCI stillsuccess. Cancel only redundant same-source tag-triggered run.
- [ ] Archive/hash-check/remove only this plan scratch, finish owned branch, commit durable verified snapshot, reverify final publicmain/source equivalence and clean local/remote state. Do not stop after review/tests. Owner signing/physical/native-AT/real-handler/efficacy tasks remain accurately separate.

## Observed completion evidence

Exact source `4c8206812a2a23ab238c2e523a2d7ab04d30a654` passed all seven jobs on attempt 1 in [CI run 42329671305](https://github.com/BeauDevCode/steady-through/actions/runs/42329671305): 468 Flutter tests, 94 helper tests, clean analysis, 12 Android JUnit cases, and four strict native cases on each of five runtimes. The independent staged-byte audit passed with limits and no findings/advisories: 13 artifact ZIPs, six production packages, ten assets, nine checksum lines, 34 report members and four arm64/platform-2 device images. The source review found one P2; two regressions failed before the fix and all three including a primary-failure baseline passed afterward. No unresolved material finding or deferred minor remains.

The public preview tag and ten server hashes/sizes/states match the tested source and staged files. All twelve anonymous endpoints returned HTTP 200. Main-branch equivalence and the durable publication snapshot are the remaining integration records. The owner selected iPhone source and Simulator delivery; unsigned device compilation does not establish installation, physical sensing, native assistive technology, real handlers or clinical effectiveness.
