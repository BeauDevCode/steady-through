import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/app/steady_through_app.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/main.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/features/tools/grounding_screen.dart';

class _MemoryRepository implements AppRepository {
  AppData value = AppData.empty();

  @override
  Future<AppData> load() async => value;

  @override
  Future<void> save(AppData next) async => value = next;
}

// The controller serializes writes through a Future chain. Widget tests use a
// fake clock, so give that chain one real event-loop turn after a user action.
Future<void> _settleWrite(WidgetTester tester) async {
  await tester.runAsync(
    () async => Future<void>.delayed(const Duration(milliseconds: 1)),
  );
  await tester.pumpAndSettle();
}

void main() {
  late AppController controller;

  setUp(() {
    controller = AppController(_MemoryRepository(), AppData.empty());
  });
  tearDown(() => controller.dispose());

  testWidgets('empty Home explains privacy and creates a titled event', (
    tester,
  ) async {
    await tester.pumpWidget(SteadyThroughApp(controller: controller));

    expect(find.text('Start an event'), findsOneWidget);
    expect(find.textContaining('on this device'), findsOneWidget);
    await tester.tap(find.text('Create event'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save event'));
    await tester.pumpAndSettle();
    expect(find.text('Give this event a title.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Moving house');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'One step at a time',
    );
    await tester.tap(find.text('Save event'));
    await _settleWrite(tester);

    expect(controller.activeEvent?.title, 'Moving house');
    expect(controller.activeEvent?.description, 'One step at a time');
    expect(find.text('Get oriented'), findsOneWidget);
  });

  testWidgets('Home switches between two saved events', (tester) async {
    await tester.runAsync(() => controller.createEvent('First event', ''));
    final firstId = controller.activeEvent!.id;
    await tester.runAsync(() => controller.createEvent('Second event', ''));
    await tester.pumpWidget(SteadyThroughApp(controller: controller));

    expect(find.text('Second event'), findsWidgets);
    await tester.tap(find.text('Switch event'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('First event').last);
    await _settleWrite(tester);

    expect(controller.activeEvent!.id, firstId);
    expect(find.text('First event'), findsWidgets);
  });

  testWidgets('Home opens grounding in one tap and Stop returns Home', (
    tester,
  ) async {
    await tester.pumpWidget(SteadyThroughApp(controller: controller));

    await tester.tap(find.text('Grounding'));
    await tester.pumpAndSettle();
    expect(find.byType(GroundingScreen), findsOneWidget);
    expect(find.text('Step 1 of 4'), findsOneWidget);
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    expect(find.text('Start an event'), findsOneWidget);
  });

  testWidgets('game result can return directly to the active event path', (
    tester,
  ) async {
    await tester.runAsync(() => controller.createEvent('Move house', ''));
    await tester.pumpWidget(SteadyThroughApp(controller: controller));
    await tester.tap(find.text('Tools'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Path game'), 250);
    await tester.ensureVisible(find.text('Path game'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Path game'));
    await tester.pumpAndSettle();

    for (final cell in [1, 2, 3, 7, 11, 15]) {
      final square = find.byKey(ValueKey('cell-$cell'));
      await tester.ensureVisible(square);
      await tester.tap(square);
      await tester.pump();
    }
    await tester.scrollUntilVisible(
      find.text('How did this round feel?'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Calm'));
    await _settleWrite(tester);
    await tester.scrollUntilVisible(
      find.text('Go to event path'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Go to event path'));
    await tester.pumpAndSettle();

    expect(find.text('Your path'), findsOneWidget);
    expect(find.text('Move house'), findsOneWidget);
  });

  testWidgets('Simple words shortens Home and Path guidance', (tester) async {
    await tester.runAsync(() => controller.createEvent('Move house', ''));
    await tester.runAsync(
      () => controller.setReadingStyle(ReadingStyle.simple),
    );
    await tester.pumpWidget(SteadyThroughApp(controller: controller));

    expect(find.text('One small step'), findsOneWidget);
    await tester.tap(find.text('Path'));
    await tester.pumpAndSettle();
    expect(find.text('What needs to happen first?'), findsOneWidget);
    expect(
      find.text('What needs your attention first? Start with what you know.'),
      findsNothing,
    );
  });

  testWidgets('Simple words makes the event form easier to read', (
    tester,
  ) async {
    await tester.runAsync(
      () => controller.setReadingStyle(ReadingStyle.simple),
    );
    await tester.pumpWidget(SteadyThroughApp(controller: controller));
    await tester.tap(find.text('Create event'));
    await tester.pumpAndSettle();

    expect(
      find.text('Name what is happening. You can leave details blank.'),
      findsOneWidget,
    );
  });

  testWidgets('Path completes an action and updates progress', (tester) async {
    await tester.runAsync(() => controller.createEvent('Move house', ''));
    await tester.pumpWidget(SteadyThroughApp(controller: controller));
    await tester.tap(find.text('Path'));
    await tester.pumpAndSettle();

    expect(find.text('0 of 5 actions done'), findsOneWidget);
    final action = find.widgetWithText(
      CheckboxListTile,
      'Notice what needs attention first',
    );
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await _settleWrite(tester);

    expect(controller.activeEvent!.actions.first.done, isTrue);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('1 of 5 actions done'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 5 actions done'), findsOneWidget);
  });

  testWidgets('Path can add, rename, and remove an action', (tester) async {
    await tester.runAsync(() => controller.createEvent('Move house', ''));
    await tester.pumpWidget(SteadyThroughApp(controller: controller));
    await tester.tap(find.text('Path'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Add action').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add action').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Pack one box');
    await tester.tap(find.text('Save action'));
    await _settleWrite(tester);
    expect(find.text('Pack one box'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit Pack one box'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Pack a bag');
    await tester.tap(find.text('Save action'));
    await _settleWrite(tester);
    expect(find.text('Pack a bag'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove Pack a bag'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove action'));
    await _settleWrite(tester);
    expect(find.text('Pack a bag'), findsNothing);
  });

  testWidgets(
    'Path finishes, reopens, and deletes an event with confirmation',
    (tester) async {
      await tester.runAsync(() => controller.createEvent('Move house', ''));
      await tester.pumpWidget(SteadyThroughApp(controller: controller));
      await tester.tap(find.text('Path'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Finish event'), 300);
      await tester.ensureVisible(find.text('Finish event'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish event'));
      await _settleWrite(tester);
      expect(controller.activeEvent!.completedAt, isNotNull);
      await tester.scrollUntilVisible(find.text('Reopen event'), 300);
      await tester.ensureVisible(find.text('Reopen event'));
      await tester.pumpAndSettle();
      expect(find.text('Reopen event'), findsOneWidget);

      await tester.tap(find.text('Reopen event'));
      await _settleWrite(tester);
      expect(controller.activeEvent!.completedAt, isNull);
      await tester.scrollUntilVisible(find.text('Delete event'), 300);
      await tester.ensureVisible(find.text('Delete event'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete event'));
      await tester.pumpAndSettle();
      expect(controller.activeEvent, isNotNull);
      await tester.tap(find.text('Keep event'));
      await tester.pumpAndSettle();
      expect(controller.activeEvent, isNotNull);

      await tester.tap(find.text('Delete event'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete permanently'));
      await _settleWrite(tester);
      expect(controller.activeEvent, isNull);
      expect(find.text('Start an event'), findsOneWidget);
    },
  );

  testWidgets('Help now stays reachable at narrow width and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(SteadyThroughApp(controller: controller));
    expect(find.byTooltip('Help now'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(find.byTooltip('Help now'));
    await tester.pumpAndSettle();
    expect(find.textContaining('immediate physical danger'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('U.S. only'), 150);
    expect(find.textContaining('U.S. only'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide window uses a navigation rail', (tester) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(SteadyThroughApp(controller: controller));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Help now'), findsOneWidget);
  });

  testWidgets('corrupt local data requires explicit confirmation to reset', (
    tester,
  ) async {
    var resets = 0;
    await tester.pumpWidget(
      MaterialApp(home: StartupRecoveryScreen(onReset: () async => resets++)),
    );
    expect(find.textContaining('saved data'), findsWidgets);
    expect(resets, 0);
    await tester.tap(find.text('Reset local data'));
    await tester.pumpAndSettle();
    expect(resets, 0);
    await tester.tap(find.text('Keep data'));
    await tester.pumpAndSettle();
    expect(resets, 0);
    await tester.tap(find.text('Reset local data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete saved data'));
    await tester.pumpAndSettle();
    expect(resets, 1);
  });
}
