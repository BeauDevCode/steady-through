# Steady Through Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a public, offline-first Flutter app that helps people navigate stressful life events on iOS, Android, macOS, Windows, and Linux.

**Architecture:** A Flutter Material 3 UI reads one `AppController` and writes through a JSON repository. Event, contact, check-in, and game data are immutable model values. A pure Dart path-game engine provides observable play cues; the person confirms how the round felt.

**Tech Stack:** Flutter stable 3.47.9, Dart, `path_provider`, `file_picker`, `url_launcher`, Flutter tests, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-05-steady-through-design.md`

## Global Constraints

- Target `android`, `ios`, `macos`, `windows`, and `linux` from one Flutter app.
- No account, backend, analytics, advertising, location, contacts permission, notification permission, or raw game tap trace.
- Game moves are never presented as a stress diagnosis or score. A player confirms whether a round felt calm, tense, or neither.
- Help now remains reachable during every exercise and game; 988 is labeled U.S.-only.
- Grounding and breathing have visible Stop, and grounding has Skip. No required closed eyes, breath holding, or rapid/deep breathing.
- Events can coexist; one is selected. Game history is global; check-ins are event-owned.
- Import validates before a confirmed full replacement. Export writes user-selected JSON. Delete-all and game-history clearing require confirmation.
- Simple words mode requires no birth date and offers read-along guidance.
- Generated platform scaffolds and lockfile are committed. No signing secrets or user records are committed.

## Review Focus

- A malformed or future-version JSON import must leave the current data untouched; Task 2 tests this.
- Deleting the selected event must choose another surviving event or show the empty state, and must delete only its check-ins; Task 2 tests this.
- A game wall, nonadjacent tap, or undo after Start must not make an impossible path or false completion; Task 3 tests this.
- Large text and narrow width must still expose Help now, Stop, and navigation without clipped controls; Tasks 4 and 5 test this.
- A phone/SMS handler missing on desktop must show/copy the number without losing it; Task 6 tests this.

---

### Task 1: Scaffold and data model

**Files:** generated Flutter platform directories and `pubspec.yaml`; create `lib/model/app_data.dart`, `test/model/app_data_test.dart`.

**Interfaces:** `AppData.empty()`, `AppData.fromJson(Map<String,dynamic>)`, `toJson()`; `SupportEvent`, `PlanAction`, `CheckIn`, `TrustedPerson`, `GameRound`; `JourneyStage` enum with five fixed values; `ThemeChoice`, `ReadingStyle`, `RoundFeeling` enums. All model types have `copyWith` where mutations need it.

- [ ] Install Flutter and create the package `steady_through` with the five platform targets and `com.beaudevcode` organization; add and lock the three runtime packages.
- [ ] Write tests that round-trip an event, person, event-owned check-in, global game round, and settings; reject duplicate IDs, dangling active event/check-in, malformed values, and unsupported schema versions.
- [ ] Run `flutter test test/model/app_data_test.dart` and see expected failures from the missing model.
- [ ] Implement the smallest immutable models and JSON validation; rerun the focused test and `flutter analyze`.
- [ ] Commit only Task 1 files.

### Task 2: Durable repository and controller

**Files:** create `lib/data/app_repository.dart`, `lib/data/file_app_repository.dart`, `lib/app/app_controller.dart`, `test/data/file_app_repository_test.dart`, `test/app/app_controller_test.dart`.

**Interfaces:** `abstract class AppRepository { Future<AppData> load(); Future<void> save(AppData value); }`; `FileAppRepository(Directory root)`; `AppController(AppRepository repository, AppData initial)` extends `ChangeNotifier`, exposes `data` and `activeEvent`, and has async methods for create/select/complete/delete event, add/rename/toggle/remove action, add/delete person, add/delete check-in, record/clear game rounds, set theme/reading style, replace data, and clear all. UI awaits mutations.

- [ ] Write tests for first-load empty state, persistence round-trip, invalid local JSON preserving its file, invalid import preserving current state, and serial writes.
- [ ] Write controller tests for new event defaults, active-event switching, event deletion and check-in cascade, action progress, and global game history survival.
- [ ] Run focused tests and observe expected failures before implementing repository/controller.
- [ ] Implement file persistence with a recoverable temporary/backup replacement and controller mutations; run focused tests, full `flutter test`, and `flutter analyze`.
- [ ] Commit Task 2 files.

### Task 3: Pure path-game engine

**Files:** create `lib/game/path_game.dart`, `lib/game/game_feedback.dart`, `test/game/path_game_test.dart`, `test/game/game_feedback_test.dart`.

**Interfaces:** `PathGame` exposes the 4x4 board, current cell, path, move count, backtracks, restart count, completion, `moveTo(int cell)`, `undo()`, `restart()`, and `startNewBoard()`; `GameFeedback.cue(PathGame)` returns a neutral optional break/easier-route cue after repeated revisions; `GameFeedback.pattern(List<GameRound>)` returns a descriptive personal-history summary only when enough user-labeled rounds exist.

- [ ] Test that all preset boards are solvable, only adjacent open cells are accepted, invalid moves do not count, undo/restart work at boundaries, and Finish requires reaching the goal.
- [ ] Test that feedback depends on observable moves, never returns a stress score or diagnosis, and uses user-confirmed feelings for history patterns.
- [ ] Run focused tests to see missing-feature failures, implement the pure engine, then rerun focused tests and `flutter analyze`.
- [ ] Commit Task 3 files.

### Task 4: App shell and event journey

**Files:** create `lib/main.dart`, `lib/app/steady_through_app.dart`, `lib/features/home/home_screen.dart`, `lib/features/journey/journey_screen.dart`, `lib/features/journey/event_form.dart`, `test/widget/journey_test.dart`.

**Interfaces:** `SteadyThroughApp(controller: AppController)` owns adaptive Home/Path/Tools/Check-ins/More navigation and a Help now top-bar action. Home and Path use Task 2 controller methods. Other destinations can initially use temporary placeholders until their tasks land.

- [ ] Write widget tests for welcome/empty state, event creation, selecting among two events, action completion, finish/reopen/delete, and Help now at narrow and large-text sizes.
- [ ] Run widget tests and observe expected failures; implement shell and journey screens with accessible labels and keyboard-friendly controls.
- [ ] Run focused tests, full `flutter test`, and `flutter analyze`; replace placeholders as later tasks land.
- [ ] Commit Task 4 files.

### Task 5: Tools, game, and help UI

**Files:** create `lib/features/tools/tools_screen.dart`, `grounding_screen.dart`, `breathing_screen.dart`, `path_game_screen.dart`, `lib/features/help/help_screen.dart`, `test/widget/tools_test.dart`.

**Interfaces:** Screens receive `AppController`; path game uses Task 3 engine and stores a `GameRound` only after the person chooses a feeling. Help is a route callable from the shell and from each tool screen.

- [ ] Write widget tests for grounding Skip/Stop, breathing Stop, game win and feeling confirmation, move-based optional cue, and Help now while playing at large text.
- [ ] Run focused tests to observe missing-feature failures; implement the screens and connect them to the controller.
- [ ] Run focused and full tests and `flutter analyze`.
- [ ] Commit Task 5 files.

### Task 6: People, check-ins, settings, and data portability

**Files:** create `lib/features/people/people_screen.dart`, `lib/features/check_ins/check_ins_screen.dart`, `lib/features/settings/settings_screen.dart`, `lib/data/data_portability.dart`, `test/widget/people_checkins_settings_test.dart`, `test/data/data_portability_test.dart`.

**Interfaces:** Screens receive `AppController`; `DataPortability` uses `file_picker` for import/export and passes validated data to `replaceData` only after UI confirmation. Number launch uses `url_launcher`, with visible number and copy fallback.

- [ ] Write tests for adding/removing a person, missing handler fallback, check-in save/history/delete, theme/reading style persistence, invalid import, cancel import, confirmed replacement, export, and delete-all confirmation.
- [ ] Run focused tests to observe expected failures; implement UI and portability with no new permission requirements.
- [ ] Run focused and full tests and `flutter analyze`.
- [ ] Commit Task 6 files.

### Task 7: Documentation and platform automation

**Files:** create `README.md`, `PRIVACY.md`, `CONTRIBUTING.md`, `LICENSE`, `.github/workflows/verify.yml`, `.gitignore` additions as needed.

**Interfaces:** CI runs analysis/tests on Ubuntu, Android APK on Ubuntu, iOS simulator and macOS app on macOS, Windows app on Windows, and Linux app on Ubuntu; upload unsigned artifacts with clear labels.

- [ ] Document exact features, privacy/data behavior, safety limits, local setup, platform build commands, signing boundaries, and cited source basis.
- [ ] Add GitHub Actions jobs with Flutter version pinned to `3.47.9` and run YAML/static checks.
- [ ] Run local `flutter test`, `flutter analyze`, and available builds; inspect platform config and license/secret scan.
- [ ] Commit Task 7 files.

### Task 8: Integration, review, and public release

**Files:** only fixes found by integration review and CI.

- [ ] Replace any placeholders, run `dart format`, `flutter analyze`, full `flutter test`, and available local builds; inspect actual output and fix failures.
- [ ] Ask a fresh reviewer to compare the implemented app against the spec, including accessibility, game claims, privacy, and all five platform directories; fix actionable findings.
- [ ] Commit reviewed changes; create `BeauDevCode/steady-through` as a public GitHub repository and push `main` (user explicitly requested public publication).
- [ ] Verify remote visibility and GitHub Actions results; address failures that can be fixed without signing credentials.
- [ ] Report actual tested platforms and any remaining signing/store distribution requirements without presenting source scaffolds as device-ready releases.
