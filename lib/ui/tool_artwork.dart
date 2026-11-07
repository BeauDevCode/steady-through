import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:steady_through/model/tool_feedback.dart';

/// Original, static decorative artwork. Never adds a target or a spoken label.
class ToolArtwork extends StatelessWidget {
  const ToolArtwork({super.key, required this.tool, this.height = 96});
  final SupportTool tool;
  final double height;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _ToolPainter(tool, Theme.of(context).colorScheme),
        ),
      ),
    ),
  );
}

class _ToolPainter extends CustomPainter {
  const _ToolPainter(this.tool, this.colors);
  final SupportTool tool;
  final ColorScheme colors;
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width * .5, size.height * .5);
    final h = size.height;
    final paint = Paint()..isAntiAlias = true;
    final ink = tool == SupportTool.grounding
        ? colors.secondary
        : tool == SupportTool.breathing
        ? colors.primary
        : colors.tertiary;
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(0, h * .22),
        width: math.min(size.width * .8, 180),
        height: h * .24,
      ),
      paint..color = ink.withValues(alpha: .06),
    );
    if (tool == SupportTool.breathing) {
      for (final radius in [.44, .32, .2]) {
        canvas.drawCircle(
          c,
          h * radius,
          paint
            ..color = ink.withValues(alpha: .13)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
      canvas.drawCircle(
        c,
        h * .12,
        paint
          ..style = PaintingStyle.fill
          ..color = ink.withValues(alpha: .85),
      );
      canvas.drawCircle(
        c + Offset(h * .32, 0),
        3.5,
        paint..color = colors.surface,
      );
      canvas.drawCircle(c + Offset(h * .32, 0), 2, paint..color = ink);
    } else if (tool == SupportTool.grounding) {
      final stem = Path()
        ..moveTo(c.dx, c.dy + h * .36)
        ..quadraticBezierTo(
          c.dx - h * .08,
          c.dy,
          c.dx + h * .04,
          c.dy - h * .36,
        );
      canvas.drawPath(
        stem,
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = ink,
      );
      for (var i = 0; i < 3; i++) {
        final y = c.dy + h * .12 - i * h * .18;
        for (final direction in [-1.0, 1.0]) {
          canvas.save();
          canvas.translate(c.dx + direction * h * .13, y);
          canvas.rotate(direction * .45);
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset.zero,
              width: h * .3,
              height: h * .13,
            ),
            paint
              ..style = PaintingStyle.fill
              ..color = ink.withValues(alpha: .22 + i * .14),
          );
          canvas.restore();
        }
      }
      canvas.drawCircle(
        c + Offset(h * .55, -h * .25),
        h * .08,
        paint..color = ink.withValues(alpha: .3),
      );
    } else {
      final p = Path()
        ..moveTo(c.dx - h * .68, c.dy + h * .23)
        ..cubicTo(
          c.dx - h * .4,
          c.dy - h * .45,
          c.dx - h * .15,
          c.dy + h * .48,
          c.dx + h * .08,
          c.dy,
        )
        ..cubicTo(
          c.dx + h * .25,
          c.dy - h * .4,
          c.dx + h * .4,
          c.dy + h * .1,
          c.dx + h * .68,
          c.dy - h * .3,
        );
      canvas.drawPath(
        p,
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18
          ..strokeCap = StrokeCap.round
          ..color = ink.withValues(alpha: .1),
      );
      canvas.drawPath(
        p,
        paint
          ..strokeWidth = 2
          ..color = ink,
      );
      for (final point in [
        c + Offset(-h * .68, h * .23),
        c + Offset(h * .08, 0),
        c + Offset(h * .68, -h * .3),
      ]) {
        canvas.drawCircle(
          point,
          5,
          paint
            ..style = PaintingStyle.fill
            ..color = colors.surface,
        );
        canvas.drawCircle(point, 2.8, paint..color = ink);
      }
    }
  }

  @override
  bool shouldRepaint(_ToolPainter oldDelegate) =>
      oldDelegate.tool != tool || oldDelegate.colors != colors;
}
