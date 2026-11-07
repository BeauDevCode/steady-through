import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/ui/interactive_card.dart';
import 'package:steady_through/ui/steady_theme.dart';

double _contrast(Color a, Color b) {
  final light = a.computeLuminance();
  final dark = b.computeLuminance();
  return (math.max(light, dark) + .05) / (math.min(light, dark) + .05);
}

void main() {
  for (final brightness in Brightness.values) {
    test('readable text and visible focus across $brightness surfaces', () {
      final theme = steadyTheme(brightness);
      final c = theme.colorScheme;
      for (final pair in [
        (c.onPrimary, c.primary),
        (c.onPrimaryContainer, c.primaryContainer),
        (c.onSecondary, c.secondary),
        (c.onSecondaryContainer, c.secondaryContainer),
        (c.onTertiaryContainer, c.tertiaryContainer),
        (c.onSurface, c.surface),
        (c.onSurfaceVariant, c.surface),
        (c.onSurface, c.surfaceContainerLow),
        (c.onSurface, c.primaryContainer),
        (c.onSurface, c.secondaryContainer),
        (c.onSurface, c.tertiaryContainer),
      ]) {
        expect(_contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
      }
      final outlined = theme.outlinedButtonTheme.style!.side!.resolve({
        WidgetState.focused,
      })!;
      expect(_contrast(outlined.color, c.surface), greaterThanOrEqualTo(3));
    });
  }
  testWidgets(
    'whole card hover and focus stay passive and each activation fires once',
    (tester) async {
      var calls = 0;
      Widget host({bool enabled = true}) => MaterialApp(
        theme: steadyTheme(Brightness.light),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: InteractiveCard(
                onTap: enabled ? () => calls++ : null,
                child: const Text('Open a pause'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(host());
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(
        location: tester.getCenter(find.text('Open a pause')),
      );
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(calls, 1);
      await tester.tap(find.text('Open a pause'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      await tester.pumpWidget(host(enabled: false));
      await tester.tap(find.text('Open a pause'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
