import 'dart:math' as math;

import 'package:flutter/material.dart';

class SteadyPage extends StatelessWidget {
  const SteadyPage({super.key, required this.children, this.maxWidth = 1120});
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              constraints.maxWidth < 600 ? 20 : 36,
              24,
              constraints.maxWidth < 600 ? 20 : 36,
              36,
            ),
            children: children,
          ),
        ),
      ),
    ),
  );
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.color,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  @override
  Widget build(BuildContext context) => Card(
    color: color,
    child: Padding(padding: padding, child: child),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });
  final String title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final heading = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      );
      if (action == null) return heading;
      if (constraints.maxWidth < 520) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [heading, const SizedBox(height: 12), action!],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: heading),
          const SizedBox(width: 24),
          action!,
        ],
      );
    },
  );
}

class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.icon, this.color, this.size = 48});
  final IconData icon;
  final Color? color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color ?? Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(size * .32),
    ),
    child: Icon(
      icon,
      size: size * .48,
      color: Theme.of(context).colorScheme.onPrimaryContainer,
    ),
  );
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      letterSpacing: 1.8,
      fontWeight: FontWeight.w800,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class ResponsiveColumns extends StatelessWidget {
  const ResponsiveColumns({
    super.key,
    required this.children,
    this.minWidth = 280,
  });
  final List<Widget> children;
  final double minWidth;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final count = math.max(
        1,
        math.min(
          children.length,
          ((constraints.maxWidth + 20) / (minWidth + 20)).floor(),
        ),
      );
      final width = (constraints.maxWidth - 20 * (count - 1)) / count;
      return Wrap(
        spacing: 20,
        runSpacing: 20,
        children: children
            .map((child) => SizedBox(width: width, child: child))
            .toList(),
      );
    },
  );
}

/// Original, decorative route artwork. Content and actions never depend on it.
class PathArtwork extends StatelessWidget {
  const PathArtwork({super.key, this.height = 220});
  final double height;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _PathPainter(Theme.of(context).colorScheme)),
    ),
  );
}

class _PathPainter extends CustomPainter {
  _PathPainter(this.colors);
  final ColorScheme colors;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint();
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * .54, h * .66),
        width: w * .82,
        height: h * .55,
      ),
      paint..color = colors.primary.withValues(alpha: .06),
    );
    canvas.drawCircle(
      Offset(w * .76, h * .23),
      h * .115,
      paint..color = colors.secondaryContainer,
    );
    canvas.drawCircle(
      Offset(w * .76, h * .23),
      h * .065,
      paint..color = colors.secondary.withValues(alpha: .65),
    );
    final path = Path()
      ..moveTo(w * .12, h * .84)
      ..cubicTo(w * .27, h * .56, w * .40, h * .92, w * .48, h * .62)
      ..cubicTo(w * .59, h * .22, w * .68, h * .66, w * .80, h * .30);
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.primary.withValues(alpha: .15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    for (final point in [
      Offset(w * .12, h * .84),
      Offset(w * .48, h * .62),
      Offset(w * .80, h * .30),
    ]) {
      canvas.drawCircle(point, 7, Paint()..color = colors.surface);
      canvas.drawCircle(point, 4, Paint()..color = colors.primary);
    }
    final leafPaint = Paint()..color = colors.primary.withValues(alpha: .28);
    for (var i = 0; i < 4; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * .16 + i * 5, h * .39 - i * 13),
          width: 20,
          height: 9,
        ),
        leafPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * .24 - i * 3, h * .38 - i * 13),
          width: 20,
          height: 9,
        ),
        leafPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_PathPainter oldDelegate) => oldDelegate.colors != colors;
}
