// Run: flutter test --update-goldens tool/capture_visual_polish_ui_test.dart
// 32 actual-shell reference captures for human visual review. These are not
// pixel-comparison evidence. All records are fictional and memory-only; no
// vault, source grants, clipboard, phone, message or native chooser is used.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/app/steady_through_app.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/features/help/help_screen.dart';
import 'package:steady_through/features/people/phone_actions.dart';
import 'package:steady_through/model/app_data.dart';

class _MemoryRepository implements AppRepository {
  _MemoryRepository(this.value);
  AppData value;
  @override
  Future<AppData> load() async => value;
  @override
  Future<void> save(AppData next) async => value = next;
}

class _NoHandoff implements PhoneActions {
  @override
  Future<bool> openPhone(String number) async =>
      throw StateError('Visual captures must never open a phone app.');
  @override
  Future<bool> openSms(String number) async =>
      throw StateError('Visual captures must never open a message app.');
}

class _Profile {
  const _Profile(
    this.name,
    this.size, {
    this.dark = false,
    this.simple = false,
  });
  final String name;
  final Size size;
  final bool dark;
  final bool simple;
}

AppData _sample(_Profile profile, {bool empty = false}) => AppData(
  theme: profile.dark ? ThemeChoice.dark : ThemeChoice.light,
  readingStyle: profile.simple ? ReadingStyle.simple : ReadingStyle.standard,
  activeEventId: empty ? null : 'fictional-event',
  people: [
    TrustedPerson(id: 'fictional-morgan', name: 'Morgan', phone: '555-0100'),
    TrustedPerson(id: 'fictional-lee', name: 'Lee'),
    TrustedPerson(id: 'fictional-sam', name: 'Sam Rivera', phone: '555-0142'),
  ],
  checkIns: empty
      ? []
      : [
          CheckIn(
            id: 'fictional-note',
            eventId: 'fictional-event',
            createdAt: DateTime.utc(2026, 11, 5),
            feeling: 'A little more settled',
            intensity: 2,
            note: 'A walk and a conversation helped me find one next step.',
          ),
        ],
  events: empty
      ? []
      : [
          SupportEvent(
            id: 'fictional-event',
            title: 'A new chapter, a new routine',
            description: 'Finding my feet, one small step at a time.',
            createdAt: DateTime.utc(2026, 11, 5),
            actions: [
              PlanAction(
                id: 'fictional-1',
                stage: JourneyStage.orient,
                title: 'Name what I can do today',
                done: true,
              ),
              PlanAction(
                id: 'fictional-2',
                stage: JourneyStage.settle,
                title: 'Take a short pause',
                done: true,
              ),
              PlanAction(
                id: 'fictional-3',
                stage: JourneyStage.support,
                title: 'Ask someone to walk with me',
              ),
              PlanAction(
                id: 'fictional-4',
                stage: JourneyStage.plan,
                title: 'Prepare one thing for tomorrow',
              ),
              PlanAction(
                id: 'fictional-5',
                stage: JourneyStage.reflect,
                title: 'Write down what helped',
              ),
            ],
          ),
        ],
);

Future<void> _finishFrame(WidgetTester tester) async {
  // Bound every wait: no perpetual animation can silently hang capture work.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 100));
  expect(tester.takeException(), isNull);
}

Future<void> _capture(WidgetTester tester, String name) async {
  await _finishFrame(tester);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../docs/screenshots/visual-polish/$name.png'),
  );
}

Future<void> _navigate(WidgetTester tester, int destination) async {
  const icons = [
    Icons.home_outlined,
    Icons.route_outlined,
    Icons.spa_outlined,
    Icons.edit_note_outlined,
    Icons.more_horiz,
  ];
  final nav = find.byType(NavigationRail).evaluate().isNotEmpty
      ? find.byType(NavigationRail)
      : find.byType(NavigationBar);
  final target = find.descendant(
    of: nav,
    matching: find.byIcon(icons[destination]),
  );
  expect(target, findsOneWidget);
  await tester.tap(target);
  await _finishFrame(tester);
}

Future<void> _revealAndTap(WidgetTester tester, Finder target) async {
  for (var attempt = 0; target.evaluate().isEmpty && attempt < 24; attempt++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -220));
    await _finishFrame(tester);
  }
  expect(target, findsWidgets);
  await tester.ensureVisible(target.first);
  await _finishFrame(tester);
  await tester.tap(target.first);
  await _finishFrame(tester);
}

Widget _shell(AppController controller, _Profile profile) => SteadyThroughApp(
  controller: controller,
  helpBuilder: (context, controller) => Scaffold(
    appBar: AppBar(title: const Text('Help now')),
    body: HelpScreen(
      controller: controller,
      simpleWords: profile.simple,
      phoneActions: _NoHandoff(),
    ),
  ),
);

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
    _Profile('light-mobile', Size(390, 1100)),
    _Profile('light-desktop', Size(1280, 1100)),
    _Profile('dark-desktop', Size(1280, 1100), dark: true),
    _Profile(
      'simple-light-narrow-200-reduced-motion',
      Size(320, 1100),
      simple: true,
    ),
  ]) {
    testWidgets('visual polish references ${profile.name}', (tester) async {
      final previousFatal = WidgetController.hitTestWarningShouldBeFatal;
      WidgetController.hitTestWarningShouldBeFatal = true;
      addTearDown(
        () => WidgetController.hitTestWarningShouldBeFatal = previousFatal,
      );
      tester.view.physicalSize = profile.size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = profile.simple
          ? 2
          : 1;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: profile.simple);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final initial = _sample(profile);
      final controller = AppController(_MemoryRepository(initial), initial);
      addTearDown(controller.dispose);
      String file(String scene) => '$scene-${profile.name}';
      await tester.pumpWidget(_shell(controller, profile));
      await _capture(tester, file('home'));
      await _navigate(tester, 1);
      await _capture(tester, file('path'));
      await _navigate(tester, 2);
      await _capture(tester, file('tools'));
      await _navigate(tester, 4);
      await _capture(tester, file('more'));
      await _revealAndTap(tester, find.text('People'));
      await _capture(tester, file('people'));
      await _navigate(tester, 3);
      await _capture(tester, file('checkins'));
      final help = find.byTooltip('Help now').evaluate().isNotEmpty
          ? find.byTooltip('Help now')
          : find.text('Help now');
      await tester.tap(help.first);
      await _capture(tester, file('help'));
      expect(controller.data.learning.enabledSources, isEmpty);
      expect(controller.data.learning.examples, isEmpty);
      expect(controller.data.learning.deviceOwnerConfirmed, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await _finishFrame(tester);
      final empty = _sample(profile, empty: true);
      final emptyController = AppController(_MemoryRepository(empty), empty);
      addTearDown(emptyController.dispose);
      await tester.pumpWidget(_shell(emptyController, profile));
      await _capture(tester, file('home-empty'));
      await tester.pumpWidget(const SizedBox.shrink());
      await _finishFrame(tester);
    });
  }
}
