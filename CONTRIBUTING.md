# Contributing to Steady Through

Thank you for helping make Steady Through clearer and more reliable. Keep changes small enough to review and explain the behavior they change.

## Development checks

Use Flutter **3.47.9** and the native toolchain for the platform you are testing. From the repository root:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Build on the relevant host with the commands in [README.md](README.md). GitHub Actions also compiles all five platform targets; its artifacts are development outputs, not signed store releases. Note the exact platform and whether you ran on a device, simulator, or only compiled. Do not mark a platform tested on a device based on a successful build alone.

## Changes that need particular care

- Keep the app usable offline without accounts, analytics, advertising, or personal-data transmission. Do not add permissions or data collection without explaining the need and updating [PRIVACY.md](PRIVACY.md).
- Treat game moves as observable actions within a game. Do not claim they measure stress, diagnose a condition, or support a clinical score. Ask the player how a round felt before tailoring a suggestion. Avoid saving raw tap traces.
- Keep Help now reachable during tools and game play. Label 988 as a U.S. option and direct people elsewhere to local services. Keep Stop visible on exercises and Skip visible in grounding. Do not require breath holding, closed eyes, or rapid/deep breathing.
- Preserve import safety: validate the complete file before asking to replace local data. Invalid or canceled imports must leave existing data untouched. Confirm full replacement, delete-all, and game-history clearing.
- Test large text, screen readers, keyboard focus, narrow layouts, light/dark appearance, and phone/SMS fallback where the platform has no handler. [W3C mobile accessibility guidance](https://www.w3.org/TR/wcag2mobile-22/) is a useful review reference.
- Use original copy and cite authoritative sources for health, crisis, privacy, or platform claims. The [WHO stress guide](https://www.who.int/thailand/activities/doing-what-matters-in-times-of-stress), [NIMH help guidance](https://www.nimh.nih.gov/health/publications/my-mental-health-do-i-need-help), and [988 Lifeline](https://988lifeline.org/get-help/) inform the current content; they do not endorse this app.

## Pull requests and issues

Include a short description, the reason for the change, commands run and their results, and any platform limitation. Add focused tests for behavior changes. Never commit signing credentials, tokens, real user records, JSON exports, or private contact information. Use fictional sample data in issues and tests. For a security or privacy concern, describe a minimal reproduction without exposing someone's data.

Contributions are licensed under the [MIT License](LICENSE).
