# Manual device validation guide

This is a checklist for a future human walkthrough of Steady Through. **No checks in this guide are claimed as executed or passed.** Record
results separately for Android, iOS, macOS, Windows, and Linux; a build or automated native smoke test is not a substitute for these
observations. Use the source commit and build under review, not an older preview. The published preview is **1.2.1+6**; its automated CI/package/publication evidence is in [quality status](quality-status.md#current-121-preview--verified-evidence). This manual checklist remains unexecuted. The unsigned iPhoneOS ZIP cannot be installed; physical iPhone testing first requires the separate owner-signed build described in the [iOS distribution handoff](ios-distribution.md).

## Set up a safe test session

- Use a test-owned device, simulator, or isolated account/profile with no personal Steady Through records. Do not reset or uninstall an existing
  vault that contains real data.
- Enter only fictional events, names, check-ins, and phone numbers. Use test-only vault and export passphrases; keep them out of screenshots,
  logs, issues, and this result record. Do not upload an export or device recording containing real records.
- Keep the test offline when checking the basic support flow. Confirm the app opens without an account, payment, subscription, or required device
  permission.
- Record the OS, device/model, app build, source SHA, and any relevant accessibility settings before starting. Mark each check **Pass**,
  **Fail**, **Not run**, or **Unavailable**; attach a short observation for anything other than Pass.
- Use the app's ordinary UI and native file dialogs. The CI suite's file gateway and scripted confirmation callbacks do not validate those
  dialogs.

## Core flow on each of the five platforms

1. **Create and reopen the vault.** On a fresh test profile, enter a test-only passphrase of at least 12 characters in **Passphrase** and
   **Confirm passphrase**, then choose **Create private vault**. Confirm Home opens and **Insights** shows all four sources off. If Motion & Fitness or another source permission appears before your explicit action, record a failed consent check rather than accepting it to proceed. Create a small
   fictional event as a persistence marker. Use **Lock vault** from the app header or **More**; enter a wrong passphrase and confirm the vault
   stays closed with an error. Retry the correct passphrase and confirm the marker remains.
2. **Check privacy on app switching.** While unlocked, switch away or background the app and inspect the app switcher/desktop transition for the
   privacy cover. Return before five minutes and check that content reappears only when active. Repeat after at least five minutes away; return
   and confirm **Unlock vault** is required. Note actual OS lifecycle behavior, especially if a desktop window remains visible while another app
   is focused.
3. **Create and navigate an event.** On Home choose **Create event** and add a fictional title. Choose a guide voluntarily, then choose any starter steps, including none. Check General, School & growing up, Adult life changes, Caring for someone, and Later life changes without entering a birth date or helper account. Cancel each picker once and confirm prior choices remain. Confirming the same guide must preserve the selected steps; a different guide starts with its five suggestions selected. In **Path**, confirm the five stages—**Get
   oriented**, **Settle**, **Find support**, **Make a plan**, **Reflect**—and the selected actions. A zero-step event should invite adding a step rather than say the work is done. Finish the earliest action, add a new
   unfinished action to an earlier stage, then check Home and Path recommend that earliest unfinished stage. Rename, finish, and remove an
   action; add selected suggestions from **Choose starter steps**, checking that existing matches, including done steps, are unavailable. Change the event's guide and confirm saved edits, done states and check-ins remain. Create a second event with another guide and use **Switch event**; Home and Path must reflect that event's own guide.
4. **Use support without Insights consent.** Open **Tools** for grounding (**Skip** and **Stop**), gentle breathing (**Stop**), and the untimed
   **Path game** (**Undo**, **Restart**, and the post-round feeling choice). Confirm **Help now** can be reached from the main destinations and
   during a tool. The game should give neutral move feedback and ask how the round felt; do not treat its moves as a stress measurement.
5. **Save and review fictional records.** Add an event-owned entry in **Check-ins** and a fictional person under **More → People**. Check that
   the entry and person survive a lock/unlock, and that the check-in disappears if its event is deleted. Try **Settings → Reading style → Simple
   words** and inspect the shorter guide labels, prompts and newly selected suggestions. Previously saved step wording must stay unchanged. Guides offer optional context ideas, not an age classification or clinical program; check that the wording does not assume a diagnosis, retirement, dependency or family arrangement. A helper can read along while preserving the person's own choices.
6. **Inspect contact handoff without contacting anyone.** Test the copy-number icon with the fictional number. Use **Call** and **Text** only with a controlled
   test handler or disconnected simulator/emulator that guarantees no connection or message delivery. Inspect any OS handler preview, then cancel
   it without calling or sending. On a live device whose handler may dial immediately, skip Call and record it as **Not run**; do not assume the
   app supplies its own preview. If no handler exists, check the copy-number fallback and visible error.

## Backup and data ownership on each platform

7. Open **More → Settings → Export data**. In **Protect your backup**, enter a test-only export passphrase different from the vault passphrase.
   Inspect the actual OS save dialog, cancel it once, and confirm the app data is unchanged. Repeat and save a `.steady` file to a test-owned
   location. The export is a separate copy outside the app's deletion control.
8. Add a second fictional event after exporting. In **Import data**, inspect and cancel the actual OS picker; confirm both events remain. Select
   the saved file, try a wrong export passphrase at **Unlock your backup**, and confirm current data remains. Retry with the export passphrase;
   choose **Keep current data** at **Replace all local data?** and confirm both events remain. Import again and choose **Replace all data**;
   confirm only the exported state returns, including its guide, action wording/order/done states and appearance/reading settings. Lock and reopen the vault to confirm disk persistence. If a separate test export contains enabled system sources, confirm device usage and motion reset off
   after import; otherwise mark that subcheck **Not run**. Manual and in-app choices may be restored from an export.
   Current documents write version 3; the current app accepts validated versions 1/2/3. If separately prepared version 1/2 fictional files are available, confirm their events use General and retain saved steps. Older apps cannot read newly written v3 vaults or exports: never try this compatibility check on a real vault or discard the only usable older copy. Invalid v3 context must fail before replacement confirmation and leave current records intact.
9. With fictional data only, inspect **Clear game history** and **Delete all data** in Settings, plus **Clear learning** in Insights, including
   confirmation and resulting scope if included in this run. A committed clear can still show a cleanup warning if older known recovery files
   cannot be removed; that warning means the active vault changed, not that every local copy was erased. Do not force a storage failure on a
   personal device. Confirm Clear learning keeps the guide and saved actions as well as the other event records. Exported files and OS backups require separate owner action.

## Locked-vault passphrase help and preservation

These are additional unexecuted checks, using only the fictional vault created above. Never reset or uninstall a real vault to demonstrate the help UI. Keep every learning source off and do not approve a permission prompt just to proceed.

- Lock the fictional vault and open **Forgot your passphrase?**. Read **Help with your passphrase**: no account/server recovery; the `.steady` export passphrase is separate and does not unlock this vault; restore through **More → Settings → Import data** only after a vault can be opened; check an existing backup on another installation before discarding the locked vault; no vault passphrase or usable backup means the records cannot be recovered. The help must not discover files, request a permission, decrypt records or change the locked vault.
- Choose **Back to unlock**; separately reopen and dismiss with Escape/Back or the modal barrier where supported. Confirm each returns to the locked screen without a reset confirmation. Unlock with the known test passphrase and confirm the fictional persistence marker, guide/steps and settings remain. Repeat after a wrong-passphrase error; opening and dismissing help must not make that error destructive or create an empty vault.
- From help, choose **Start over…** and inspect the existing reset confirmation. Choose **Keep vault**, then unlock and confirm the same records remain. In a separate cancellation trial, enter a value other than `DELETE` and confirm reset remains unavailable; dismiss without deleting. Reset must never begin from opening/dismissing help alone. If testing actual reset, use only a separate disposable fictional vault, verify a usable test backup first, type `DELETE` explicitly and record progress/error behavior separately.
- At 320 logical pixels/200% text, in light and dark appearance and with a keyboard visible, scroll the locked form to its help link and read the help to its final paragraph. Confirm the safe primary actions **Unlock vault** and **Back to unlock** stay reachable, the help text scrolls without clipped controls, and Start over does not gain default keyboard focus. Check Tab/Shift-Tab, Enter/Space, Escape/Back and native screen-reader reading/focus return separately. Record any overflow, obscured action, focus trap or unexpected reset prompt.

Recovery render references live in `docs/screenshots/recovery-*.png`. Regenerate only synthetic captures with `flutter test --no-pub --concurrency=1 --update-goldens tool/capture_recovery_ui_test.dart`; this does not execute the manual checks above or validate a physical keyboard/VoiceOver.

## Accessibility and visual review on each platform

10. Review event creation, both guide/starter pickers, Home, Path, Tools, game, Check-ins, People, Settings, vault setup/unlock, and Insights in light and dark themes, with standard and Simple words. On a narrow/mobile
    window and at 200% text, check for clipped text, hidden buttons, unreachable dialogs, scroll traps, and touch targets. Enable the OS
    reduced-motion setting and check that optional transitions are not needed to understand state.
11. Use VoiceOver on iOS/macOS, TalkBack on Android, and the available native screen reader on Windows/Linux. Read navigation, stage progress,
    game cells, guide radio choices, starter checkboxes and existing-step explanations, source switches/status, errors, passphrase controls, and confirmation dialogs. Record missing names, misleading order/state, or
    controls that cannot be activated.
12. With a physical keyboard on desktop and where supported on mobile, traverse the same flows using Tab/Shift-Tab, arrows where appropriate,
    Enter/Space, and Escape/Back. Check visible focus, logical order, game navigation, modal focus return, and the Help now path. Note any
    difference between a screen-reader result and keyboard-only result.

## Optional sources and real device behavior

13. Start with all sources off; confirm events, tools, People, Check-ins, and Help now remain usable. In **Insights**, enable **Feeling
    check-ins** alone and save a fictional feeling. Enable **In-app activity** separately and inspect aggregate in-app counts after ordinary
    navigation/game play. **Review learning** should explain when evidence or elapsed time is insufficient; do not advance the device clock or
    claim a real 60-day result from this walkthrough.
14. On a test device you own or are authorized to configure, turn on a supported system source. Confirm the separate **Your device, your choice**
    dialog and **This is my device** decision. Where the OS presents a grant (Android/iOS), deny or cancel it, then check **Needs your
    permission** or an unavailable/denied reading while the rest of the app works. Grant only if you choose to test that source; inspect
    **Refresh readings**, revoke that same test grant in OS settings, and confirm the app no longer reports a usable reading. macOS foreground
    usage has no separate OS grant. Do not change another person's privacy settings.
15. With consented collection active, background the app, lock the vault, and turn the source off in Insights in separate trials. Check that the
    displayed reading pauses or clears, and use platform diagnostics where available to inspect collector stop and late callbacks. If stop cannot
    be established, mark it unverified. A resumed source should report its actual availability; never substitute zero for a missing reading.

| Platform | Source behavior to inspect |
| --- | --- |
| Android | Optional **Device usage** opens **Open usage access settings** for Usage Access; optional **Motion context** has **Allow motion access** for Activity Recognition, where supported. Check grant, denial, revocation, no-data, and Google Play services availability. Usage aggregates cover the last 60 minutes and may undercount. |
| iOS | **Device usage** is unavailable in this preview. Optional **Motion context** uses Core Motion where supported; check grant, denial, revocation, delayed/no readings, and session stop. |
| macOS | Optional **Device usage** counts activations only while Steady Through is foregrounded and screen-awake session minutes; it does not observe other-app switching or attention. Motion is unavailable. Check focus, sleep/wake, background, and lock transitions. |
| Windows and Linux | **Device usage** and **Motion context** should report unavailable. **Feeling check-ins** and **In-app activity** should still work without a native permission. |

16. Test possible vehicle context only while safely stopped, or observe a consenting passenger's device without asking the person to interact
    during travel. If a supported reading indicates possible vehicle movement, inspect **Return when safely stopped**: interactive reflection
    should be suppressed and Help remain reachable. The flag cannot identify a driver, passenger, route, or emotional state. Do not test by using
    the app while driving.

## Result record (one per platform/build)

Copy this block for each device or host. Link only synthetic screenshots/logs and redact passphrases, phone numbers, personal records, and
exported file contents.

```text
Date/time and tester:
OS and version / device or host model:
App build or artifact identifier / source SHA:
Installed via (local build, CI artifact, test distribution):
Core flow (steps 1–6): Pass / Fail / Not run / Unavailable — notes:
Backup and data (steps 7–9): Pass / Fail / Not run / Unavailable — notes:
Passphrase help / dismissal / reset cancellation / preservation: Pass / Fail / Not run / Unavailable — notes:
Visual/accessibility (steps 10–12): Pass / Fail / Not run / Unavailable — notes:
Sources (steps 13–16): Pass / Fail / Not run / Unavailable — notes:
Consent/grant states tested and actual reading/status:
Issue links, reproduction steps, and synthetic evidence:
Remaining unverified items / follow-up owner:
```

Report an observed failure or skipped check as such. A passed build, simulator case, or this checklist does not establish physical-device source
accuracy, accessibility for every person, a validated stress measure, or general store readiness.

## Reduced-motion resize regression walkthrough

This is an additional unexecuted manual check. With reduced motion enabled, create a fictional event, change its guide/steps, save it, edit/save again and leave the form. Resize/rotate with the keyboard open where supported. In Insights with every source off, pause, resize and resume. Toggle reduced motion while a normal transition is in progress. Record any rendering error, stuck control or lost choice; the local regressions do not replace this native walkthrough.
