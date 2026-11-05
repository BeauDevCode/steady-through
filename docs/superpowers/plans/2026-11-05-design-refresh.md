# Visual redesign implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Each owner edits separate files; Flutter test and analyzer commands are serialized through root.

**Goal:** Replace the generic first-preview layout with a polished responsive design while preserving working offline flows.

**Architecture:** A shared UI kit and theme define type, surfaces, spacing and original path artwork. Feature screens consume those primitives and retain controller calls and route interfaces. No persistence schema change.

**Tech Stack:** Flutter 3.47.9, Dart, local Manrope font asset, existing native plugins.

**Spec:** docs/superpowers/specs/2026-11-05-design-refresh.md

## Global constraints

- Five native targets, offline storage, Simple words, light/dark themes, Help now throughout.
- Keep existing data and behavior; preserve game feedback as player-confirmed reflection.
- No fonts or images loaded from a network at runtime.

## Review focus

- 320 logical pixel width with 200% text must remain scrollable with no overflow.
- Long event titles and contact names must wrap or truncate without hiding actions.
- Keyboard/screen-reader game movement must remain possible.
- Desktop navigation and modal routes must return to the correct destination.
- Redesign must preserve save-failure feedback and data replacement confirmations.

## Tasks

1. Root: create `lib/ui/steady_ui.dart`, `lib/ui/steady_theme.dart`; update shell and font assets. Verify layout behavior in `test/widget/layout_test.dart`.
2. Home/Path owner: redesign only `home_screen.dart` and `journey_screen.dart`; retain callback signatures and tested action labels. Add meaningful layout coverage when needed.
3. Tools owner: redesign only tools feature files; improve connected game board and self-paced tools without changing engine or controller.
4. Personal owner: redesign People, Check-ins, More and Settings; retain all confirmed data controls and failure states.
5. Root: format/analyze/test, inspect real-font screenshots at mobile and desktop sizes, and request independent review. Fix findings, commit and push only after verified.
6. Root: verify five-platform CI, publish a new labeled preview with verified artifacts, and report remaining physical-device/signing limits accurately.

Cosmetic-only edits are verified by rendering and existing behavior tests; new behavior or regressions use a failing test before the fix. This avoids tests that merely mirror styling values.
