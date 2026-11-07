# Visual polish design

## Intent and delegated choices

The user asks to continue improving layout, colors, interactions and animation until Steady Through looks beautiful and polished. Prior explicit instructions delegate implementation choices and request continued work without approval pauses. Build on the existing Flutter/Manrope warm-green identity. This design records implementer choices, not a separately approved mockup. Target 1.6.0+11 / v1.6.0-preview.1.

## Approaches

1. Recolor the existing equal-weight cards: small scope, little improvement to hierarchy or interaction.
2. Refine the existing design system, responsive hierarchy and finite motion across the app: chosen by implementer. Warm ivory, deep teal, apricot and restrained lavender; clear next action, distinctive tool artwork, quiet depth and visible focus. Preserves familiar destinations and function.
3. Replace navigation/layout with a new animated scene system: unnecessary state-lifetime and accessibility risk. Keep normal routes and immediate destination disposal.

## Surfaces and responsive composition

Use fully paired light/dark foreground colors, warm neutral cards, soft feature gradients (SurfaceCard accepts optional Gradient), restrained shadows, and clear focused/hovered controls. Keep 48px touch targets and readable typography. Narrow page/card gutters shrink before content does; full labels wrap. Section headings stack their actions at large text. ResponsiveColumns expands minimum reading width with text scale and optionally aligns natural-height rows using intrinsic row height; no fixed-height text or clipping. People uses that shared layout.

Home's event/empty hero uses a refined gradient, original decorative path artwork and balanced title measure. Its exact next-step card gets a clear leading accent and stronger action hierarchy. Support cards retain one whole-card action with visible hover/focus/press feedback. Tools get original code-drawn static illustrations (grounding, breathing rings, route), distinct restrained color identities and bottom-aligned actions in multi-column rows; single-column content remains natural height. More cards share the same interactive surface treatment. Desktop navigation has a framed branded rail, clearer selection and a compact useful destination header with Help always outside body motion. Preserve 800/1180 width behavior and large-text fallback.

## Motion and interaction

Use a finite incoming-only reveal, approximately 240ms ease-out with at most 8px translation. No perpetual decorative animation, autoplay tools, retained outgoing tab children, or delayed Help. Keep the existing GentleReveal API but stable widget structure when reduced-motion changes, preserving child state; reduced motion immediately completes the entrance without custom motion. Controller updates do not replay the entrance. A keyed reveal per destination disposes old content on the first switch frame. Existing Material routes remain.

Interactive card state follows InkWell hover/focus/highlight callbacks; a subtle border/wash changes, without geometric shrinking, duplicate gesture handlers, duplicated semantics or fabricated learning taps. Reduced motion uses zero-duration visual transitions. Pointer, keyboard and semantic activation invoke the existing callback exactly once. Focus/hover must not invoke an action or save data.

## Boundaries

Preserve exact labels/callbacks/keys/navigation behavior, Help/Back availability, failure feedback and all ownership/lifecycle protections. Schema4/read1/2/3/4, encryption/KDF/dependencies/permissions/adapters/learning thresholds remain unchanged. The app stays free/offline with all sources off. iPhone delivery stays Source and Simulator; unsigned device compilation is not installation. Use fictional memory fixtures and fake handoffs only. Never touch a personal vault, phone action, clipboard, OS chooser or source grant.

## Verification and delivery

Behavioral tests precede motion/interaction changes: stable child state across reduced-motion changes; finite entrance; immediate old-destination disposal, rapid switching and immediate Help; full-card pointer/keyboard single activation; text-aware columns/natural content. Pure reversible colors/spacing/art are verified through actual-widget captures rather than tests mirroring theme constants. Check meaningful color contrast on actual foreground/background pairs. Root owns serial SDK/Git/network orchestration; workers edit disjoint files.

Inspect actual captures for populated/empty Home, Path, Tools, More/People, Check-ins and Help at mobile light, desktop light/dark, and 320px Simple/200%/reduced-motion, plus hover/focus and animation before/after frames. Full Flutter/analyzer/format/helper checks, one fresh whole-branch review and one material regression fix pass. Publish final exact source only after existing seven jobs, four native cases on each of five runtimes, 13 artifact ZIPs, six complete packages, ten assets and independent byte audit pass. Verify tag/body/server hashes/anonymous access and documentation-only main successors; archive only this plan's scratch.
