# iOS packages and distribution handoff

This guide describes the published **1.2.1+6 / [v1.2.1-preview.1](https://github.com/BeauDevCode/steady-through/releases/tag/v1.2.1-preview.1)** packages. All seven jobs and device-package/archive checks passed on exact source `0f62db5ee2ba0e0769273de5872b1214ea6bafc5`; the [quality record](quality-status.md#current-121-preview--verified-evidence) records the observed evidence and limits. Commands below remain instructions; the future signing and physical steps have not been performed.

## Choose the right output

| Output | Build and package | What it establishes |
| --- | --- | --- |
| iOS Simulator | `flutter build ios --simulator --debug`; `build/ios/iphonesimulator/Runner.app`; public `steady-through-1.2.1-preview.1-ios-simulator.zip` | Debug app for a compatible Simulator. The existing Simulator job separately checks its selected available runtime, boot readiness and three actual native cases. It is not an iPhone package. |
| Unsigned iPhoneOS Release | `flutter build ios --release --no-codesign --target lib/main.dart`; `build/ios/iphoneos/Runner.app`; public `steady-through-1.2.1-preview.1-ios-device-release-unsigned.zip` | Device-targeted production compilation and validated package contents only. **Unsigned, not installable, not physically validated.** It is an app ZIP, not a signed Xcode archive or IPA. |
| Future signed archive/IPA | A separately generated `.xcarchive` and `.ipa`, after the owner supplies an Apple Team, valid signing identity and provisioning for the chosen distribution method | A separate signing/distribution result that must be validated and tested on a physical iPhone. Neither preview ZIP supplies it. |

The new device job does not replace Simulator execution. An arm64 slice can belong to a Simulator: the device validator requires **every Mach-O slice to declare platform 2 / iOS**, alongside arm64, appropriate executable types and deployment metadata. Its current app minimum is iOS 15.0. These are package checks; they do not prove behavior on all supported hardware or OS versions.

## Build and verify the unsigned device package

Use a macOS host with the required toolchain already installed. CI pins **Flutter 3.47.9**, **Xcode 26.5**, **iPhoneOS SDK 26.5**, Python 3.13 and `DEVELOPER_DIR=/Applications/Xcode_26.5.app/Contents/Developer` on macOS 26. Confirm your host matches before comparing results; do not accept a mismatching toolchain as equivalent evidence. From the repository root, in a fresh build session:

```sh
export DEVELOPER_DIR=/Applications/Xcode_26.5.app/Contents/Developer
flutter --version --machine
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version
flutter pub get
mkdir -p build
```

Run the production build in Bash so a failed build cannot be hidden by the logging pipe:

```bash
set -o pipefail
flutter build ios --release --no-codesign --target lib/main.dart 2>&1 | tee build/ios-device-release-build.log
```

Then follow the workflow's directory-before-archive order. Use Python 3 (`python` in CI; `python3` below):

```sh
python3 tool/ci/verify_ios_device_bundle.py build/ios/iphoneos/Runner.app --pubspec pubspec.yaml --report build/ios-device-release-validation.json
ditto -c -k --keepParent --norsrc --noextattr --noqtn build/ios/iphoneos/Runner.app steady-through-ios-device-release-unsigned-ci.zip
python3 tool/ci/verify_ios_device_bundle.py build/ios/iphoneos/Runner.app --pubspec pubspec.yaml --report build/ios-device-release-validation.json --archive steady-through-ios-device-release-unsigned-ci.zip
shasum -a 256 steady-through-ios-device-release-unsigned-ci.zip
```

The first verifier creates the report and refuses to overwrite an existing report. Keep that baseline unchanged and do not rebuild or modify `Runner.app` between validation and archive verification. The second verifier requires the prior report, revalidates the directory against it and checks exact ZIP membership, types, modes, lengths and file hashes. On success it adds the archive's name, size, SHA-256 and member count to the report. If a check fails, preserve the failed report/log/archive for diagnosis; do not delete or rewrite the baseline to make a changed bundle appear to match. A new build needs a separately preserved build/evidence session.

Expected app metadata includes `com.beaudevcode.steadyThrough`, display/name `Steady Through`, executable `Runner`, **1.2.1/build 6**, iPhoneOS/`iphoneos`, and minimum iOS 15.0. The verifier also checks embedded frameworks and Mach-O slices, bundled icons/storyboards/fonts/assets, active `objective_c` native-asset mapping, pinned plugin privacy resources, absence of root signing/provisioning artifacts and absence of known test/debug fixture content. Read the actual JSON and build log; a ZIP existing on disk is insufficient.

The `iPhoneOS Release (macOS, unsigned, not installable)` job preserves two CI artifacts:

- `ios-device-release-unsigned-not-installable`: contains `steady-through-ios-device-release-unsigned-ci.zip`.
- `ios-device-release-evidence`: contains `ios-device-release-build.log`, `ios-device-release-toolchain.json`, `ios-device-release-provenance.json` and `ios-device-release-validation.json` from `build/`.

A failed job may upload partial evidence; artifact presence does not establish success. The provenance records the source, repository, run/attempt, production command, disabled code signing and toolchain. Local commands above do not fabricate a GitHub source/run identity. Retain local source/toolchain observations separately, and use the actual CI provenance for a release.

The public device filename is **`steady-through-1.2.1-preview.1-ios-device-release-unsigned.zip`**. Release staging must preserve the validated CI ZIP bytes, map its original name to the public name in build information and compare hashes. The published release has six app packages plus `BUILD-INFO.txt`, `SHA256SUMS.txt`, `android-motion-unit-results.xml` and `native-runtime-reports.zip` (ten assets); the report ZIP includes the four device evidence files alongside the original native reports. Public main/tag, anonymous downloads and all server hashes/sizes must be observed before publication is recorded as complete.

## Future owner-controlled signing and physical iPhone work

These steps have **not** been performed. The owner must choose and configure their own Apple Team, signing certificate/private key and provisioning profile for the intended method. Do not commit credentials, a Team ID invented for this project, a placeholder provisioning profile or an export-options file copied from another account. Apple account authentication, membership/payment, license acceptance, device registration and any store record or submission remain owner actions. This repository provides none of them.

Once the owner has made those choices, open `ios/Runner.xcworkspace`, select **Runner → Signing & Capabilities**, and choose the owner's Team and provisioning. Review the bundle identifier, capabilities, iOS minimum and version/build. No Family Controls entitlement or Screen Time extension is configured. Follow the [official Flutter iOS release guide](https://docs.flutter.dev/deployment/ios#review-xcode-project-settings) for these settings.

After signing is configured, a separate local build can be requested with:

```sh
flutter build ipa --release --target lib/main.dart
```

Flutter produces an Xcode archive under `build/ios/archive/` and an IPA under `build/ios/ipa/` when export succeeds. Use the actual resulting archive in Xcode Organizer to validate the chosen signing/export method. Keep its source, toolchain, signing method, version/build, validation result and hashes as separate evidence. Do not rename an unsigned preview ZIP to `.ipa` or treat its directory validator as validation of a signed export. See Flutter's [archive and IPA instructions](https://docs.flutter.dev/deployment/ios#create-an-app-bundle); this guide performs no upload or store submission.

Install only an appropriately signed build through the owner's selected authorized test method on a test-owned physical iPhone. Keep the existing locked vault until a backup has been checked on another installation. Use fictional data and follow the [manual device guide](device-validation.md), including passphrase-help dismissal and reset cancellation, actual backup dialogs, keyboard/200% text, VoiceOver, lock/background/resume, and optional permission denial/revocation. Record physical model/OS, install method, source/build and observed results. Leave every optional source off for the basic support flow. Physical grants and collector behavior require their own explicit checks; neither this handoff nor a Simulator pass establishes them.
