# iOS packages and distribution handoff

<a id="current-151-work-in-progress--verification-and-publication-pending"></a>

## Current 1.5.1 work in progress — verification and publication pending

Working **1.5.1+10**, intended preview **v1.5.1-preview.1**, has no verified 1.5.1 public package, source SHA or CI run yet. **Final local verification passed:** 465 Flutter tests, 94 Python CI-helper tests, no analyzer issues, and 115 Dart files format-checked with no changes. All 21 regenerated fictional actual-widget captures passed and were inspected across seven scenes/three profiles, including a full-size narrow backup view. Three layout regressions cover setup and backup Confirm passphrase plus Optional description at 320px/200% text. The full 12-character backup helper was separately observed RED within the same backup test, then passed after allowing three helper lines; this adds no fourth layout test. The final labels/helper wrap in full. These captures do not validate native assistive technology or establish a pixel-comparison run.

The first macOS attempt passed three cases and failed the legacy lock/unlock case after a real resumed-to-inactive transition; the new fourth rendered journey passed in 32.8s and backup passed. An unattended rerun also received real inactive/hidden transitions without computer use and stalled on the second case. Root stopped its own run; its zero exit and incomplete case report are not a pass. No source defect was demonstrated and no full four-case macOS pass is claimed. All four cases on all five runtimes remain an exact-source CI gate, with lifecycle and fatal hit-test checks intact. No iOS Simulator pass is claimed for 1.5.1. Fresh whole-branch review, all-runtime native CI, device package validation and publication remain pending. See [current quality status](quality-status.md#current-151-work-in-progress--verification-and-publication-pending) and [1.5.1 decisions](releases/1.5.1-decisions.md).

For iPhone, the owner explicitly selected **Source and Simulator for now**. Owner signing/provisioning and physical installation are outside this software-completion target. Any unsigned iPhoneOS archive is package evidence only: **unsigned, not installable and physically untested**. The separate unsigned device job remains required as production compilation/archive evidence; it does not create an installable signed app. Do not invent an Apple Team, signing identity, provisioning or physical-install result. Schema **4/read 1/2/3/4**, the encryption envelope/KDF, dependencies, native adapters, source permissions and learning thresholds remain unchanged. The app stays free/offline with every source off.

The four-case native contract adds a visible default Gate/screens journey using owned real encrypted disk storage and fresh Gate/Store authenticated reopen. Its mutations use visible controls; assertions do not substitute controller writes for UI. It does not execute native contact/clipboard handoffs, OS dialogs, sensors/grants or native assistive technology, and does not call production main(), use personal app storage, install a release or restart the process. The verified 1.5 packages and metadata below remain historical, not 1.5.1 evidence.

<a id="current-150-work-in-progress--ci-and-publication-pending"></a>

<a id="current-150-preview--published-and-verified"></a>

## Published 1.5.0 preview — historical verified evidence

Published **[v1.5.0-preview.1](https://github.com/BeauDevCode/steady-through/releases/tag/v1.5.0-preview.1) /1.5.0+9** uses exact tagged source `5b9b661ce8e16dada74079f8e5b1bb675325dfde` under [CI run 42315634394](https://github.com/BeauDevCode/steady-through/actions/runs/42315634394), attempt 1. All seven jobs passed: 415 Flutter tests, 88 Python CI-helper tests, 12 Android JUnit tests and all three original native cases on each of five runtimes, including iOS Simulator. Thirteen outer artifact ZIPs/six complete package payloads and all ten public assets passed source/hash/size checks; exact draft/public body and anonymous repository/release/download access were verified.

Apple binary metadata confirms **1.5.0/build 9**. The separate device archive has **82 members and four actual arm64/platform 2 images**, minimum iOS 15.0, with exact-source archive helpers, native/privacy resources and Xcode 26.5/SDK 26.5 checks passed. **It remains unsigned, not installable and physically untested.** The encrypted native backup case passed with edited fictional people/cleared phone/stable ID/order, focused-completion API persistence, ratings and other records/settings; it does not execute native contact handoffs or Help/People/focus navigation.

Schema **4/read 1/2/3/4**, permissions, adapters and learning remain unchanged. Local analyzer reported no issues, 109 Dart files needed no formatting changes, and all 24 fictional actual-widget captures were inspected across three passing profiles. Whole-branch review and one regression-verified fix pass completed for pending Add/Edit input loss: fields are read-only only while saving, Cancel remains available and failure restores editing/retry. Captures show non-saving states, with no new pixel comparison or native accessibility result inferred. Physical iPhone execution/grants, real OS dialogs, VoiceOver, owner signing/provisioning and efficacy remain unexecuted. Public-main ancestry and documentation-only equivalence were verified at the observation recorded in the [publication snapshot](releases/1.5.0-publication.json); later documentation-only records preserve the tested application source. See [verified quality status](quality-status.md#current-150-preview--verified-evidence) and [1.5 decisions](releases/1.5.0-decisions.md).

<a id="current-140-preview--verified-packages-unsigned-device-output"></a>

## Published 1.4.0 preview — historical verified packages, unsigned device output

**[v1.4.0-preview.1](https://github.com/BeauDevCode/steady-through/releases/tag/v1.4.0-preview.1) /1.4.0+8** is published from exact tested source `a0a12ecc7badf359411e520b21a4081dcd06854d`. All seven jobs passed in [run 42308127205](https://github.com/BeauDevCode/steady-through/actions/runs/42308127205); the iOS Simulator ran all three native cases. All 13 artifact ZIPs, six package payloads and ten public assets passed source/hash/size checks and anonymous access. Apple app metadata reports 1.4.0/build 8. The device archive has 82 members and four actual arm64/platform 2 images, with minimum 15.0, Xcode 26.5/SDK 26.5 and required native/privacy resources verified independently. See [quality status](quality-status.md#current-140-preview--verified-evidence).

**The device ZIP remains unsigned, not installable and physically untested.** It supplies production compilation/package evidence. A future owner-signed archive/IPA, provisioning and physical iPhone test remain separate. Simulator success is not physical-device execution. Real permission/file dialogs, VoiceOver, signing/notarization and outcomes remain unexecuted.

Schema 4 adds optional encrypted ratings/settings and reads validated 1/2/3/4. Older apps supporting only up to 3 cannot read new 4 files; preserve an earlier backup if a return is needed. [Implementation decisions](releases/1.4.0-decisions.md) and 28 synthetic [feedback captures](screenshots/what-helps/) describe the feature without effectiveness claims.

## Historical 1.3 published package reference

The earlier **1.3.0+7 / [v1.3.0-preview.1](https://github.com/BeauDevCode/steady-through/releases/tag/v1.3.0-preview.1)** packages passed all seven jobs and device-package/archive checks on exact source `3dd1fe72dfceb1f9d7ae5716a479c11e2faff65f`; the [quality record](quality-status.md#current-130-preview--verified-evidence) records the observed evidence and limits. Commands below remain instructions; future signing and physical steps have not been performed.

## Choose the right output

Public filenames in this table refer to the verified historical 1.5 release; no verified 1.5.1 package is available yet. The historical 1.4 evidence above remains tied to its own source.

| Output | Build and package | What it establishes |
| --- | --- | --- |
| iOS Simulator | `flutter build ios --simulator --debug`; `build/ios/iphonesimulator/Runner.app`; public `steady-through-1.5.0-preview.1-ios-simulator.zip` | Debug app for a compatible Simulator. The existing Simulator job separately checks its selected available runtime, boot readiness and three actual native cases. It is not an iPhone package. |
| Unsigned iPhoneOS Release | `flutter build ios --release --no-codesign --target lib/main.dart`; `build/ios/iphoneos/Runner.app`; public `steady-through-1.5.0-preview.1-ios-device-release-unsigned.zip` | Device-targeted production compilation and validated package contents only. **Unsigned, not installable, not physically validated.** It is an app ZIP, not a signed Xcode archive or IPA. |
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

The verified published 1.5 binary metadata includes `com.beaudevcode.steadyThrough`, display/name `Steady Through`, executable `Runner`, **1.5.0/build 9**, iPhoneOS/`iphoneos`, and minimum iOS 15.0. The binary identity and complete package were independently reinspected. The verifier also checks embedded frameworks and Mach-O slices, bundled icons/storyboards/fonts/assets, active `objective_c` native-asset mapping, pinned plugin privacy resources, absence of root signing/provisioning artifacts and absence of known test/debug fixture content. Read the actual JSON and build log; a ZIP existing on disk is insufficient.

The `iPhoneOS Release (macOS, unsigned, not installable)` job preserves two CI artifacts:

- `ios-device-release-unsigned-not-installable`: contains `steady-through-ios-device-release-unsigned-ci.zip`.
- `ios-device-release-evidence`: contains `ios-device-release-build.log`, `ios-device-release-toolchain.json`, `ios-device-release-provenance.json` and `ios-device-release-validation.json` from `build/`.

A failed job may upload partial evidence; artifact presence does not establish success. The provenance records the source, repository, run/attempt, production command, disabled code signing and toolchain. Local commands above do not fabricate a GitHub source/run identity. Retain local source/toolchain observations separately, and use the actual CI provenance for a release.

The current public device filename is **`steady-through-1.5.0-preview.1-ios-device-release-unsigned.zip`**. Staging preserved the validated CI ZIP bytes and mapped its original filename in build information. The release has six app packages plus BUILD-INFO, checksums, Android JUnit and native-runtime-reports.zip (ten assets). The report ZIP includes the four device evidence files and source verifiers. The exact tag/source, anonymous downloads and all server hashes/sizes are verified separately from package/native execution. Public-main ancestry and documentation-only equivalence were verified at the observation recorded in the [publication snapshot](releases/1.5.0-publication.json); later documentation-only records preserve the tested application source.

## Future owner-controlled signing and physical iPhone work

These steps have **not** been performed. The owner must choose and configure their own Apple Team, signing certificate/private key and provisioning profile for the intended method. Do not commit credentials, a Team ID invented for this project, a placeholder provisioning profile or an export-options file copied from another account. Apple account authentication, membership/payment, license acceptance, device registration and any store record or submission remain owner actions. This repository provides none of them.

Once the owner has made those choices, open `ios/Runner.xcworkspace`, select **Runner → Signing & Capabilities**, and choose the owner's Team and provisioning. Review the bundle identifier, capabilities, iOS minimum and version/build. No Family Controls entitlement or Screen Time extension is configured. Follow the [official Flutter iOS release guide](https://docs.flutter.dev/deployment/ios#review-xcode-project-settings) for these settings.

After signing is configured, a separate local build can be requested with:

```sh
flutter build ipa --release --target lib/main.dart
```

Flutter produces an Xcode archive under `build/ios/archive/` and an IPA under `build/ios/ipa/` when export succeeds. Use the actual resulting archive in Xcode Organizer to validate the chosen signing/export method. Keep its source, toolchain, signing method, version/build, validation result and hashes as separate evidence. Do not rename an unsigned preview ZIP to `.ipa` or treat its directory validator as validation of a signed export. See Flutter's [archive and IPA instructions](https://docs.flutter.dev/deployment/ios#create-an-app-bundle); this guide performs no upload or store submission.

Install only an appropriately signed build through the owner's selected authorized test method on a test-owned physical iPhone. Keep the existing locked vault until a backup has been checked on another installation. Use fictional data and follow the [manual device guide](device-validation.md), including passphrase-help dismissal and reset cancellation, actual backup dialogs, keyboard/200% text, VoiceOver, lock/background/resume, and optional permission denial/revocation. Record physical model/OS, install method, source/build and observed results. Leave every optional source off for the basic support flow. Physical grants and collector behavior require their own explicit checks; neither this handoff nor a Simulator pass establishes them.
