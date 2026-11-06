# Private learning and encrypted vault

The user wants an app that learns from chosen interactions, device usage and optional motion/trip patterns, estimates what may help, improves after roughly 60 days, stays free, and keeps information encrypted on the person's devices. Device permissions are optional; the algorithm determines when evidence is sufficient. The existing event planning and support tools remain available when permissions are declined.

## Approach

Use a passphrase-protected local vault, an explainable personal model trained on the person's own labels, and explicit per-source consent. A cloud emotion service would transmit sensitive behavior and create a server dependency. Broad screen/keystroke capture would collect content that is unnecessary for these signals. The chosen sources store aggregate counts and durations; content from other apps, GPS routes, raw keypresses and screenshots are outside this design.

Every source starts off. A person can choose structured feeling check-ins, aggregate in-app activity, supported device-usage summaries or supported motion summaries. System sources additionally require device-owner confirmation and native permission where available. Revoking consent stops its collector. No OS permission is necessary for the rest of the app. Collection runs only during an unlocked app session; native limitations and observation windows are shown rather than replaced with fake data.

## Encryption

All app records, settings, learning examples and labels are inside an authenticated AES-256-GCM vault. A passphrase derives the key with PBKDF2-HMAC-SHA256 at 600,000 iterations and a random 16-byte salt. Each save uses a fresh 12-byte nonce and authentication tag. Key derivation runs outside the UI isolate. The passphrase is not stored. A session holds a derived key in memory, clears its reference on lock, and makes no claim that a compromised unlocked endpoint is protected. There is no recovery server.

First launch creates a passphrase. Existing version 1/2 JSON is migrated only after the encrypted document is written, authenticated and read back; old plaintext primary/backup/temp files are then removed. Cleanup failures are surfaced. Existing encrypted data is never silently reset. A corrupt file or wrong passphrase leaves disk untouched. Explicit reset requires confirmation. New exports are encrypted `.steady` files with their own passphrase; legacy JSON may be imported after validation and replacement confirmation.

## Personal model

Store bounded, dated aggregate feature snapshots paired only with labels chosen by the person. The engine has an insufficient-evidence state, an uncertain state, and tentative matches with supporting observations. It never turns a click, app switch or vehicle flag into a factual emotional or medical diagnosis. A response can say that the current pattern resembles moments the person marked tense, ask if that fits, and offer one useful action. Corrections become new labeled examples. Manual-only input can show a self-reported trend even when predictive matching has no features.

The engine uses explicit minimum sample/class coverage and comparable-feature requirements before matching. Every 60 days a local calibration review may train a candidate on older examples and evaluate it against later held-out examples and a simple majority baseline. It adopts an update only when sufficient evidence and improvement checks pass, and records its revision, date and evaluation counts. Otherwise the current model remains and the report explains what is missing. This is personal calibration, not a clinical accuracy claim. Retain at most 180 days/1,000 labeled examples, whichever limit is reached first; users can clear learning independently.

## Platform sources

- macOS: opt-in NSWorkspace application activation counts and unlocked-session duration; no app names or window content persisted.
- Android: permission-gated UsageStats aggregates; optional Activity Recognition for possible vehicle/walking context while the session runs, if supported.
- iOS: opt-in Core Motion activity summaries where supported. Cross-app usage is unavailable in this preview because Screen Time requires Apple's Family Controls capability/entitlement and extensions. No entitlement bypass.
- Windows/Linux: manual and in-app sources work; system usage/motion sources report unavailable until native adapters are implemented and verified.

Vehicle context is uncertain and does not identify the driver. Suppress reflection prompts when current motion indicates possible vehicle movement; display a calm notice to return when safely stopped. No driving-time notifications, route map, driving score or diagnosis.

## Interface

Add a beautiful Insights destination with a coordinated sage/apricot/forest palette, a visible source/consent panel, live aggregate signal tiles, evidence-based reflection card, editable feeling choices, calibration progress, and clear pause/clear controls. Use subtle entrance/crossfade/selection animation, respect reduced-motion settings, and preserve 200% text and touch targets. Add a vault setup/unlock/lock flow with a privacy cover on app switching and a 5-minute background lock timeout. Plain language explains encryption, passphrase loss, source scope, insufficient evidence and the 60-day review.

## Verification

Tests must cover wrong passphrase/tampering/nonces, legacy migration/cleanup failures, encrypted export/import, consent off/no collection, permission denial/unsupported sources, aggregate bounds, uncertain models, temporal calibration gating, correction/clear flows, reduced motion and narrow layouts. Compile all five native targets and independently review crypto boundaries and inference claims before publishing another preview. Physical device/source validation remains explicit if unavailable locally.

## Primary references

- https://pub.dev/packages/cryptography
- https://developer.android.com/reference/android/app/usage/UsageStatsManager
- https://developers.google.com/location-context/activity-recognition
- https://developer.apple.com/documentation/coremotion/cmmotionactivity
- https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement
- https://developer.apple.com/documentation/appkit/nsworkspace
