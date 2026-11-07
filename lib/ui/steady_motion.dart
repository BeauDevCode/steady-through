import 'package:flutter/material.dart';

/// A finite incoming reveal. Its child stays mounted when motion settings change.
class GentleReveal extends StatefulWidget {
  const GentleReveal({super.key, required this.child});
  final Widget child;
  @override
  State<GentleReveal> createState() => _GentleRevealState();
}

class _GentleRevealState extends State<GentleReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  late final CurvedAnimation _progress = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      _started = true;
    } else if (!_started) {
      _started = true;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _progress,
    child: widget.child,
    builder: (_, child) => Opacity(
      opacity: _progress.value,
      child: Transform.translate(
        offset: Offset(0, 8 * (1 - _progress.value)),
        child: child,
      ),
    ),
  );
}
