// Run: flutter test --update-goldens tool/capture_visual_feedback_ui_test.dart
// Ten actual-component references for human review, not pixel-comparison
// evidence. Fictional content only; no controller, vault, or external actions.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/ui/steady_motion.dart';
import 'package:steady_through/ui/steady_theme.dart';
import 'package:steady_through/ui/steady_ui.dart' hide GentleReveal;

Widget _host(Brightness brightness, {required Widget child}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: steadyTheme(brightness),
  home: Scaffold(
    body: Center(child: SizedBox(width: 460, child: child)),
  ),
);

Widget _content(BuildContext context, {required bool interactive}) {
  final theme = Theme.of(context);
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      IconBadge(icon: interactive ? Icons.spa_outlined : Icons.route_rounded),
      const SizedBox(height: 20),
      Text(
        interactive ? 'Open a pause' : 'One small step',
        style: theme.textTheme.headlineSmall,
      ),
      const SizedBox(height: 10),
      Text(
        'There is room to take your time.',
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: Text(
              interactive
                  ? 'Choose a quiet moment'
                  : 'Begin when you are ready',
              style: theme.textTheme.labelLarge,
            ),
          ),
          Icon(Icons.arrow_forward_rounded, color: theme.colorScheme.primary),
        ],
      ),
    ],
  );
}

Future<void> _capture(WidgetTester tester, String name) async {
  expect(tester.takeException(), isNull);
  // Intentionally no pump here: preserve the requested animation frame.
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../docs/screenshots/visual-polish/$name.png'),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final brightness in Brightness.values) {
    final palette = brightness.name;
    testWidgets('finite feedback reference frames $palette', (tester) async {
      final previousFatal = WidgetController.hitTestWarningShouldBeFatal;
      WidgetController.hitTestWarningShouldBeFatal = true;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      var callbacks = 0;
      try {
        tester.view.physicalSize = const Size(600, 460);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: false);
        await mouse.addPointer(location: const Offset(4, 4));
        await tester.pumpWidget(
          _host(
            brightness,
            child: Builder(
              builder: (context) => GentleReveal(
                child: SurfaceCard(
                  child: _content(context, interactive: false),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 40));
        await _capture(tester, 'entrance-early-$palette');
        await tester.pump(const Duration(milliseconds: 300));
        await _capture(tester, 'entrance-settled-$palette');

        // Dispose the reveal before mounting a single interactive action.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          _host(
            brightness,
            child: Builder(
              builder: (context) => InteractiveCard(
                onTap: () => callbacks++,
                child: _content(context, interactive: true),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(callbacks, 0);
        await _capture(tester, 'interactive-rest-$palette');

        await mouse.moveTo(tester.getCenter(find.byType(InteractiveCard)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(callbacks, 0);
        await _capture(tester, 'interactive-hover-$palette');

        await mouse.moveTo(const Offset(4, 4));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        final decoration =
            tester
                    .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                    .decoration!
                as BoxDecoration;
        expect(
          (decoration.border! as Border).top.color,
          steadyTheme(brightness).colorScheme.primary,
          reason: 'Real Tab input must expose the keyboard focus ring.',
        );
        expect(callbacks, 0);
        await _capture(tester, 'interactive-keyboard-focus-$palette');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(callbacks, 1);
        expect(tester.takeException(), isNull);
      } finally {
        await mouse.removePointer();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 300));
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
        WidgetController.hitTestWarningShouldBeFatal = previousFatal;
      }
    });
  }
}
