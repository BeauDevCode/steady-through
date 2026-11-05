# Steady Through — Product Design

## Intent

Steady Through helps a person move through a stressful life event, one manageable action at a time. The person may be overwhelmed, short on time, or unsure what to do next. The app gives them a simple route from the first difficult moments through support, practical tasks, and later reflection.

The user asked for a complete public repository with one working app for iOS, Android, macOS, Windows, and Linux, and asked for direct execution. Product choices below are builder decisions made in service of that request; the user can change them later.

## Goals

- A person can create an event, see its current journey, add and finish practical steps, record check-ins, save trusted people, and return later to their data.
- A person can open a short, self-paced grounding exercise at any point, with visible Skip and Stop controls.
- A person can play a short, untimed strategy game. The app notices observable play patterns, asks whether the round felt tense, and uses that answer to offer a relevant next step.
- A person can reach a clearly labeled help screen from every main destination, including during an exercise.
- Entries persist on the device without an account or network connection. The person can export and import their data and delete it all in settings.
- The same Flutter source works on the five requested platforms, with automated checks and platform build jobs in GitHub Actions.
- The app is usable with large text, screen readers, keyboard navigation, and both light and dark themes.

## Boundaries and safety

- The app provides general self-help and organization. It does not diagnose, treat, monitor, or promise to resolve a condition or danger.
- It does not require a mood score, notification permission, contacts permission, location, account, analytics, or a backend.
- The app is useful from early childhood through older adulthood without asking for a birth date. A Simple words setting shortens instructions and prompts an adult or trusted helper to read along when needed. No chat, social feed, advertising, or player ranking is included.
- Game behavior is an uncertain clue about this specific task, not a valid clinical stress measurement. The app never labels a person as stressed from moves alone, never shows a diagnostic score, and asks the person how the round felt before tailoring a suggestion. The game is optional, untimed, has no failure state, and stores no raw tap trace.
- The Help now screen says that a person in immediate physical danger should contact local emergency services. It labels call/text 988 as a U.S. crisis option and tells people elsewhere to use their local crisis service. It also recommends professional support when distress worsens or interferes with daily life.
- Exercises never require closed eyes, breath holding, or deep/fast breathing. They can always be skipped or stopped. Copy is original and avoids lifting text from third-party guides.
- Contact phone numbers are entered manually. Opening the phone or SMS app happens only after a user tap, and a copy-number fallback remains available on desktop.
- Data stays in one local JSON document under the app's support directory. Export/import uses a user-chosen JSON file. The README plainly states that an exported file is outside app storage and that uninstalling can remove local data.

## Experience

1. **Start:** Welcome explains the app's scope and privacy. The user can begin without an account. Creating an event asks for a short title and optional description. No category or explanation is required.
2. **Right now:** Home shows the active event, one-tap access to grounding and Help now, the next unfinished step, and a check-in action. Empty state asks the person to start an event.
3. **The path:** Five fixed stages provide a clear default structure: Get oriented, Settle, Find support, Make a plan, Reflect. Each stage has a brief original prompt and one default action. The user can add, rename, complete, or remove actions within a stage. Progress is derived from completed actions, never from elapsed time or a clinical score.
4. **Tools:** A self-paced grounding flow gives a few short prompts about the present surroundings and choosing a next action. Skip and Stop remain visible. A separate optional breathing pace screen uses a gentle visual rhythm and a Stop control. No exercise is required to finish an event.
5. **Path game:** The user can move through a small grid from Start to Finish, choosing among possible routes around obstacles. It has no countdown or score. Undo and Restart are always available. After repeated backtracks or restarts, the app offers an optional break or easier route based on those moves, without claiming to know why they happened. After a round, it summarizes neutral facts such as turns and backtracks, then asks whether it felt calm, tense, or neither. If the user confirms tension, it offers grounding or a smaller real-life next step; otherwise it offers another round or the event path. The app stores only per-round summary counts and the person's answer, so later rounds can show a plain-language pattern from their own history. It does not infer a medical state.
6. **People:** The user can save trusted people with a name and optional phone number, then copy a number or open the device's phone/SMS handler after tapping.
7. **Check-ins:** The user can record a feeling in their own words, an optional intensity from 1 to 5, and an optional note. They can view history and delete an entry. These are personal notes, not medical measurements.
8. **Finish:** The user can mark an event complete, keep its history, reopen it, or delete it. Settings offers theme selection, import/export, privacy details, reading style, and delete-all with confirmation.

Several unfinished events may coexist. Home shows one selected active event; a visible event switcher selects another. Creating or reopening an event selects it. Import validates the entire file first, then replaces all local data only after a clear confirmation; it never silently merges or partially applies an import.

Game-round summaries belong to the person, not to an event, so the game works before an event exists. Deleting an event leaves those summaries; the game screen can clear its history, and delete-all removes it too. Check-ins are tied to events and are deleted with their event.

On narrow screens, Home, Path, Tools, Check-ins, and More use bottom navigation. On wide screens, they use a navigation rail. More contains People and Settings. Help now stays in the top app bar. Empty screens contain a next action and no decorative dead ends.

## Approach choices

1. **Flutter with local storage (chosen):** One Dart codebase can target all five requested platforms; offline-first storage avoids a service dependency. The tradeoff is that Apple builds need macOS/Xcode, and Windows/Linux builds need their respective hosts or CI runners.
2. **Separate native apps:** Native UI can fit each platform closely, but five codebases would multiply implementation and maintenance work and risk different behavior across devices.
3. **Web app in platform shells:** Shared web code can cover many devices, but OS file handling, accessibility, and desktop/mobile packaging would add shell-specific work. A browser-first experience also gives weaker offline ownership for this use case.

## Architecture

- Flutter Material 3 UI with feature folders for home, journey, tools, people, check-ins, settings, and help.
- Immutable Dart models for events, actions, people, check-ins, and game-round summaries. One app state controller owns mutations and notifies the UI.
- A storage interface separates JSON encoding and persistence from widgets. Production storage writes an atomic replacement file in the app support directory; tests use an in-memory implementation or a temporary directory.
- `path_provider` locates app storage, `file_picker` handles user-chosen import/export files, and `url_launcher` opens phone/SMS handlers when available. These packages must be checked for all five targets before release. The app displays and copies phone numbers when no phone/SMS handler is installed.
- No cloud service, account, or embedded secret.

## Verification and release

- Unit tests cover model serialization, invalid/corrupt imports, state transitions, event deletion, persistence round trips, game path rules, and truthful game feedback.
- Widget tests cover the empty home state, event creation, journey action completion, help access, exercise Stop/Skip, and a complete game round with a user-confirmed feeling.
- `flutter analyze` and `flutter test` run in CI. GitHub Actions builds an Android APK, an iOS simulator app, and Linux, macOS, and Windows desktop outputs on matching runners. The iOS simulator output is not an installable iPhone release; device distribution needs Apple signing. Other unsigned outputs may require platform trust steps.
- The public repository includes a README, LICENSE, privacy document, contribution notes, automated checks, and source citations for safety copy. No private user data or credentials enter Git.

## Source basis

- Flutter platform support: https://docs.flutter.dev/platform-integration
- WHO stress self-help concepts: https://www.who.int/thailand/activities/doing-what-matters-in-times-of-stress
- NIMH help-seeking guidance: https://www.nimh.nih.gov/health/publications/my-mental-health-do-i-need-help
- U.S. 988 help: https://988lifeline.org/get-help/
- FTC mobile health app privacy practices: https://www.ftc.gov/business-guidance/resources/mobile-health-app-developers-ftc-best-practices
- W3C mobile accessibility guidance: https://www.w3.org/TR/wcag2mobile-22/
- Apple health measurement claims and Kids Category rules: https://developer.apple.com/app-store/review/guidelines/
- FTC children's privacy guidance: https://www.ftc.gov/business-guidance/resources/complying-coppa-frequently-asked-questions
