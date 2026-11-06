# Saved Moments Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let people inspect and repair private saved feelings and understand the evidence behind Insights.

**Architecture:** Retain schema 3 and the encrypted repository. Add current-state queued history mutations and session-owned exact-record undo; derive summary/diagnostics in the learning layer; compose focused history and evidence widgets into Insights.

**Tech Stack:** Existing Flutter/Dart, Material, flutter_test; no new dependencies.

**Spec:** `docs/superpowers/specs/2026-11-06-saved-moments-design.md`

## Global Constraints

- Keep schema version 3 and its JSON shape unchanged; versions 1/2/3 stay readable.
- Retention remains inclusive 180 days, at most 1,000 examples, deterministic ties.
- No cloud or new permissions/dependencies; free core features and optional sources remain.
- History mutations clear derived model/review artifacts, preserve existing review anchors while records remain, and never trigger adoption.
- Stored dates and snapshot fields are immutable under relabeling; display timestamps locally.
- No quota encouragement, inferred consent-at-save, diagnostic accuracy claim or emotion probability.
- Existing colors, typography, 48-pixel controls, 200% text, reduced motion and keyboard access.

## Review Focus

- An imported/replaced document or queued edit cannot leave Undo pointing to or deleting a different record.
- A correction's primary save can succeed while residual purge fails: show a committed change plus cleanup warning, not a duplicate-inviting retry.
- Retention removal must invalidate derived model artifacts, including when called by assessment rather than an explicit delete.
- Many labels with partial/missing features must not imply a comparison is ready; current blockers remain visible.
- Source-off and paused history access must work, while a detected vehicle context keeps interactive reflection/history controls suppressed.

---

### Task 1: Durable history mutations and exact-record undo

**Files:** Modify `lib/learning/learning_data.dart`, `lib/app/app_controller.dart`, `lib/learning/learning_session.dart`; test `test/learning/learning_history_test.dart`, `test/app/learning_history_test.dart`, `test/learning/learning_session_test.dart`.

**Interfaces:** Produces `LearningData.relabel(String id, FeelingLabel label)`, `LearningData.remove(String id)`, `Future<LearningExample> AppController.recordLearning(...)`, `Future<void> AppController.relabelLearningExample(String id, FeelingLabel label)`, `Future<void> AppController.deleteLearningExample(String id, {LearningExample? expected})`; session getter `LearningExample? undoableMoment`, methods `relabelMoment`, `deleteMoment`, `undoSavedFeeling`. Existing `saveFeeling` stays `Future<void>` and records the committed receipt.

- [ ] Write tests first: relabel retains exact ID/times/snapshot/other entries; same-label no-op; missing ID throws StateError; edit/remove/retention clear model/revision/results but preserve anchors and consent/pause; empty removes anchors. Controller tests assert durable state/reload, primary-save failure, residual purge/warning and queued unrelated writes. Session tests assert undo exact target, failed undo retry, stale queued edit protection, invalidation on clear/import/edit/prune/close and management with sources off/paused.
- [ ] Run targeted files and observe missing APIs or missing behavior (RED). Expected FAIL specifically for the new contract.
- [ ] Implement pure mutations, fresh calibration reset, save receipt and current-state queued controller actions. Pass purgeResidual for edits. Delete's optional expected receipt uses identity to reject an altered target. Session owns transient receipt, invalidates from controller notifications/replacement revision and rejects closed/background/vehicle management. Do not replace whole saved documents for undo.
- [ ] Run targeted tests, then `flutter test`. Expected all PASS.
- [ ] Commit task code/tests and record exact commands/results in the ledger.

### Task 2: Evidence diagnostics and personal seven-day summary

**Files:** Create `lib/learning/learning_summary.dart`; modify `lib/learning/pattern_engine.dart`; test `test/learning/learning_summary_test.dart`, `test/learning/pattern_engine_test.dart`.

**Interfaces:** Produces `LearningSummary.fromData(LearningData data, {DateTime? now})` with `recentCounts`, `recentCount` and newest-first `moments`; `PersonalPatternEngine.evidence(LearningData data, SignalSnapshot snapshot, {DateTime? now})` returns `LearningEvidence` with retained/eligible/day/class counts, `hasComparableHistory` from the existing training result, and the actual `PatternInsight` assessment. Source descriptions belong in presentation derived from actual snapshot keys.

- [ ] Write failing tests: rolling seven-day inclusive boundary, future/expired exclusions, Unsure preserved in summary but excluded from model eligibility, deterministic timestamp ties; UTC observation days; twenty same-day entries/one class and mixed incomplete features never imply comparable history; valid complete features do; revocation filters context; stale/future/current missing readings and vehicle keep actual assessment blocker.
- [ ] Run targeted files and observe expected missing APIs (RED).
- [ ] Implement bounded immutable summary and engine diagnostics using `_visibleExamples`, `_counts`, `_train`, `_day` and `assess`. Do not change existing thresholds/prediction or review rules.
- [ ] Run targeted tests, then `flutter test`. Expected all PASS.
- [ ] Commit task code/tests and ledger evidence.

### Task 3: Accessible history, correction dialogs and clearer Insights

**Files:** Create `lib/features/insights/saved_moments.dart`, `lib/features/insights/learning_details.dart`; modify `lib/features/insights/insights_screen.dart`; create `test/widget/saved_moments_test.dart`; extend `test/widget/insights_test.dart`; extend `tool/capture_learning_ui_test.dart`.

**Interfaces:** Consumes Tasks 1/2. `SavedMomentsCard(session: LearningSession, disabled: bool, onChanged: VoidCallback)` owns preview/full-history/detail/edit/delete flows with action feedback. `LearningDetails(session: LearningSession, working: bool, onReview: VoidCallback)` renders collapsed technical details and separate existing review behavior. Parent Insights owns save/Undo feedback and clears stale cached review results when history changes.

- [ ] Write failing widget tests for preview/latest3/full lazy list, exact source-summary/metric detail, local timestamps, explicit edit Save/Cancel, delete Cancel/Confirm, source-off/paused access, currently detected vehicle suppression, failure with intact data, one-record undo/retry, live-region success semantics and reduced-motion/narrow 320px/200% text dialog usability. Keep existing source/vehicle tests.
- [ ] Run targeted widget tests and observe missing feature behavior (RED).
- [ ] Implement focused widgets, recent self-report summary, preview/all-history, details with literal copy, edit/delete confirmations and persistent Undo. Keep errors in context, no timed undo, no red/green-only meaning. Move machinery into collapsed details, display actual diagnostics plus safeguard limits, keep 60-day review separate and preserve accessible result feedback. New label selection means new moment; explicitly direct corrections to history.
- [ ] Run targeted widgets, analyzer and full Flutter suite. Expected all PASS without overflow/timer errors.
- [ ] Generate synthetic captures for light/dark mobile/desktop, 320px/200% reduced-motion and edit/delete/detail dialogs; inspect images and correct layout issues with a regression if behavioral.
- [ ] Commit task code/tests/captures and ledger evidence.

### Task 4: Review, public source and cross-platform verification

**Files:** Modify `README.md`, `docs/quality-status.md`, `docs/device-validation.md`, `pubspec.yaml`; create `docs/releases/1.3.0-decisions.md`. Keep historical release evidence labeled historical.

**Interfaces:** Consumes completed app. Current existing CI and release staging/verification helpers remain authoritative; no new native adapter behavior.

- [ ] Run format check, analyzer, full Flutter tests, existing Python CI-helper suite. Expected all PASS. Record actual counts, not inherited counts.
- [ ] Request a fresh whole-branch code review with spec, plan, ledger and exact diff; resolve material findings with failing regression then full green suite.
- [ ] Update version to `1.3.0+7` and docs to describe research-informed changes, schema compatibility and remaining physical/signing limits. Commit exact source.
- [ ] Push authorized public feature branch, run existing seven-job CI for exact source; inspect job conclusions and native case reports. Package/publish `v1.3.0-preview.1` only after artifact/source/package checks pass. Verify public assets and checksums. If an external prerequisite blocks publishing, retain source and concrete evidence without claiming release completion.
- [ ] Fast-forward public main only after verification/review; update documentation-only publication evidence with source equivalence checked. Preserve exact tested-source/tag/main distinction. Finish with user-visible changes, primary research links, verified tests/builds and concrete outstanding distribution limits.
