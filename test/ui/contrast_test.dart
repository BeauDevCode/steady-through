import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/ui/steady_theme.dart';

double _contrast(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  return (max(a, b) + .05) / (min(a, b) + .05);
}

void main() {
  test('small secondary text meets 4.5 contrast on every card surface', () {
    for (final brightness in Brightness.values) {
      final colors = steadyTheme(brightness).colorScheme;
      for (final background in [
        colors.surface,
        colors.primaryContainer,
        colors.secondaryContainer,
        colors.surfaceContainerLow,
      ]) {
        expect(
          _contrast(colors.onSurfaceVariant, background),
          greaterThanOrEqualTo(4.5),
          reason: '$brightness small text on $background',
        );
      }
    }
  });
}
