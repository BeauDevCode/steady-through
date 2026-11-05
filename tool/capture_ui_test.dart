// Run: flutter test --update-goldens tool/capture_ui_test.dart
// Uses synthetic entries and bundled fonts. These captures support visual
// review and are deliberately outside the default platform-sensitive tests.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/app/steady_through_app.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/features/tools/path_game_screen.dart';

class _MemoryRepository implements AppRepository {
  @override
  Future<AppData> load() async => AppData.empty();
  @override
  Future<void> save(AppData value) async {}
}

AppData _sample({bool empty = false, bool dark = false}) => AppData(
  theme: dark ? ThemeChoice.dark : ThemeChoice.light,
  activeEventId: empty ? null : 'event',
  people: [
    TrustedPerson(id: 'morgan', name: 'Morgan', phone: '+1 555 010 0123'),
    TrustedPerson(id: 'lee', name: 'Lee', phone: ''),
  ],
  checkIns: empty
      ? []
      : [
          CheckIn(
            id: 'note',
            eventId: 'event',
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
            id: 'event',
            title: 'A new chapter, a new routine',
            description: 'Finding my feet, one small step at a time.',
            createdAt: DateTime.utc(2026, 11, 5),
            actions: [
              PlanAction(
                id: '1',
                stage: JourneyStage.orient,
                title: 'Name what I can do today',
                done: true,
              ),
              PlanAction(
                id: '2',
                stage: JourneyStage.settle,
                title: 'Take a short pause',
                done: true,
              ),
              PlanAction(
                id: '3',
                stage: JourneyStage.support,
                title: 'Ask someone to walk with me',
              ),
              PlanAction(
                id: '4',
                stage: JourneyStage.plan,
                title: 'Prepare one thing for tomorrow',
              ),
              PlanAction(
                id: '5',
                stage: JourneyStage.reflect,
                title: 'Write down what helped',
              ),
            ],
          ),
        ],
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
  for (final capture in [
    ('home-mobile', const Size(430, 932), 0),
    ('home-desktop', const Size(1440, 1000), 0),
    ('welcome-mobile', const Size(430, 932), 0),
    ('path-desktop', const Size(1440, 1100), 1),
    ('tools-desktop', const Size(1440, 1000), 2),
    ('game-mobile', const Size(430, 1000), 2),
    ('home-dark', const Size(1440, 1000), 0),
    ('checkins-mobile', const Size(430, 932), 3),
    ('people-desktop', const Size(1440, 1000), 4),
    ('settings-desktop', const Size(1440, 1100), 4),
  ]) {
    testWidgets(capture.$1, (tester) async {
      tester.view.physicalSize = capture.$2;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = AppController(
        _MemoryRepository(),
        _sample(
          empty: capture.$1.startsWith('welcome'),
          dark: capture.$1.endsWith('dark'),
        ),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(SteadyThroughApp(controller: controller));
      await tester.pumpAndSettle();
      if (capture.$3 > 0) {
        if (find.byType(NavigationRail).evaluate().isNotEmpty) {
          tester
              .widget<NavigationRail>(find.byType(NavigationRail))
              .onDestinationSelected!(capture.$3);
        } else {
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .onDestinationSelected!(capture.$3);
        }
        await tester.pumpAndSettle();
      }
      if (capture.$1.startsWith('game')) {
        await tester.ensureVisible(find.text('Path game').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Path game').last);
        await tester.pumpAndSettle();
        expect(find.byType(PathGameScreen), findsOneWidget);
        for (final cell in [1, 2, 3, 7]) {
          await tester.tap(find.byKey(ValueKey('cell-$cell')));
          await tester.pump();
        }
      }
      if (capture.$1.startsWith('people') ||
          capture.$1.startsWith('settings')) {
        final label = capture.$1.startsWith('people') ? 'People' : 'Settings';
        await tester.ensureVisible(find.text(label).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../docs/screenshots/${capture.$1}.png'),
      );
    });
  }
}
