# Quick Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make trusted people reachable from Help and the exact pending action reachable from Home.

**Architecture:** Current-state guarded controller mutations, shared People form/cards in Help, and an ephemeral focused route for an existing action. No new persisted data; retain the existing vault and platform adapters.

**Tech Stack:** Existing Flutter/Dart/Material/url_launcher/flutter_test; no new dependencies.

**Spec:** `docs/superpowers/specs/2026-11-06-quick-support-design.md`

## Global Constraints

-1.5.0+9 preview; unchanged schema4/read1..4, envelope/KDF/sources/model thresholds/native adapters.
- Free/offline/source-off functionality; no contact permission, backend, raw monitoring, automatic call/text/clipboard or real contact during tests.
- Help preview up to3 people in stored order; exact original crisis content and immediate Back/Help preserved.
- Dialog and mutation guards run inside the write queue against current data, revision, expected ID+instance and active view. Disposed controller rejects ownership writes. Started atomic saves may finish without late navigation to another route.
- Shared view policy `ViewActivity.active`, `.epoch`, `.accepts(int)` in `lib/ui/view_activity.dart`; disposal/foreground transitions invalidate epochs. Existing feedback policy stays untouched.
-48px wrapping controls, Simple words,320px/200% text, live errors and reduced motion. Every pending save keeps navigation/cancel available.

## Review Focus

- A stale edit/remove dialog or focused action must not alter imported same-ID data, a different active event, or a corrected record.
- Cancel/background/route closure before queued save versus after atomic commit must not duplicate saves, lose input, pop another route or show false success.
- Failed native handlers/clipboard and numberless people must leave Help usable; live contact edits/imports must not launch a stale number or expose values to learning.
- Focus completion/Undo must affect only the exact current action; deleted/completed/no-next events retain full Path access without changing another task.
- New routing must preserve Home/Path/Help/tool returns, breathing pause, all source-off features and current encryption/import/native evidence boundaries.

---

### Task 1: Guarded ownership mutations and foreground policy

**Files:** modify `lib/app/app_controller.dart`; create `lib/ui/view_activity.dart`, `test/app/quick_support_test.dart`.
**Interfaces:** addPerson optional expectedRevision/isActive; updatePerson required expected TrustedPerson+revision; deletePerson optional expected/revision/isActive (UI always supplies); setFocusedActionDone(eventId,actionId,done,{required PlanAction expected,required int expectedRevision,bool Function()? isActive}); ViewActivity as Global Constraints. Person edit/remove explicitly purge residuals.

- [x] Write tests for trimmed name/phone, blank rejection, clear phone, ID/order/other-data preservation; exact-ID/instance and revision mismatch; queued theme+edit; foreground callback evaluated at execution; closed rejection; primary failure versus committed cleanup warning. Focus requires same active unfinished event and exact action; test done/undo/failure/deleted/completed/other-active/same-ID import and unrelated writes.
- [x] Run `flutter test test/app/quick_support_test.dart --reporter expanded` (expected RED missing methods/guards), implement current-state APIs and ViewActivity, then run targeted file (expected PASS). Root owns controller and policy file.
- [x] Run full Flutter suite after integration; commit Task1 files and record exact RED/GREEN and full-suite evidence in ledger.

### Task 2: Shared trusted people, editing and Help preview

**Files:** create `lib/features/people/phone_actions.dart`, `person_card.dart`, `person_form_dialog.dart`, `trusted_people_section.dart`, `test/widget/trusted_people_test.dart`; refactor `people_screen.dart`; modify `lib/features/help/help_screen.dart`.
**Interfaces:** PhoneActions/UrlLauncherPhoneActions moved with PeopleScreen re-export; PersonCard(controller,person,{phoneActions,showManagement=true}); PersonFormDialog(controller,{person}); showPersonForm(context,controller,{person}); TrustedPeopleSection(controller,{phoneActions}); HelpScreen optional controller and phoneActions; HelpNowButton optional controller. Root Task3 handles shell/tool forwarding.

- [x] Write widget tests before implementation: explicit-only Call/Text/Copy, false/thrown handler fallback, clipboard failure, missing number, latest data after edit/import, Help up-to3 preview/View all/empty Add, editing prefill/clear/cancel/fail/retry/duplicate/save persistence, exact stale same-ID edit/remove, cancel/foreground/disposal late completion, cleanup warning versus failed save, sources off, narrow/200%/Simple/reduced-motion and return to Help. Run file to observe RED.
- [x] Implement focused shared cards/form/section with current-state guards, duplicate suppression, complete labels/live errors and no auto-handoff; retain ordinary People remove confirmation. Run targeted file (expected PASS) and root integration suites.
- [x] Commit Task2 files after full green integration and ledger evidence. No new source or permission; emergency Help content remains unchanged.

### Task 3: Focused next action, entry points, native fixture and visuals

**Files:** create `lib/model/next_action_target.dart`, `lib/features/journey/focused_action_screen.dart`, `test/widget/focused_action_test.dart`, `tool/capture_quick_support_ui_test.dart`; modify `home_screen.dart`, `steady_through_app.dart`, all tool HelpNowButton call sites, `test/widget/journey_test.dart`, `test/widget/tools_test.dart` as needed, `integration_test/native_smoke_test.dart`, `test/data/data_portability_test.dart`.
**Interfaces:** NextActionTarget(eventId,actionId,replacementRevision), FocusedActionScreen(controller,target,{onOpenHelp,onOpenPath}), optional Home.onOpenNextAction ValueChanged<NextActionTarget>. Root owns Home/shell/tool forwarding/integration/native/captures; focused-screen worker owns only target/screen/standalone test.

- [x] Write standalone and shell widget regressions for exact action vs five-stage Path, explicit-only completion/Undo/no advance, failure/retry/concurrency, stale target/import/deleted/completed/changed-active cases, immediate Help/Back/fullPath, Home no-next states and proper return/pause from all Help entry points. Observe RED before production integration.
- [x] Implement target/focus screen and Home navigation; forward controller to shell and fallback Help buttons. Reuse existing full Path and People routing. Run targeted files (expected PASS).
- [x] Extend real encrypted unit and existing native backup case with fictional edited people: stable ID/order, optional phone clearing and preservation through export/import/authenticated reopen, with ratings/guides/settings/native consent behavior intact. Preserve exactly original3 native case names. No real handoff in native tests.
- [x] Generate/inspect synthetic Help/People/edit/focus mobile light, desktop dark and320px/200%/Simple/reduced-motion captures. Run format/analyze/full Flutter/Python helper suite (expected PASS), commit and ledger actual results.

### Task 4: Review and verified public1.5 preview

**Files:** pubspec.yaml, README.md, PRIVACY.md, docs quality/device/iOS records; new docs/releases/1.5.0-decisions.md and publication snapshot.

- [x] Set1.5.0+9; document current behavior, unchanged schema4/read1..4 and remaining owner/manual work. Adapt1.4 operational release helpers to1.5+9 without weakening any gate.
- [x] Fresh whole-branch review on most capable model after green local verification; address material findings with RED→GREEN regressions in one fix pass, then full suite. No repeated whole-branch review loop.
- [x] Push final source; require all7 CI jobs PASS with actual suite counts,3nativecases each5runtimes andJUnit12. Download all13 source-bound artifacts; full payload/metadata/Apple device/hash/provenance checks and independent staged-byte audit precede publication.
- [x] Draft-upload/verify exact body and10serverhashes/sizes; publish v1.5.0-preview.1 tag exactly equal CI source. Update publicmain with tested source plus documentation-only verified records; verify rename-safe source ancestry, public repository/release/all10anonymous downloads. Cancel only redundant tag run on identical already-verified source.
- [x] Archive/remove only this plan scratch, finish branch and final evidence. Do not stop after tests/review. Physical signing/grants/dialogs/assistive technology/human outcomes remain distinct unexecuted work.
