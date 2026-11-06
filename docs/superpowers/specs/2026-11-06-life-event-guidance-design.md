# Optional life-event guidance

The user asked for a free app that helps through life from school to later life, then explicitly requested continued autonomous work. This pass adds voluntary guidance attached to each event. It uses the existing Flutter app, five stages, encrypted local vault, source consent and forest/sage design. Routine implementation choices below are the builder's decisions under that authorization; no question or approval pause is needed.

## Approaches and choice

A separate library would be easy to browse but detached from a person's saved path. An age profile would collect an unnecessary attribute and could choose the wrong guidance. Choose a guide for each event instead: the person selects General, School & growing up, Adult life changes, Caring for someone, or Later life changes. Anyone can choose any guide, and General remains the default. No date of birth, inferred age, caregiver account, clinical program or new device permission is introduced.

## Required behavior

- Each guide has a short description, an optional helper note, five stage prompts and one starter action per stage. Provide standard and Simple words variants. Copy is original general self-help, not a validated intervention. A trusted person/adult/helper is an option, never an assumed safe parent. Caregiving breaks must say care is safely covered. No mandatory disclosure, breathing, emotional outcome or fixed grief schedule.
- The create-event form shows the selected guide and offers a compact chooser and a reusable starter-step picker. General initially selects its five existing generic steps. Choosing another guide displays its five proposed steps with a visible selected count; the person can uncheck any or all before Save. No actions are committed before Save. Confirming a different guide selects its five suggestions; confirming the current guide preserves selection; Cancel preserves both. The selected count is visible immediately.
- Editing an event can change its guide and hence prompts. It never reseeds, renames, completes or deletes saved actions. The form explains that existing steps stay. Path offers a separate `Choose starter steps` dialog for adding selected suggestions to an existing event.
- Suggested steps become ordinary editable actions with fresh IDs. Resolve suggestion IDs inside the controller against the event's current guide. Unknown, cross-guide and repeated input IDs reject atomically. Existing actions matching the same stage and either standard or simple suggestion title, compared after trimming/case folding, are not duplicated, including completed actions. A renamed/deleted suggestion can be deliberately added again. Repeated/concurrent additions must not duplicate actions.
- New suggestion text is copied using the current reading style. Later style/catalog changes do not rewrite saved titles. Existing two-argument `createEvent` calls preserve the five General suggestion identities/stages; new saved suggestion text follows the queued reading style, including Simple words. Explicit empty selections create an event without actions.
- Home shows the selected guide label and keeps `nextPendingAction` ordering. An unfinished event with no actions invites adding a step in Path instead of claiming all work is done. Path shows guide description/helper note and context-specific prompts. Help, tools, people, check-ins and optional Insights remain equally available. Guide choices do not enter learning features, labels, calibration or native signals.
- Keep keyboard and screen-reader labels, scrollable dialogs and visible save/cancel paths. Check 320-pixel/200% text and large desktop light/dark rendering. Use existing theme/components. A guide-card transition may animate briefly; OS reduced motion removes its duration. Selecting context never guesses a feeling.

## Data and compatibility

Add `GuidanceContext` in a dependency-free enum file. `SupportEvent.guidanceContext` is nonnullable, default General; `copyWith` retains it unless explicitly changed. PlanAction's schema is unchanged. Catalog lives in pure Dart, independent of Flutter, with stable IDs `<context>.<stage>`, immutable content and exact per-context resolution.

Write AppData document version **3**. Accept versions 1, 2 and 3. Versions 1/2 reject an injected guidance key and migrate missing context to General without changing actions or IDs. Version 1 retains its learning-off migration; versions 2/3 require valid learning. Version 3 requires a valid context on every event; unknown/null/wrong-type context rejects before replacing active data. Standalone SupportEvent parsing can default legacy absence to General, with a flag to reject the new key for old documents. Older app releases cannot read version-3 documents: state this in release/privacy documentation. The encrypted envelope format and cryptography are unchanged.

All controller mutations use the existing serialized queue and pre-commit validation. Invalid IDs or genuine save failures preserve current data. New fields follow encrypted persistence/export and event deletion naturally. Import still resets device usage, motion and device-owner confirmation on the destination, and preserves allowed manual/in-app choices. Clear learning preserves guides/actions.

## UI and content structure

- Guide chooser: five labelled options with short descriptions; current choice marked; Cancel leaves state alone.
- Starter picker: five stage-labelled checkboxes and selected count; existing matching steps disabled with `Already in your path`; none is allowed. In the create form, selection is local until Save; on Path, one queued batch save.
- Form uses a typed submission carrying title, description, guide and selected IDs for creation. Editing uses no starter selection, with existing context preloaded.
- Path's stage prompts are catalog-driven; saved actions remain user-owned text. General preserves current prompts/default titles for compatibility.
- Original copy is informed by NIMH caring-for-mental-health guidance, UNICEF positive parenting/teen support, NIH caregiving/loss checklists and NIA meaningful activity guidance. Record direct sources and limits in a content note. These sources do not endorse or validate the app or its five-stage order.

## Verification and release

Use meaningful failing-then-passing model/controller and widget regressions. Exercise legacy migration, strict version/key handling, atomic selection validation, changed-guide preservation, duplicates, failed saves and simplified content. Verify independently encrypted portability with guide/actions/consent. Extend the existing native backup case with a non-General guide; retain all three exact native case names and sources-off/no-grant conditions. Run formatting, analysis, full Flutter/helper tests and all five production/native CI jobs. Render and inspect synthetic new guide screens. Obtain scoped task reviews and one whole-branch review. Publish the next preview only after required gates, verify asset/server hashes, update main and document physical-device/accessibility/signing limits. Do not claim outcomes for children, older adults or caregivers from automated checks.
