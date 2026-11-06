# Private learning implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or executing-plans. Owners edit disjoint files; root schedules every Flutter/Dart verification command.

**Goal:** Deliver encrypted local storage and a consent-controlled personal learning loop with honest evidence limits and a 60-day calibration review.

**Architecture:** Vault services wrap the existing AppRepository. Versioned learning models extend AppData. A native signal bridge feeds aggregate snapshots into a foreground learning session; an Insights UI lets the person label/correct and control each source.

**Tech Stack:** Flutter 3.47.9, cryptography 2.9, existing file picker, Swift/Kotlin platform channels.

**Spec:** docs/superpowers/specs/2026-11-05-private-learning.md

## Global constraints

- Entire app free; external device permissions optional.
- Encrypted local persistence and exports, no server transmission or embedded secret.
- No diagnostic emotion claim or prompts during possible vehicle movement.
- All sources off initially; consent and platform availability must be shown.
- Animation respects reduced motion and layouts remain usable at 200% text.

## Review focus

- Disk/authentication failures must preserve existing records and avoid plaintext fallback.
- Retried migration must not overwrite a usable encrypted vault or lose its cleanup warning.
- Missing/denied source readings must stay missing rather than become misleading zeroes.
- Sparse, one-class, contradictory or temporally shifted examples must not produce confident predictions.
- Locking/permission dialogs must not race pending writes or leave collectors running.

## Tasks

- [x] Vault owner: create codec/store/session/encrypted repository and encrypted portability; write meaningful RED/GREEN security and migration tests. Root adds dependency and owns test lane.
- [x] Learning owner: add learning models, AppData version migration, explainable engine and 60-day candidate evaluation; tests for coverage, uncertainty, temporal holdout and adoption limits.
- [x] Platform owner: implement consent-neutral capabilities/start/read/stop bridge and macOS/Android/iOS aggregate adapters. No collection before start; no raw app content. Root verifies builds.
- [x] Root: integrate vault setup/unlock/privacy cover/lock and learning controller/UI with source controls, feedback, support actions and accessible motion.
- [ ] Root: encrypted import/export UI, failure states, full tests and reduced-motion/narrow checks; independent crypto/inference review and native build verification.
- [ ] Root: update privacy/setup/quality docs and public source/release with exact platform and validation limits.

Cosmetic changes use render checks and existing tests; behavioral and security changes start with tests that expose the missing behavior. The user has asked for continued execution, so plan and implementation proceed in this chat without a separate approval stop.
