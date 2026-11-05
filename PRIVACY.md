# Privacy and data in Steady Through

_Last updated: November 5, 2026_

Steady Through is designed to work locally without an account, app-operated backend, analytics, advertising, or in-app cloud sync. The app does not ask for a birth date, location permission, contacts permission, or notification permission. People and phone numbers are typed in manually. The app's features are general self-help and organization, not medical care or a validated stress measurement.

## Data you choose to save

The app stores your event titles and descriptions, stage actions and completion state, check-ins (your words, optional 1–5 intensity and note), manually entered trusted people and phone numbers, appearance and reading settings, and path-game round summaries. Round summaries include counts and the feeling you select after a round. The app does not retain a raw sequence of game taps or infer a clinical stress score from them.

This information is kept in a JSON document in the app's local support directory on your device. It is not encrypted by a separate app password. Device security and any device backup settings are controlled by your operating system. If you share a device or backup account, consider that others with access may be able to access this data.

## When data can leave the app

- **Export:** An export writes a readable JSON copy to a location you choose. That file is outside the app's support directory. Other apps, file-sharing services, and backups may access it depending on where you save or share it. Delete exported copies separately when you no longer want them.
- **Import:** You choose a JSON file. The app validates it before asking to replace its current data. A confirmed import replaces all local app data; it does not merge records. Canceling or rejecting an invalid file leaves the current data intact. The source file remains where you selected it.
- **Phone or text:** Tapping a contact action can hand a manually entered number to the device's phone or SMS app. Calling or texting is then handled by that other app and its service provider. The number remains visible and can be copied when a handler is unavailable.

The app does not send your journal entries, event details, or game history to the project maintainers. Operating-system backups can retain copies independently of the app.

## Deletion and retention

You can delete a check-in, delete an event, clear game history, or use Delete all in settings. Deleting an event also deletes its check-ins; it does not clear the global game history. Delete all removes the app's local records after confirmation. Uninstalling may remove local app data, depending on the platform. Neither action removes exported files, files in backups, or messages/calls handled by another app. The app has no server copy to delete.

## Children and helpers

Simple words mode does not require a birth date. A trusted adult or helper can read along. There is no in-app chat, social feed, targeted advertising, or ranking. Caregivers should decide what personal information to enter and where to keep any export. See the [FTC's guidance on children's privacy](https://www.ftc.gov/business-guidance/resources/complying-coppa-frequently-asked-questions) for broader context; this document does not claim legal certification.

## Questions or changes

Open a repository issue for a privacy question or bug, but do not post your real check-ins, phone numbers, export files, or other sensitive details. Privacy and safety changes should be reviewed against the app's actual behavior and the [FTC's mobile health app practices](https://www.ftc.gov/business-guidance/resources/mobile-health-app-developers-ftc-best-practices).
