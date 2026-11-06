# What Helps You Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Let people optionally rate support tools and revisit ones they explicitly marked helpful.

**Architecture:** Separate bounded ratings/settings in the existing encrypted document, guarded queued mutations, reusable foreground-aware feedback/history UI, and completion-point integrations. Suggestions retrieve explicit recent preferences and do not train the feeling model.

**Tech Stack:** Existing Flutter/Dart, Material, cryptography and flutter_test; no new dependencies or permissions.

**Spec:** `docs/superpowers/specs/2026-11-06-what-helps-design.md`

## Global Constraints

- App1.4.0+8, write schema4/read validated1/2/3/4; preserve version>=3 guidance behavior.
- New top-level toolFeedback object; records/settings stay in the existing encrypted vault/export. Crypto/native sources unchanged.
- Helpful/Not this time are explicit opinions; Skip/Stop/Help/completion save nothing automatically.
- Maximum1,000 ratings, inclusive180-day retention, UTC timestamps, deterministic timestamp/ID ties; no persisted derived score.
- All tools and rating management work with every learning source off. No rating choice becomes a feeling label, GameRound or sensor-model feature.
- Stop/Back/Help stay immediate. Current possible-vehicle context suppresses feedback mutations; missing motion stays unknown.
- Guard document replacement and foreground/attempt lifetime inside queued writes; started atomic writes may finish without late UI success.
- Existing palette, Simple words,48px controls, keyboard actions,200% text and reduced motion.

## Review Focus

- A queued save or stale dialog must not write into a replaced/imported document, including matching record IDs.
- Closing/backgrounding or resetting a tool attempt during a write must not show Saved on a new route/board; committed writes must not be mistaken for failures.
- Schema4 must preserve non-General guides and existing plans/learning while rejecting malformed earlier-version payloads and invalid rating fields before import confirmation.
- Correction/delete/clear/retention must remove old recovery copies without deleting unrelated records or treating cleanup failure as an unsaved action.
- A negative/skipped rating must not become emotional evidence or hide ordinary tools; source-off users need the full ownership flow.

---

### Task 1: Encrypted rating data, migration and safe mutations

**Files:** Create `lib/model/tool_feedback.dart`, `lib/model/tool_feedback_summary.dart`; modify `lib/model/app_data.dart`, `lib/app/app_controller.dart`, `lib/app/vault_gate.dart`, `lib/data/data_portability.dart`; create `test/model/tool_feedback_test.dart`, `test/app/tool_feedback_test.dart`; extend `test/model/app_data_test.dart`, `test/data/data_portability_test.dart`; adjust legitimate legacy fixture builders and prune call sites.

**Interfaces:** `SupportTool {grounding,breathing,pathGame}`; `ToolRating {helpful,notThisTime}`; immutable `ToolFeedback(id,createdAt,tool,rating)`; `ToolFeedbackData(showPrompts,useSuggestions,ratings)` with `bounded`, `record`, `correct`, `remove`, `copyWith` and strict JSON. `ToolFeedbackSummary.fromData(data,{now})` provides newest-first `ratings`, per-tool `counts(tool)` (`helpful`,`notThisTime`,`latest`) and `suggestion` (latest Helpful among latest-per-tool ratings, null when suggestions off). Controller `recordToolFeedback(tool,rating,{required expectedRevision,isActive}) -> Future<ToolFeedback>`; `correctToolFeedback(id,rating,{required expected,required expectedRevision,isActive})`; matching delete; `clearToolFeedback({required expectedRevision,isActive})`; `updateToolFeedbackOptions({bool? showPrompts,bool? useSuggestions,required expectedRevision,isActive})`; `pruneRetainedData()`.

- [x] Write failing tests for strict record/settings validation and immutable UTC roundtrip; schema1/2/3→4 preserving guide/plan/learning; invalid4/unknown5, illegal field in earlier versions; inclusive180day/future/tie/1000eviction; most-recent helpful retrieval and latest-negative exclusion with all ordinary tools retained by UI.
- [x] Write controller tests for exact receipt/correction identity/time, expected-ID+instance checks, queued unrelated writes, replacement revision/lifecycle guard checked at execution, failed primary save versus committed cleanup warning, clear scope, retention/eviction purge and post-dispose rejection. Extend real encrypted portability with rating/settings roundtrip and unchanged native consent reset.
- [x] Run targeted tests to observe missing behavior (RED). Implement models, schema4/version>=3 parsing, guarded current-state mutations and both-history retention. Replace production/test `pruneLearning` calls with `pruneRetainedData`; do not weaken malformed-import expectations.
- [x] Run targeted suites then `flutter test`. Expected all PASS. Commit code/tests and record actual evidence.

### Task 2: Optional rating prompt, ownership history and explained ideas

**Files:** Create `lib/features/tools/feedback/feedback_activity.dart`, `tool_feedback_prompt.dart`, `tool_feedback_history.dart`, `tool_feedback_dialog.dart`, `what_helps_card.dart`, `feedback_display.dart`; create `test/widget/tool_feedback_test.dart`.

**Interfaces:** `FeedbackActivity` observes lifecycle, exposes active/epoch guard and closes cleanly. `ToolFeedbackPrompt(controller,tool,LearningSession? safetySession)` is collapsed by default and borrows the controller; parent gives a fresh widget key per attempt. `WhatHelpsCard(controller,{safetySession,onOpenTool})` shows exact counts/latest answers, optional explained suggestion, two settings and link to lazy `ToolFeedbackHistory`. Dialogs support add/correct/delete/clear with revision, expected receipt and lifecycle guards; no caller supplies a stale whole AppData/list.

- [x] Write failing widget tests for collapsed/expand/skip/no automatic save, duplicate tap with delayed repository, failed save/retry, correction and exact Undo, source-off/paused use, prompt setting off/manual Add still available, suggestion reason/latest-negative behavior, per-record and clear confirmation scope, stale/import/background/vehicle/disposal guards and safe late completions.
- [x] Run targeted widget file (RED). Implement focused widgets and activity guard, live success/error semantics and wrapping controls. Suggestions open only after a tap. Ratings list uses lazy rendering; external exports remain outside deletion scope. Record primary success plus cleanup warning distinctly.
- [x] Run widget tests, analyzer and full Flutter suite. Expected all PASS. Commit and ledger actual results.

### Task 3: Integrate all tool entry points, pacing and encrypted native fixture

**Files:** Modify `lib/features/tools/tools_screen.dart`, `grounding_screen.dart`, `breathing_screen.dart`, `path_game_screen.dart`, `lib/app/steady_through_app.dart`; extend `test/widget/tools_test.dart`, `test/widget/insights_test.dart` as needed; extend `integration_test/native_smoke_test.dart`; create `tool/capture_feedback_ui_test.dart` and synthetic screenshots.

**Interfaces:** Tool constructors gain optional `LearningSession? safetySession`; shell and game-break routes forward it consistently. Grounding uses prompt at finished view. Breathing adds explicit Done for now/Start again with attempt key, paused lifecycle and static reduced-motion circle. Game prompt is independent of `_chooseFeeling`; new/easier/restarted attempts reset prompt state. Tools summary callback opens the selected tool in the existing route with shell help/path callbacks.

- [x] Write failing integration/widget cases for Grounding skipped-to-ending, immediate Stop/Back/Help, all shell return labels, Breathing Done cancels timer/Help pauses/no auto-resume/static reduced motion, game usefulness without GameRound and independent feeling save, new-board/in-flight prompt isolation, source-off summary and320px/200% Simple/reduced-motion layouts.
- [x] Run targeted widget suites (RED). Integrate reusable components and safety parameters; keep original tool ordering and direct exits. Update game grounding return label to Back to game.
- [x] Extend the existing native encrypted backup case with synthetic ratings of all tools/both answers plus options. Assert exact preservation after confirmed import and authenticated reopen, unchanged plans/settings/native-consent-off behavior and exactly the original3native case names. Existing encrypted unit fixture verifies the same payload before CI.
- [x] Run analyzer/full Flutter/helper suites. Generate and inspect synthetic mobile/desktop/light/dark/large-text prompt, summary, history and dialog captures; no personal vault/passphrase or OS grants. Commit and ledger evidence.

### Task 4: Whole-branch review and verified public1.4preview

**Files:** Update `pubspec.yaml`, `README.md`, `PRIVACY.md`, `docs/quality-status.md`, `docs/device-validation.md`, `docs/ios-distribution.md`; create `docs/releases/1.4.0-decisions.md` and publication snapshot.

- [x] Run fresh format/analyzer/full Flutter/helper verification; record actual counts. Request fresh whole-branch review on exact range with spec/plan/ledger/Review Focus. Resolve material findings with RED→GREEN regressions and a full green suite.
- [x] Set1.4.0+8 and document schema4/read1..4 downgrade/backup boundaries, optional opinions and remaining manual/distribution limits. Adapt previous scoped release helpers without weakening source/package/native/hash gates; preserve original3case names and6packages/10assets.
- [ ] Push public feature branch; all7existing CI jobs must pass on exact final source. Download13source-bound artifacts and verify actual suite/native reports/binary metadata. Stage6packages plus evidence/checksums; independent artifact review precedes public release. Draft-upload/hash-check then publish `v1.4.0-preview.1` with tag exactly equal to CI source.
- [ ] Update public main through reviewed source and documentation-only publication records. Verify ancestry/rename-safe doc allowlist, server asset hashes/sizes/states and anonymous repository/release/all10downloads. Cancel only any redundant tag-triggered identical-source run. Keep physical devices/grants, real OS dialogs, native assistive technology, signing and efficacy as unexecuted separate work.
- [ ] Record final evidence, archive/remove only this plan scratch workspace, finish branch and report concrete changes with verified limits. Do not stop merely after local tests or review.
