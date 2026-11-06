// Run: flutter test --update-goldens tool/capture_recovery_ui_test.dart
// Actual locked/help UI, empty synthetic fields, bundled fonts, no disk vault.
// No controller, LearningSession, source grants, backup discovery or reset.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/features/vault/vault_unlock_screen.dart';
import 'package:steady_through/ui/steady_theme.dart';

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  for (final field in tester.widgetList<EditableText>(
    find.byType(EditableText, skipOffstage: false),
  )) {
    expect(field.controller.text, isEmpty);
    expect(field.obscureText, isTrue);
  }
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../docs/screenshots/recovery-$name.png'),
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

  for (final profile in [
    ('light-mobile', const Size(430, 1100), Brightness.light, 1.0),
    ('dark-mobile', const Size(430, 1100), Brightness.dark, 1.0),
    ('light-narrow-200', const Size(320, 1100), Brightness.light, 2.0),
    ('dark-desktop', const Size(1440, 1100), Brightness.dark, 1.0),
  ]) {
    testWidgets('recovery UI ${profile.$1}', (tester) async {
      tester.view.physicalSize = profile.$2;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = profile.$4;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      var resetCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: steadyTheme(profile.$3),
          debugShowCheckedModeBanner: false,
          home: VaultUnlockScreen(
            creating: false,
            onSubmit: (_) async {
              throw StateError('This preview never opens a vault.');
            },
            onReset: () async {
              resetCalls++;
              throw StateError('This preview never resets a vault.');
            },
          ),
        ),
      );
      await _capture(tester, 'locked-${profile.$1}');
      await tester.ensureVisible(find.text('Forgot your passphrase?'));
      await tester.pumpAndSettle();
      expect(
        find.text('Forgot your passphrase?').hitTestable(),
        findsOneWidget,
      );
      if (profile.$4 == 2) {
        await _capture(tester, 'locked-controls-${profile.$1}');
      }
      await tester.tap(find.text('Forgot your passphrase?'));
      await _capture(tester, 'help-${profile.$1}');
      if (profile.$4 == 2) {
        final ending = find.textContaining('cannot be recovered');
        await tester.ensureVisible(ending);
        await _capture(tester, 'help-end-${profile.$1}');
        tester.view.viewInsets = const FakeViewPadding(bottom: 240);
        await tester.pumpAndSettle();
        await Scrollable.ensureVisible(tester.element(ending), alignment: 1);
        await tester.pumpAndSettle();
        await _capture(tester, 'help-keyboard-${profile.$1}');
      }
      expect(resetCalls, 0);
      await tester.tap(find.text('Back to unlock'));
      await tester.pumpAndSettle();
      expect(resetCalls, 0);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
