import 'package:flutter/material.dart';

/// One Material action, with finite visual feedback and a visible focus ring.
class InteractiveCard extends StatefulWidget {
  const InteractiveCard({
    super.key,
    required this.child,
    required this.onTap,
    this.color,
    this.padding,
  });
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  @override
  State<InteractiveCard> createState() => _InteractiveCardState();
}

class _InteractiveCardState extends State<InteractiveCard> {
  bool _hover = false, _focus = false, _pressed = false;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = widget.onTap != null && (_hover || _focus || _pressed);
    final base = widget.color ?? colors.surface;
    return LayoutBuilder(
      builder: (context, constraints) => AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            colors.primary.withValues(alpha: active ? .055 : 0),
            base,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            width: 1.5,
            color: _focus && widget.onTap != null
                ? colors.primary
                : active
                ? colors.primary.withValues(alpha: .5)
                : colors.outlineVariant.withValues(alpha: .8),
          ),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: active ? .055 : .015),
              blurRadius: active ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(23),
          clipBehavior: Clip.antiAlias,
          child: Semantics(
            button: true,
            enabled: widget.onTap != null,
            child: InkWell(
              onTap: widget.onTap,
              onHover: (value) => setState(() => _hover = value),
              onFocusChange: (value) => setState(() => _focus = value),
              onHighlightChanged: (value) => setState(() => _pressed = value),
              borderRadius: BorderRadius.circular(23),
              mouseCursor: widget.onTap == null
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.click,
              focusColor: colors.primary.withValues(alpha: .04),
              hoverColor: Colors.transparent,
              child: Padding(
                padding:
                    widget.padding ??
                    EdgeInsets.all(constraints.maxWidth < 340 ? 18 : 22),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
