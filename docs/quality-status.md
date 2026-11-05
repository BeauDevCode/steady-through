# Quality status

The releases are development previews. A successful build and automated test run are useful evidence, but the app still needs practical testing with people and physical devices before a store release.

## Verified in the design refresh

- All 89 model, storage, controller, game and widget tests passed locally.
- Layouts with long entries passed at 320 and 1200 logical pixels with 200% text.
- Small secondary text passes a 4.5:1 contrast check on light/dark card surfaces.
- Ten screenshots were generated using the bundled fonts and synthetic data; Home, Path, Tools, game, Check-ins, People and Settings were visually inspected.
- An independent read-only review checked navigation, saved-data controls, game accessibility and the rendered design. Its contrast finding was fixed with a regression test.
- Five-platform CI and a macOS native walkthrough are required before publishing this preview.

## Still required before a general store release

- Run complete flows on physical iOS and Android devices, including native file dialogs, phone/SMS handoff, background/resume, rotation, keyboard and accessibility settings.
- Perform VoiceOver and TalkBack walkthroughs and keyboard-only checks on the native apps.
- Perform Windows and Linux native usability checks in addition to compilation.
- Observe people using the guidance, including caregivers/helpers and older adults, and revise unclear steps. Automated tests do not establish whether the guidance is understandable for every age.
- Configure distribution signing, Apple notarization and store records, then test the signed packages through their distribution channels.

The path game reflects observable moves and the player's own answer. Its behavior is not a validated stress measurement and has not been tested as a clinical instrument.
