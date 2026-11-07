# Visual Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A visibly refined, cohesive, responsive app with safe finite motion and a verified public cross-platform preview.

**Architecture:** Existing Flutter screens and Material routes; shared visual components/theme, incoming-only destination reveal, natural-height responsive cards. Root serial SDK/Git/network, disjoint visual worker, one fresh final reviewer.

**Tech Stack:** Flutter3.47.9/Dart3.13.7; existing bundled Manrope/icons; original Canvas artwork; no new dependency.

**Spec:** `docs/superpowers/specs/2026-11-07-visual-polish-design.md`

## Global Constraints

- 1.6.0+11/v1.6.0-preview.1; schema4/read1/2/3/4, encryption/KDF/dependencies/permissions/adapters/learning thresholds unchanged.
- All five destinations/exact labels/keys/callbacks preserved, Help outside body motion, immediate outgoing disposal, no outgoing AnimatedSwitcher.
- 48px targets, no fixed-height text or clipping; light/dark, mobile/desktop, Simple200%/reduced motion.
- Fictional owned fixtures only; no personal vaults, real OS actions or grants. iPhone Source+Simulator scope retained.
- Preserve7jobs/4nativecases×5/13artifactZIPs/6packages/10assets and source/latest-attempt/hash/body/tag/main/anonymous gates.

## Review Focus

- Reduced-motion changes during entry preserve focused form/child state and settle without replay.
- Rapid destination switches dispose outgoing state immediately; old queued operations cannot acquire extra animation lifetime.
- Focus/hover never activates or records an extra tap; keyboard/semantic/pointer activation calls exactly once.
- Large text and long labels retain natural card height and stack headings/columns; Help remains reachable.
- Explicit colors pair correctly on light/dark feature surfaces, focus distinguishable without relying on low-contrast decorative borders.

---

### Task 1: Shared visual system and safe motion

**Files:** lib/ui/steady_theme.dart, lib/ui/steady_ui.dart; create lib/ui/steady_motion.dart, lib/ui/interactive_card.dart, lib/ui/tool_artwork.dart; test/widget/visual_polish_test.dart.
**Interfaces:** Preserve GentleReveal(child), SurfaceCard(child,padding,color) with optional Gradient? gradient, ResponsiveColumns(children,minWidth); add optional alignHeights=false to ResponsiveColumns; new InteractiveCard({required Widget child,required VoidCallback? onTap,Color? color,EdgeInsetsGeometry? padding}); new ToolArtwork({required SupportTool tool,double height=96}) uses model/tool_feedback.dart. Shared default card padding becomes responsive only when omitted, explicit padding stays exact.

- [x] Baseline existing layout/app integration checks. Write regressions for GentleReveal stable child counter/focus during disableAnimations false→true and finite entry; verify InteractiveCard exact keyboard/pointer behavior and passive focus/hover; ResponsiveColumns large-text collapse. Inspect aligned natural-height rows in actual captures; preserve the existing Material semantic action without a new handler. Observe behavioral RED before related changes. Avoid theme constant tests.
- [x] Implement palette/paired colors/state focus, safe stable-tree finite reveal, responsive shared gutters/headings/columns and interactive card. Static tool artwork excludes semantics/hit testing. Run targeted tests plus layout/tools/feedback/insights/guidance checks. Inspect initial captures; commit shared system after full suite green.

### Task 2: Screen composition and navigation finish

**Files:** lib/app/steady_through_app.dart, lib/features/home/home_screen.dart, lib/features/tools/tools_screen.dart, lib/features/people/people_screen.dart, lib/features/settings/settings_screen.dart, lib/features/check_ins/check_ins_screen.dart; test/widget/visual_navigation_test.dart; tool/capture_visual_polish_ui_test.dart and docs/screenshots/visual-polish/.
**Interfaces:** Consume Task1 components unchanged exact callbacks. New keyed GentleReveal around shell body only, keyed ValueKey(destination), standard Material routes and immediate disposal; preserve breakpoints. Root owns shell/More/check-in and behavioral tests; disjoint worker owns Home/Tools/People and capture script.

- [x] Write motion-boundary regressions using injected real shell destination builders: outgoing child disposed first switch frame, rapid switch final-only content, immediate Help/Back and focus behavior. Observe expected RED for missing new entry without changing existing disposal guarantees.
- [x] Refine Home hero/next step/support, Tools illustration/card alignment, shared People columns, More card feedback, Check-ins stacking and desktop/mobile shell. Preserve route/learning/storage protections. Run meaningful interaction/layout suites; generate/inspect actual screenshots for populated/empty Home/Path/Tools/More/People/Check-ins/Help at mobile390/desktop1280 light/dark and320Simple200%reduced motion; capture focus/hover and finite entry frames. No native AT or pixel-comparison claim from generated references.
- [x] Full Flutter/analyzer/format/helpers; set1.6.0+11; document actual local results and pending CI. One fresh whole-branch review using spec/ledger, fix material findings once with RED/GREEN and full suite. Commit exact final source and captures.

### Task 3: Verified public preview and completion

**Files:** README.md, PRIVACY.md, docs/quality-status.md, docs/device-validation.md, docs/ios-distribution.md, docs/releases/1.6.0-decisions.md and publication snapshot. Operational helpers outside repo.
**Interfaces:** Adapt prior1.5.1 release helpers to1.6.0+11, keep four-case verifier/fixture markers/evidence allowlists and all gates. Export helperbytes from exact source.

- [ ] Push source, require7latestjobsSUCCESS and actual CI suite/helper/JUnit counts; four named native cases×5. Download13 artifactZIPs via connector; full hashes/payload/metadata/unsigned-device/sourcehelper staging of10assets. Independent actual byte audit before publication.
- [ ] Verify draft then public exact release body/tag/source/10serverhashes/sizes; publishauthorizedpublicpreview, anonymously verifyrepo/release/downloads. Merge testedsource with documentation-only successors to main; verify ancestry/pathallowlist and cleanremote/localHEAD.
- [ ] Save durable publication snapshot, complete plan, archive/hash-check/remove only own scratch, delete fully merged local featurebranch, final public proof. Report visual changes, actual checks, complete rulings and limits. Do not stop at review or offer another approval menu.
