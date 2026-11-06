# Life-event Guidance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Root owns all Git and Flutter/Dart/native commands; implementers edit their task files and wait for root RED evidence before production edits. Steps use checkbox syntax.

**Goal:** Give each event voluntary, useful context guidance and selectable starter steps, preserving records, privacy and old imports.

**Architecture:** Pure Dart context/catalog feeds a version-3 event model and serialized controller mutations. Reusable Flutter chooser/picker components connect creation/editing and Path. Existing encrypted portability and five-platform native checks verify the new field without new permissions.

**Tech Stack:** Flutter 3.47.9 / Dart 3.13.7, existing dependencies only.

**Spec:** docs/superpowers/specs/2026-11-06-life-event-guidance-design.md

## Global Constraints

- All support remains free, offline, and usable with every learning source off; no new permission or native collector.
- Guide is selected per event, never inferred from age, clicks or labels. No DOB, caregiver account, diagnosis or outcome claim.
- Five guides: general, schoolAndGrowing, adultChanges, caregiving, laterLife. Five existing JourneyStage values remain unchanged.
- Standard and Simple words content; no saved action rewritten by a later guide/style/catalog change.
- Version 3 writes; strict v1/v2/v3 reads; legacy context defaults General; no silent downgrade or plaintext fallback.
- All new mutations stay in the existing serialized queue; invalid IDs/save failures preserve active data; imported system sources still reset off.
- Fictional temporary data only in tests/captures. Root serializes verification and Git; no OS grants or real phone activity.

## Review Focus

- A zero-action unfinished event needs an invitation to add a step, not completed-work copy.
- Guide edits preserve action IDs/text/order/done, timestamps and check-ins, including concurrent additions.
- A stale picker cannot add another guide's IDs; unknown/repeated IDs reject before any partial save.
- Completed suggestions and their standard/simple variants cannot be re-added accidentally; renamed/deleted steps can be chosen again.
- Old encrypted/legacy imports remain readable; v3 unknown/missing context rejects before confirmation/replacement, while native consent resets on valid import.

### Task 1: Versioned model, catalog and atomic controller behavior

**Files:** create lib/model/guidance_context.dart, lib/model/event_guidance.dart; modify lib/model/app_data.dart, lib/app/app_controller.dart; tests test/model/app_data_test.dart, test/data/file_app_repository_test.dart, new test/app/event_guidance_test.dart; content note docs/guidance-content.md.

**Interfaces:**
- `enum GuidanceContext { general, schoolAndGrowing, adultChanges, caregiving, laterLife }` in dependency-free file, imported/exported by app_data.dart.
- SupportEvent constructor/copyWith adds `GuidanceContext guidanceContext = GuidanceContext.general`; JSON key `guidanceContext` uses enum name. Standalone fromJson allows absence->General, with `bool allowGuidance = true`; old-document callers set false to reject an injected key.
- AppData writes version3, accepts1/2/3. v3 event context required; v1/2 absent->General and injected key rejected. v1 learning migration and v2/v3 valid-learning requirement retained.
- `EventGuidance guideFor(GuidanceContext context)` returns immutable `context`, `label`, `simpleLabel`, `description`, `simpleDescription`, `helperNote`, `simpleHelperNote`, `List<StarterStep> starterSteps`; `stagePrompt(JourneyStage stage, {required bool simpleWords})` returns appropriate copy.
- StarterStep has const `id`, `stage`, `title`, `simpleTitle`; `text({required bool simpleWords})`; `matchesAction(PlanAction action)` compares same stage + trimmed lowercase standard or simple text.
- `List<StarterStep> resolveStarterSteps(GuidanceContext context, List<String> ids)` rejects repeated/unknown/cross-guide IDs, returns guide/stage order. Stable IDs are `<enumName>.<stageName>`.
- `createEvent(String title, String description, {GuidanceContext guidanceContext = GuidanceContext.general, List<String>? starterStepIds})`: null selects all five for that guide, empty selects none; resolve inside queue, copy text from current queued reading style, fresh action IDs.
- `updateEvent(String id, String title, String description, {GuidanceContext? guidanceContext})`: current-event copy, actions/times unchanged.
- `addStarterActions(String eventId, List<String> starterStepIds)`: one queued batch, resolve against current event guide, preserve all existing actions, skip stage/title matches, fresh IDs only for new actions. Empty selection may no-op. Duplicate selection requests, including concurrent calls, never duplicate saved actions.

**Copy decisions:** General standard titles retain exactly `Notice what needs attention first`, `Take a short pause`, `Choose someone to reach out to`, `Write one next step`, `Notice what helped`. Compatibility means their identities/stages remain; Simple mode may copy simpler titles for newly selected steps, while existing titles remain. Other guides use original short copy informed by the six authoritative sources in the content research brief. Every guide has one step and prompt per stage. Describe context, not an age classification. Caregiving break copy requires care safely covered. School helper note offers a trusted adult/person; later-life choice never assumes loss/retirement.

- [x] Write regressions for legacy1/2 migration, strict3 context parsing/round-trip/copy retention and real controller selection/preservation/dedup/failure/concurrency behavior. Update old v2-output assertions to3 and unsupported-version fixture to4/99; retain v1/v2 input coverage.
- [x] Root runs focused RED and confirms missing behavior before production edits.
- [x] Implement the model/catalog/controller contracts and source/limits content note; no UI/native files.
- [x] Root runs focused tests, full suite and analysis; task source review, fixes and commit.

### Task 2: Accessible guide and starter selection throughout the event flow

**Files:** create lib/features/journey/guidance_picker.dart; modify event_form.dart, journey_screen.dart, home/home_screen.dart, app/steady_through_app.dart; new test/widget/event_guidance_test.dart plus affected existing widget tests only if an intended behavior changed.

**Interfaces:**
- EventFormSubmission immutable title/description/guidanceContext/nullable `List<String> starterStepIds` in event_form.dart; EventForm onSave takes that object. Creation passes chosen IDs; editing passes null, ignores starter reseeding.
- Reusable `Future<GuidanceContext?> showGuidancePicker(BuildContext context, {required GuidanceContext selected, required bool simpleWords})` and `Future<List<String>?> showStarterStepsPicker(BuildContext context, {required GuidanceContext guidanceContext, required bool simpleWords, required List<String> selectedIds, List<PlanAction> existingActions = const []})`.
- Scrollable, constrained dialogs; wrapped labels; Cancel leaves state; selected context marked; starter rows show stage + appropriate text. Existing matching actions disabled with `Already in your path`, never selected in output. Empty selection is allowed.
- Creation initially General/allfive. Confirming a DIFFERENT guide selects allfive of that guide and updates visible count; same-guide confirmation preserves checkbox selection; cancellation preserves both. Counts/selection local until Save. Editing preloads guide and states `Your saved steps stay as they are.`
- Path guide card shows description/helper note and `Choose starter steps`; batch saves once using controller. Per-stage prompts catalog-driven. Home selected guide label; zero-action unfinished state says `Choose a starter step or add your own in Path.` (simple: `Add a step in Path when you are ready.`). Completed-event and all-done nonempty copy retained.
- Existing first two TextFormFields stay title/description; Save event bottom action remains reachable. All Help/Tools access unchanged. Brief guide-card animation respects MediaQuery.disableAnimations; default duration at most200ms, zero when reduced motion.

- [x] Write widget regressions for deliberate guide/step creation, none selection/zero-action invitation, same-guide/cancel preservation, edit-with-done-actions retention, existing-step disabling, per-event switching, Simple words and failed saves staying open.
- [x] Root confirms RED; implement reusable selectors, typed submission adapters and contextual display.
- [x] Root checks 320px/200% text and1200px, keyboard/semantics, existing full navigation suite; task review/fixes and commit.

### Task 3: Encrypted portability, native/capture evidence and public preview

**Files:** test/data/data_portability_test.dart and encrypted repository tests as appropriate; integration_test/native_smoke_test.dart; tool/capture_guidance_ui_test.dart; pubspec.yaml version **1.2.0+5**; README/PRIVACY/CONTRIBUTING, docs/quality-status.md, docs/device-validation.md, docs/screenshots, plan checkboxes.

**Interfaces:** Use catalog/context from Task1 and real selectors fromTask2. Preserve native three exact test names, timeouts, real encryption/filesystem and no-grant sources-off behavior. Native backup case creates a non-General guide with edited/done steps, then verifies restored metadata/actions through the independent passphrase and authenticated reopen. Native test OS chooser/scripted-dialog limit remains explicit.

- [x] Add meaningful encrypted round-trip regression for context, selected/edited/done actions and retained manual choices while native consent resets; invalid3 context must not reach import confirmation or change records. Root observes RED where missing behavior remains, then corrects production owner via follow-up rather than weakening tests.
- [ ] Render synthetic creation/pickers/Path/Home in standard/Simple/light/dark, narrow200% text and large desktop; visually inspect PNGs. No real passphrases or permissions in captures.
- [ ] Run formatter, analyzer, full Flutter suite, helper tests, scoped source reviews, then one whole-branch review; fix material findings with regression evidence.
- [ ] Run all five production/native CI targets at intended source; inspect actual3-case JSON per platform and Android JUnit, archive versions/contents/checksums.
- [ ] Update source/compatibility/privacy/quality documentation, publish v1.2.0-preview.1 under existing user authorization, verify publicmain/tag/allasset server hashes, then mark publication complete. Physical collectors, OSdialogs, native screen readers, signing and real health outcomes remain separate.
