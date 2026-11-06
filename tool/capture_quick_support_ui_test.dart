// Run: flutter test --update-goldens tool/capture_quick_support_ui_test.dart
// Actual Help, People, edit, and focused-step widgets with fictional records.
// Memory only: no vault, grants, native dialogs, phone/text or clipboard action.
// Produces 24 captures in docs/screenshots/quick-support/.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/features/help/help_screen.dart';
import 'package:steady_through/features/journey/focused_action_screen.dart';
import 'package:steady_through/features/people/people_screen.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/model/next_action_target.dart';
import 'package:steady_through/ui/steady_theme.dart';

class _CaptureRepository implements AppRepository {
  _CaptureRepository(this.value);
  AppData value;
  @override
  Future<AppData> load() async => value;
  @override
  Future<void> save(AppData next) async => value = next;
}

class _NoHandoff implements PhoneActions {
  int attempts = 0;
  @override
  Future<bool> openPhone(String number) async {
    attempts++;
    throw StateError('Capture must never open a phone app.');
  }

  @override
  Future<bool> openSms(String number) async {
    attempts++;
    throw StateError('Capture must never open a message app.');
  }
}

class _Profile {
  const _Profile(
    this.name,
    this.size, {
    this.dark = false,
    this.simple = false,
    this.scale = 1,
    this.reducedMotion = false,
  });
  final String name;
  final Size size;
  final bool dark;
  final bool simple;
  final double scale;
  final bool reducedMotion;
}

AppData _fictionalData(_Profile profile) => AppData(
  theme: profile.dark ? ThemeChoice.dark : ThemeChoice.light,
  readingStyle: profile.simple ? ReadingStyle.simple : ReadingStyle.standard,
  people: [
    TrustedPerson(id: 'fictional-alex', name: 'Alex Morgan', phone: '555-0100'),
    TrustedPerson(id: 'fictional-jo', name: 'Jo Ellis'),
    TrustedPerson(id: 'fictional-sam', name: 'Sam Rivera', phone: '555-0142'),
    TrustedPerson(id: 'fictional-riley', name: 'Riley Chen'),
  ],
  activeEventId: 'fictional-new-job',
  events: [
    SupportEvent(
      id: 'fictional-new-job',
      title: 'Starting a new job',
      createdAt: DateTime.utc(2026, 11, 6),
      actions: [
        PlanAction(
          id: 'fictional-orient',
          stage: JourneyStage.orient,
          title: 'Write down your first day',
          done: true,
        ),
        PlanAction(
          id: 'fictional-target',
          stage: JourneyStage.plan,
          title: 'Choose one small task for today',
        ),
        PlanAction(
          id: 'fictional-later',
          stage: JourneyStage.reflect,
          title: 'Notice one thing that helped',
        ),
      ],
    ),
  ],
);

Widget _app(
  _Profile profile,
  String scene,
  AppController controller,
  Widget home,
) => MaterialApp(
  key: ValueKey('${profile.name}-$scene'),
  debugShowCheckedModeBanner: false,
  theme: steadyTheme(Brightness.light),
  darkTheme: steadyTheme(Brightness.dark),
  themeMode: controller.data.theme == ThemeChoice.dark
      ? ThemeMode.dark
      : ThemeMode.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(profile.scale),
      disableAnimations: profile.reducedMotion,
      accessibleNavigation: profile.reducedMotion,
    ),
    child: child!,
  ),
  home: home,
);

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../docs/screenshots/quick-support/$name.png'),
  );
}

/// Lazy page children must be built before selecting their first match. Dialog
/// scrollables are selected only when the dialog actually has one.
Future<void> _reveal(WidgetTester tester, Finder target) async {
  final dialogs = find.byType(AlertDialog);
  final dialogScrollables = find.descendant(
    of: dialogs,
    matching: find.byType(Scrollable),
  );
  final scrollables =
      dialogs.evaluate().isNotEmpty && dialogScrollables.evaluate().isNotEmpty
      ? dialogScrollables
      : find.byType(Scrollable);
  for (var attempt = 0; target.evaluate().isEmpty && attempt < 60; attempt++) {
    expect(
      scrollables,
      findsWidgets,
      reason: 'No scrollable can reach $target',
    );
    await tester.drag(scrollables.first, const Offset(0, -200));
    await tester.pumpAndSettle();
  }
  expect(
    target,
    findsWidgets,
    reason: 'Missing reachable capture control $target',
  );
  await tester.ensureVisible(target.first);
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder target) async {
  await _reveal(tester, target);
  await tester.tap(target.first);
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
  for (final profile in const [
    _Profile('standard-light-mobile', Size(390, 1100)),
    _Profile('standard-dark-desktop', Size(1280, 1100), dark: true),
    _Profile(
      'simple-light-narrow-200-reduced-motion',
      Size(320, 1100),
      simple: true,
      scale: 2,
      reducedMotion: true,
    ),
  ]) {
    testWidgets('quick support captures ${profile.name}', (tester) async {
      tester.view.physicalSize = profile.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final initial = _fictionalData(profile);
      final repository = _CaptureRepository(initial);
      final controller = AppController(repository, initial);
      final handoff = _NoHandoff();
      addTearDown(controller.dispose);
      String file(String scene) => '$scene-${profile.name}';
      Finder inDialog(Finder target) =>
          find.descendant(of: find.byType(AlertDialog), matching: target);

      await tester.pumpWidget(
        _app(
          profile,
          'help',
          controller,
          Scaffold(
            body: HelpScreen(
              controller: controller,
              simpleWords: profile.simple,
              phoneActions: handoff,
            ),
          ),
        ),
      );
      await _reveal(tester, find.text('Your trusted people'));
      await _capture(tester, file('help-preview'));
      await _reveal(tester, find.byTooltip('Call Alex Morgan'));
      await _capture(tester, file('help-contact-actions'));
      expect(handoff.attempts, 0);

      // Follow the real Help route so the People page has its actual Back path.
      await _tapVisible(tester, find.text('View all saved people'));
      expect(find.byType(PeopleScreen), findsOneWidget);
      await _capture(tester, file('people'));
      await _tapVisible(tester, find.byTooltip('Edit Alex Morgan'));
      final nameField = inDialog(find.widgetWithText(TextFormField, 'Name'));
      final phoneField = inDialog(
        find.byKey(const ValueKey('person-phone-field')),
      );
      expect(
        tester.widget<TextFormField>(nameField).controller!.text,
        'Alex Morgan',
      );
      expect(
        tester.widget<TextFormField>(phoneField).controller!.text,
        '555-0100',
      );
      await _reveal(tester, phoneField);
      await _capture(tester, file('edit-prefilled'));
      await tester.enterText(phoneField, '');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await _capture(tester, file('edit-cleared-optional-phone'));
      await _tapVisible(tester, inDialog(find.text('Cancel')));
      expect(controller.data.people.first.phone, '555-0100');
      expect(repository.value.people.first.phone, '555-0100');

      final target = NextActionTarget(
        eventId: 'fictional-new-job',
        actionId: 'fictional-target',
        replacementRevision: controller.replacementRevision,
      );
      await tester.pumpWidget(
        _app(
          profile,
          'focus',
          controller,
          FocusedActionScreen(controller: controller, target: target),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Your next step'), findsOneWidget);
      await _capture(tester, file('focused-pending'));
      expect(controller.activeEvent!.actions[1].done, isFalse);
      await _tapVisible(tester, find.text('Mark step done'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(controller.activeEvent!.actions[1].done, isTrue);
      expect(repository.value.events.single.actions[1].done, isTrue);
      expect(controller.activeEvent!.actions[2].done, isFalse);
      await _reveal(tester, find.text('Starting a new job'));
      await _capture(tester, file('focused-done'));

      // A target for another document revision renders the genuine unavailable
      // state without replacing or mutating any of the fictional records.
      await tester.pumpWidget(
        _app(
          profile,
          'focus-unavailable',
          controller,
          FocusedActionScreen(
            controller: controller,
            target: NextActionTarget(
              eventId: target.eventId,
              actionId: target.actionId,
              replacementRevision: controller.replacementRevision + 1,
            ),
          ),
        ),
      );
      await _reveal(
        tester,
        find.textContaining('This step is no longer available.'),
      );
      await _capture(tester, file('focused-unavailable'));
      expect(handoff.attempts, 0);
      expect(controller.data.people.map((person) => person.id), [
        'fictional-alex',
        'fictional-jo',
        'fictional-sam',
        'fictional-riley',
      ]);
      expect(controller.data.learning.enabledSources, isEmpty);
      expect(controller.data.learning.deviceOwnerConfirmed, isFalse);
      expect(controller.data.learning.examples, isEmpty);
      expect(controller.data.toolFeedback.ratings, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
