# Steady Through

<img src="assets/brand/steady-through-icon.png" alt="Steady Through path and sun icon" width="96" />

Steady Through is an offline-first Flutter app for getting through a difficult life event one manageable action at a time. It runs from one codebase on Android, iOS, macOS, Windows, and Linux. There is no account or app-operated server.

The app is for personal organization and general self-help. It does not diagnose, measure stress, provide treatment, or replace emergency or professional support. In immediate physical danger, contact local emergency services. In the United States, call or text **988** for crisis support; elsewhere, use your local crisis service. See [Help from NIMH](https://www.nimh.nih.gov/health/publications/my-mental-health-do-i-need-help) and the [988 Lifeline](https://988lifeline.org/get-help/).

## What it does

- Keep several life events, choose the one to focus on, and work through five stages: Get oriented, Settle, Find support, Make a plan, and Reflect. Add, rename, complete, or remove steps. Finish, reopen, or delete an event.
- Use optional, self-paced grounding and gentle breathing tools. Grounding has Skip and Stop; breathing has Stop. Help now remains available while using a tool.
- Play an optional, untimed path game with Undo and Restart. The app can describe moves such as backtracks and offer a break. After a round, **you** choose whether it felt calm, tense, or neither. Moves alone are not a validated stress measure, diagnosis, or score. Only round summaries and your answer are kept, not a raw tap trace.
- Write event-specific check-ins in your own words, with an optional 1–5 intensity and note. Save trusted people and manually entered phone numbers; open the phone/SMS handler after a tap, or copy a number if no handler is available.
- Choose light or dark appearance and a Simple words reading style. No birth date is required. A trusted adult or helper can read along.
- Export a JSON copy, import a validated JSON file with confirmation before it replaces all app data, clear game history, or delete all local app data with confirmation.

Event check-ins are deleted with their event. Game history belongs to the person and remains until cleared separately or removed by Delete all. [Privacy and data details](PRIVACY.md) explain local storage, exports, backups, and deletion.

## App preview

The redesigned interface uses bundled typography and original route artwork. These captures use synthetic sample entries.

![Desktop Home with current event, next step, and support actions](docs/screenshots/home-desktop.png)

<img src="docs/screenshots/home-mobile.png" alt="Mobile Home" width="240" /> <img src="docs/screenshots/game-mobile.png" alt="Mobile path game" width="240" /> <img src="docs/screenshots/checkins-mobile.png" alt="Mobile check-ins" width="240" />

Regenerate visual review captures with `flutter test --update-goldens tool/capture_ui_test.dart`. The normal test suite checks navigation, persistence, errors, and layouts with long entries at 320 and 1200 pixels with 200% text.

## Set up locally

Install [Flutter 3.47.9](https://docs.flutter.dev/install/archive), verify the required platform toolchain with `flutter doctor -v`, then run:

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

`flutter run` needs a connected device, simulator, emulator, or supported desktop host. Android development requires an Android SDK. iOS and macOS builds require macOS and Xcode. Windows desktop builds require Visual Studio with the Desktop development with C++ workload. Linux desktop builds require `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`, and `libstdc++-12-dev`. See Flutter's [platform setup](https://docs.flutter.dev/platform-integration), [Windows setup](https://docs.flutter.dev/platform-integration/windows/setup), and [Linux setup](https://docs.flutter.dev/platform-integration/linux/setup).

## Build by platform

Run these commands from the repository root after `flutter pub get`, on a host with that platform's toolchain:

| Target | Command | Output and scope |
| --- | --- | --- |
| Android | `flutter build apk --release` | `build/app/outputs/flutter-apk/app-release.apk`; this project does not provide a Play upload key. The generated development signing configuration may sign this APK with a debug key. |
| iOS simulator | `flutter build ios --simulator --debug` | `build/ios/iphonesimulator/Runner.app`; a debug simulator app, not an iPhone install package. |
| macOS | `flutter build macos --release` | App bundle in `build/macos/Build/Products/Release/`; no distribution certificate or notarization is supplied. |
| Windows | `flutter build windows --release` | Bundle in `build/windows/x64/runner/Release/`; keep the executable, DLLs, and data together. |
| Linux | `flutter build linux --release` | Bundle in `build/linux/x64/release/bundle/`; keep the executable and data together. |

GitHub Actions runs analysis and tests on Ubuntu, then builds the Android APK on Ubuntu, the iOS simulator and macOS apps on macOS, the Windows app on Windows, and the Linux app on Ubuntu. It uploads clearly labeled CI artifacts. A successful build is a compilation check, not a device usability test, medical validation, store approval, or signed release. App Store/TestFlight distribution needs an Apple developer setup and signing; Play distribution needs a release signing key and a store-ready bundle. Review Flutter's [Android release](https://docs.flutter.dev/deployment/android) and [iOS release](https://docs.flutter.dev/deployment/ios) guides before distribution.

## Source basis and limits

The tools use original wording informed by the [WHO guide to stress self-help](https://www.who.int/thailand/activities/doing-what-matters-in-times-of-stress). [NIMH guidance](https://www.nimh.nih.gov/health/publications/my-mental-health-do-i-need-help) informs the recommendation to seek professional help when distress worsens or interferes with daily life. The U.S. crisis option is based on the [988 Lifeline](https://988lifeline.org/get-help/). These sources do not validate this app's game, check-ins, or exercises as clinical instruments. The app does not infer a medical state from play.

The privacy approach draws on [FTC mobile health app practices](https://www.ftc.gov/business-guidance/resources/mobile-health-app-developers-ftc-best-practices). Accessibility work draws on [W3C guidance for mobile apps](https://www.w3.org/TR/wcag2mobile-22/), which is informative guidance rather than a certification. Any future store release must also be reviewed against [Apple's App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) and applicable platform rules.

Game-based stress research is still limited for this use. A [controlled adult study](https://www.sciencedirect.com/science/article/pii/S2451958826002502) found a signal in one cognitive-game measure but cautioned that real-world performance may be lower. Another [adult gameplay study](https://pubmed.ncbi.nlm.nih.gov/41322085/) found age-related effects. Neither validates this app's path game as a stress measure across children and older adults. The app therefore treats moves as a prompt for reflection and relies on the player's own answer.

## Contributing and license

See [CONTRIBUTING.md](CONTRIBUTING.md) for development and review expectations. Source code is available under the [MIT License](LICENSE).

The bundled [Manrope typeface](https://github.com/google/fonts/tree/main/ofl/manrope) uses the SIL Open Font License; its license is included in `assets/fonts/OFL-Manrope.txt`. Fonts and original route artwork are available offline.
