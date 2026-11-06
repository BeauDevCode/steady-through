# iOS packages and distribution handoff

## Current 1.5.0 work in progress — CI and publication pending

Working **1.5.0+9**, intended tag **v1.5.0-preview.1**, has not yet completed exact-source CI, native execution, device archive validation or publication. There is no verified public 1.5 package/download at this stage. The expected working-source identity is **1.5.0/build 9**, not evidence that a binary has been built or inspected. [Quality status](quality-status.md#current-150-work-in-progress--ci-and-publication-pending) and [1.5 decisions](releases/1.5.0-decisions.md) retain the pending gates.

Quick support uses existing encrypted people/actions with schema **4/read 1/2/3/4** and no new permission, adapter or learning input. The extended encrypted backup fixture covers edited fictional people/cleared phone/stable ID/order and the focused-completion API; native execution remains pending CI and does not cover native handoff dialogs or focused-route navigation. **Local verification passed:** 413 Flutter tests, 88 Python CI-helper tests, no analyzer issues, and 109 Dart files format-checked with no changes. All three capture profiles passed; all 24 generated fictional actual-widget PNGs were visually inspected. These renderings do not validate native accessibility. Fresh whole-branch review remains pending. These local results do not establish Simulator or physical-device execution. Physical iPhone execution, grants, real OS dialogs, VoiceOver, owner signing/provisioning and efficacy remain unexecuted. A future unsigned device archive still will not be installable.

<a id="current-140-preview--verified-packages-unsigned-device-output"></a>

## Published 1.4.0 preview — historical verified packages, unsigned device output

**[v1.4.0-preview.1](https://github.com/BeauDevCode/steady-through/releases/tag/v1.4.0-preview.1) /1.4.0+8** is published from exact tested source `a0a12ecc7badf359411e520b21a4081dcd06854d`. All seven jobs passed in [run 42308127205](https://github.com/BeauDevCode/steady-through/actions/runs/42308127205); the iOS Simulator ran all three native cases. All 13 artifact ZIPs, six package payloads and ten public assets passed source/hash/size checks and anonymous access. Apple app metadata reports 1.4.0/build 8. The device archive has 82 members and four actual arm64/platform 2 images, with minimum 15.0, Xcode 26.5/SDK 26.5 and required native/privacy resources verified independently. See [quality status](quality-status.md#current-140-preview--verified-evidence).

**The device ZIP remains unsigned, not installable and physically untested.** It supplies production compilation/package evidence. A future owner-signed archive/IPA, provisioning and physical iPhone test remain separate. Simulator success is not physical-device execution. Real permission/file dialogs, VoiceOver, signing/notarization and outcomes remain unexecuted.

Schema 4 adds optional encrypted ratings/settings and reads validated 1/2/3/4. Older apps supporting only up to 3 cannot read new 4 files; preserve an earlier backup if a return is needed. [Implementation decisions](releases/1.4.0-decisions.md) and 28 synthetic [feedback captures](screenshots/what-helps/) describe the feature without effectiveness claims.

## Historical 1.3 published package reference

The earlier **1.3.0+7 / [v1.3.0-preview.1](https://github.com/BeauDevCode/steady-through/releases/tag/v1.3.0-preview.1)** packages passed all seven jobs and device-package/archive checks on exact source `3dd1fe72dfceb1f9d7ae5716a479c11e2faff65f`; the [quality record](quality-status.md#current-130-preview--verified-evidence) records the observed evidence and limits. Commands below remain instructions; future signing and physical steps have not been performed.

## Choose the right output

Public filenames in this table refer to the historical 1.4 release. The 1.5 source has no verified published package yet.

| Output | Build and package | What it establishes |
| --- | --- | --- |
| iOS Simulator | `flutter build ios --simulator --debug`; `build/ios/iphonesimulator/Runner.app`; public `steady-through-1.4.0-preview.1-ios-simulator.zip` | Debug app for a compatible Simulator. The existing Simulator job separately checks its selected available runtime, boot readiness and three actual native cases. It is not an iPhone package. |
| Unsigned iPhoneOS Release | `flutter build ios --release --no-codesign --target lib/main.dart`; `build/ios/iphoneos/Runner.app`; public `steady-through-1.4.0-preview.1-ios-device-release-unsigned.zip` | Device-targeted production compilation and validated package contents only. **Unsigned, not installable, not physically validated.** It is an app ZIP, not a signed Xcode archive or IPA. |
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

For the working 1.5 source, expected app metadata includes `com.beaudevcode.steadyThrough`, display/name `Steady Through`, executable `Runner`, **1.5.0/build 9**, iPhoneOS/`iphoneos`, and minimum iOS 15.0. This is an expected identity; 1.5 binary inspection is pending. The verifier also checks embedded frameworks and Mach-O slices, bundled icons/storyboards/fonts/assets, active `objective_c` native-asset mapping, pinned plugin privacy resources, absence of root signing/provisioning artifacts and absence of known test/debug fixture content. Read the actual JSON and build log; a ZIP existing on disk is insufficient.

The `iPhoneOS Release (macOS, unsigned, not installable)` job preserves two CI artifacts:

- `ios-device-release-unsigned-not-installable`: contains `steady-through-ios-device-release-unsigned-ci.zip`.
- `ios-device-release-evidence`: contains `ios-device-release-build.log`, `ios-device-release-toolchain.json`, `ios-device-release-provenance.json` and `ios-device-release-validation.json` from `build/`.

A failed job may upload partial evidence; artifact presence does not establish success. The provenance records the source, repository, run/attempt, production command, disabled code signing and toolchain. Local commands above do not fabricate a GitHub source/run identity. Retain local source/toolchain observations separately, and use the actual CI provenance for a release.

The historical 1.4 public device filename is **`steady-through-1.4.0-preview.1-ios-device-release-unsigned.zip`**. Staging preserved the validated CI ZIP bytes and mapped its original filename in build information. The release has six app packages plus BUILD-INFO, checksums, Android JUnit and native-runtime-reports.zip (ten assets). The report ZIP includes the four device evidence files and source verifiers. Public tag/main equivalence, anonymous downloads and all server hashes/sizes are checked separately from package/native execution.

## Future owner-controlled signing and physical iPhone work

These steps have **not** been performed. The owner must choose and configure their own Apple Team, signing certificate/private key and provisioning profile for the intended method. Do not commit credentials, a Team ID invented for this project, a placeholder provisioning profile or an export-options file copied from another account. Apple account authentication, membership/payment, license acceptance, device registration and any store record or submission remain owner actions. This repository provides none of them.

Once the owner has made those choices, open `ios/Runner.xcworkspace`, select **Runner → Signing & Capabilities**, and choose the owner's Team and provisioning. Review the bundle identifier, capabilities, iOS minimum and version/build. No Family Controls entitlement or Screen Time extension is configured. Follow the [official Flutter iOS release guide](https://docs.flutter.dev/deployment/ios#review-xcode-project-settings) for these settings.

After signing is configured, a separate local build can be requested with:

```sh
flutter build ipa --release --target lib/main.dart
```

Flutter produces an Xcode archive under `build/ios/archive/` and an IPA under `build/ios/ipa/` when export succeeds. Use the actual resulting archive in Xcode Organizer to validate the chosen signing/export method. Keep its source, toolchain, signing method, version/build, validation result and hashes as separate evidence. Do not rename an unsigned preview ZIP to `.ipa` or treat its directory validator as validation of a signed export. See Flutter's [archive and IPA instructions](https://docs.flutter.dev/deployment/ios#create-an-app-bundle); this guide performs no upload or store submission.

Install only an appropriately signed build through the owner's selected authorized test method on a test-owned physical iPhone. Keep the existing locked vault until a backup has been checked on another installation. Use fictional data and follow the [manual device guide](device-validation.md), including passphrase-help dismissal and reset cancellation, actual backup dialogs, keyboard/200% text, VoiceOver, lock/background/resume, and optional permission denial/revocation. Record physical model/OS, install method, source/build and observed results. Leave every optional source off for the basic support flow. Physical grants and collector behavior require their own explicit checks; neither this handoff nor a Simulator pass establishes them.
