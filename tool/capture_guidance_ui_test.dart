// Run: flutter test --update-goldens tool/capture_guidance_ui_test.dart
// Actual creation/guide/step/Path/Home UI with fictional data and bundled fonts.
// Every source stays off; no LearningSession, device bridge, vault or passphrase.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/app/steady_through_app.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/features/journey/event_form.dart';
import 'package:steady_through/features/journey/guidance_picker.dart';
import 'package:steady_through/model/app_data.dart';

class _CaptureRepository implements AppRepository {
  _CaptureRepository(this.value);
  AppData value;

  @override
  Future<AppData> load() async => value;

  @override
  Future<void> save(AppData next) async => value = next;
}

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../docs/screenshots/guidance-$name.png'),
  );
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  final dialog = find.byType(AlertDialog);
  final scrollable = dialog.evaluate().isNotEmpty
      ? find.descendant(of: dialog, matching: find.byType(Scrollable)).first
      : find.byType(Scrollable).first;
  for (var scroll = 0; finder.evaluate().isEmpty && scroll < 25; scroll++) {
    await tester.drag(scrollable, const Offset(0, -180));
    await tester.pumpAndSettle();
  }
  expect(finder, findsOneWidget, reason: 'Missing reachable control $finder');
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await _reveal(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
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
    ('standard-light-mobile', const Size(430, 1100), false, false, 1.0),
    ('simple-dark-mobile', const Size(430, 1100), true, true, 1.0),
    ('simple-light-narrow-200', const Size(320, 1100), true, false, 2.0),
    ('standard-dark-desktop', const Size(1440, 1100), false, true, 1.0),
  ]) {
    testWidgets('guidance flow ${profile.$1}', (tester) async {
      tester.view.physicalSize = profile.$2;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = profile.$5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final data = AppData(
        theme: profile.$4 ? ThemeChoice.dark : ThemeChoice.light,
        readingStyle: profile.$3 ? ReadingStyle.simple : ReadingStyle.standard,
      );
      final controller = AppController(_CaptureRepository(data), data);
      addTearDown(controller.dispose);
      await tester.pumpWidget(SteadyThroughApp(controller: controller));
      await tester.pumpAndSettle();
      await _tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Create event'),
      );
      expect(find.byType(EventForm), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Fictional shared care plan',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Make room for support and a covered break.',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await _capture(tester, 'creation-${profile.$1}');

      await _tapVisible(tester, find.text('Choose guide'));
      await _capture(tester, 'guide-picker-${profile.$1}');
      final caregiving = find.byWidgetPredicate(
        (widget) =>
            widget is RadioListTile<GuidanceContext> &&
            widget.value == GuidanceContext.caregiving,
      );
      await _tapVisible(tester, caregiving);
      if (profile.$5 == 2) {
        await _capture(tester, 'guide-picker-selected-${profile.$1}');
      }
      await _tapVisible(tester, find.text('Use guide'));
      await _tapVisible(tester, find.text('Choose starter steps'));
      expect(find.byType(StarterStepsPickerDialog), findsOneWidget);
      // Keep only orient and plan, mirroring the encrypted/native fixture.
      for (final index in [1, 2, 4]) {
        await _tapVisible(tester, find.byType(CheckboxListTile).at(index));
      }
      await _capture(tester, 'starter-picker-${profile.$1}');
      await _tapVisible(tester, find.text('Use selected steps'));
      if (profile.$5 == 2) {
        await _reveal(tester, find.text('Choose guide'));
        await _capture(tester, 'creation-guide-${profile.$1}');
      }
      await _tapVisible(tester, find.text('Save event'));
      expect(find.byType(EventForm), findsNothing);
      expect(
        controller.activeEvent!.guidanceContext,
        GuidanceContext.caregiving,
      );
      expect(controller.activeEvent!.actions, hasLength(2));
      await _capture(tester, 'path-${profile.$1}');
      if (profile.$5 == 2) {
        await _reveal(tester, find.text('Your guide'));
        await _capture(tester, 'path-guide-${profile.$1}');
        await _reveal(tester, find.text('Choose starter steps'));
        await _capture(tester, 'path-guide-end-${profile.$1}');
      }

      if (find.byType(NavigationRail).evaluate().isNotEmpty) {
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .onDestinationSelected!(0);
      } else {
        tester
            .widget<NavigationBar>(find.byType(NavigationBar))
            .onDestinationSelected!(0);
      }
      await _capture(tester, 'home-${profile.$1}');
      expect(controller.data.learning.enabledSources, isEmpty);
      expect(controller.data.learning.deviceOwnerConfirmed, isFalse);
      expect(
        tester
            .widget<SteadyThroughApp>(find.byType(SteadyThroughApp))
            .learningSession,
        isNull,
      );
    });
  }
}
