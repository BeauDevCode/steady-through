# Privacy and data in Steady Through

_Last updated: November 5, 2026_

Steady Through works locally without an account, app-operated backend, analytics, advertising, in-app cloud sync or cloud emotion service. The whole app is free. Device permissions are optional; declining them leaves planning, tools, people, manual check-ins and help available. The app does not request a birth date, location permission, contacts permission or notification permission. People and phone numbers are typed in manually. Its features support personal organization and general self-help; they are not medical care or a validated stress measurement.

## Records you choose to keep

The app saves event titles and descriptions, stage actions and completion state, event check-ins (your words, optional 1–5 intensity and note), manually entered trusted people and phone numbers, appearance and reading settings, and path-game round summaries. Round summaries include counts and the feeling you select after a round. They do not contain a raw sequence of game taps.

If you choose learning sources, the vault also holds your source choices, device-owner confirmation, bounded aggregate snapshots, the feeling labels you explicitly choose, and personal calibration parameters and review results. The app does not turn clicks, app switches or possible vehicle movement into a factual emotional or medical diagnosis. A tentative comparison asks whether it fits; you choose your answer and can add a correction as a new example.

## Your passphrase-protected local vault

All app records and settings are saved in an authenticated AES-256-GCM encrypted document in the app's local support directory. Local recovery and staging copies are also encrypted. A passphrase of at least 12 characters derives the key with PBKDF2-HMAC-SHA256, 600,000 iterations and a random 16-byte salt. Each save uses a new random 12-byte nonce. Public file-format metadata, ciphertext length and filesystem metadata remain visible; record contents are encrypted.

The app does not save the passphrase and has no recovery account or server. Keep a usable passphrase and any backup you need somewhere you control. If you forget the passphrase and have no usable copy, the app cannot recover your records. A confirmed vault reset deletes known local vault and legacy files; it does not recover them. Wrong-passphrase, authentication and storage failures do not silently replace an existing vault with an empty one. An independently authenticated recovery copy can be offered with a warning that it may contain earlier records.

Readable records and a derived key necessarily exist in memory while the vault is unlocked. Locking closes the owned key object and clears its reference, but cannot guarantee erasure of every runtime or operating-system memory copy. Encryption does not protect an already compromised unlocked device or someone using your unlocked session. A privacy cover hides the app when it becomes inactive; learning sources pause. Returning after at least five minutes away requires another unlock. This is not a claim that the key is erased by a timer while the operating system suspends the app.

## Older unencrypted records

When an older local JSON document exists, creating the vault first validates it, writes the encrypted copy, authenticates it and reads it back. Only then does the app remove its known legacy JSON primary, backup and temporary files. If cleanup fails, a visible warning explains that older unencrypted copies may remain; cleanup is retried on a later unlock. A failed cleanup must not be mistaken for successful removal. Existing operating-system backups, copied JSON files and files outside those known app paths are not removed by migration.

## Optional learning sources

Every source starts off. You can enable or revoke each one independently and pause learning. System sources also require confirmation that this is your device and a separate OS grant where required. Enabling a source does not silently open its system permission prompt. Collection and queries occur only during an unlocked, active app session; locking, backgrounding, pausing or revoking consent stops the session collector. An allowed OS permission can remain in system settings after in-app consent is turned off, but the app's collector remains off. Missing, denied and unsupported readings stay unavailable rather than becoming numerical zeroes.

| Source | Scope and platform limits |
| --- | --- |
| Feeling check-ins | The feeling labels you explicitly choose in Insights. This works on all five target platforms without device permissions. A manual-only history can describe your self-reported trend without predicting your current feeling. |
| In-app activity | Aggregate counts of taps, navigation changes, backtracks and restarts inside Steady Through on all five targets. No touch locations, typed content or raw interaction trace are stored. Counts become a learning example only when you explicitly save a label. |
| Device usage on macOS | NSWorkspace application activation counts only while Steady Through is in the foreground, plus screen-awake session duration, bounded to the last 60 minutes of the collector session. This cannot observe switching among other apps and the count may stay zero. The observer does not inspect notification app identities. Duration is an open-session estimate, not an attention or idle-time measurement. |
| Device usage on Android | User-granted Usage Access allows a query of UsageStats events within the last 60 minutes. Foreground events are reduced to switch counts and observed foreground minutes. Package identifiers are used only as transient local variables to deduplicate events; no package names, app names or event lists cross into Flutter or persist. Incomplete event history can undercount. No querying occurs while this app's source is off. |
| Motion on Android | Optional Google Play services Activity Recognition, with the required separate motion grant. The adapter keeps session-only uncertain walking/vehicle duration summaries and a possible-vehicle flag. It unregisters updates on stop and discards stale session callbacks. Devices without the required Play services support report unavailable. No location API or GPS permission is used. |
| Motion on iOS | Optional Core Motion activity summaries, where supported and authorized. Historical summaries can arrive late or be incomplete; current vehicle context is also uncertain. Queries are bounded to the active session and last 60 minutes. Core Motion's change-only current classification stays in effect until a new known classification or session stop; an unknown update does not establish that vehicle movement ended. Raw Core Motion samples are not sent to Flutter or written by the app. |
| Other system sources | iOS cross-app usage is unavailable: this preview has no Family Controls entitlement or Screen Time extensions. macOS motion and Windows/Linux system usage and motion are unavailable. Manual and in-app sources still work. |

The sources do not capture app content, window titles, keystrokes, messages, screenshots, audio, GPS locations or routes. They do not operate a driving score or identify who is driving. If current motion indicates possible vehicle movement, Insights removes interactive reflection prompts and asks you to return when safely stopped; help remains reachable. There are no driving-time notifications.

Platform constraints follow the official references for [Android UsageStatsManager](https://developer.android.com/reference/android/app/usage/UsageStatsManager), [Google ActivityRecognitionClient](https://developers.google.com/android/reference/com/google/android/gms/location/ActivityRecognitionClient), [Apple NSWorkspace](https://developer.apple.com/documentation/appkit/nsworkspace), [Core Motion](https://developer.apple.com/documentation/coremotion/cmmotionactivitymanager), [change-only activity updates](https://developer.apple.com/documentation/coremotion/cmmotionactivitymanager/startactivityupdates(to:withhandler:)) and [Family Controls entitlement requests](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement). Those operating-system APIs and device services have their own behavior and privacy policies. The project does not claim that every adapter has been validated on physical hardware; see [quality status](docs/quality-status.md).

## What personal learning can say

A pattern comparison requires at least 20 labelled examples across seven different observation days, at least five examples of each of two concrete feeling labels, and at least two comparable aggregate features. Unsure remains a saved answer but is excluded from concrete training classes. Too little evidence, missing features, contradictory examples or a shifted recent pattern prevent a clear match. Matches remain tentative personal comparisons, not emotional probabilities, clinical scores or proven accuracy claims.

After about 60 days of labelled history, and at least 60 days after a prior review, a local calibration review can train on earlier examples and evaluate against later held-out examples. The same observation day cannot appear in both sets. An update is adopted only with sufficient class, day and feature coverage, improvement over a majority-label baseline, and improvement over any existing calibrated model. Otherwise the current revision stays and the report explains what is missing. No examples or model parameters are uploaded for this review.

Learning retains at most 180 days or 1,000 labelled examples, whichever limit is reached first. Other app records remain until you delete them; they are not automatically subject to the learning retention window.

## When a copy can leave the app

- **Encrypted export:** You choose a destination and a separate export passphrase. The app writes an independently encrypted `.steady` document containing the current app data. It does not export a new readable JSON copy. Other apps, file-sharing services and backups may access the encrypted file depending on where you save or share it. Anyone with its passphrase and file can read its contents. Delete exported copies separately when you no longer want them.
- **Import:** You select an encrypted `.steady` document or a legacy readable JSON file. The app authenticates or validates the entire document before asking to replace current records. Encrypted imports require that copy's passphrase. Confirmed import replaces all app data; it does not merge it. Cancelled, unauthenticated or invalid imports leave current data intact. The selected source file remains where it was chosen; importing legacy JSON does not encrypt or remove that original file.
- **Phone or text:** Tapping a contact action can hand a manually entered number to the device's phone or SMS app. Calling or texting is handled by that other app and its service provider. The number remains visible and can be copied if no handler is available.
- **Device backups:** Operating-system or file-provider backups can retain encrypted vaults, exports, and older plaintext copies independently. Their storage, sharing and deletion controls belong to that provider or device owner.

The app does not send journal entries, event details, game history, aggregate learning examples or personal model parameters to project maintainers. It includes no app-operated cloud sync or server copy.

## Deletion and clearing

You can delete a check-in, delete an event, clear game history, clear learning, or use Delete all in settings. Deleting an event also deletes its check-ins; it does not clear global game history. Successful Clear learning removes learning examples and calibration from the active vault and known local recovery copies, turns every learning source off and resets its device-owner confirmation. It keeps events, people, event check-ins and game history. If recovery-file cleanup fails, the app warns that some copies may remain so you can retry.

Delete all clears app records and checks known local temporary, backup and legacy files. A vault reset also removes the known primary encrypted vault after separate confirmation. Cleanup failures are shown instead of claiming complete deletion. Normal saves may retain the previous encrypted document for crash recovery until it is rotated or explicitly purged. These controls do not promise forensic secure erasure and do not remove exports, operating-system backups, caller/SMS records or documents outside known app paths. Uninstall behavior depends on the platform.

## Children and helpers

Simple words mode does not require a birth date. A trusted adult or helper can read along. There is no in-app chat, social feed, targeted advertising or ranking. Helpers should decide what information to enter and where to keep any export, while preserving the person's own device and source choices. See the [FTC's guidance on children's privacy](https://www.ftc.gov/business-guidance/resources/complying-coppa-frequently-asked-questions) for broader context; this document does not claim legal certification.

## Questions or changes

Open a repository issue for a privacy question or bug, but do not post real check-ins, phone numbers, passphrases, vaults, exports, learning examples or other sensitive records. Use fictional data. Privacy and safety changes should be reviewed against actual app behavior and the [FTC's mobile health app practices](https://www.ftc.gov/business-guidance/resources/mobile-health-app-developers-ftc-best-practices).

Imported archives do not carry permission to collect on a different device. System usage and motion sources are switched off on import and require fresh device-owner confirmation before re-enabling them on this device. Historical learning examples and calibration are preserved.
