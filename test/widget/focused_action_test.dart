import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/features/help/help_screen.dart';
import 'package:steady_through/features/journey/focused_action_screen.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/model/next_action_target.dart';
import 'package:steady_through/ui/steady_theme.dart';

class _Repository implements AppRepository {
  _Repository(this.value);
  AppData value;
  bool fail = false;
  int saves = 0;
  Completer<void>? barrier;

  @override
  Future<AppData> load() async => value;

  @override
  Future<void> save(AppData next) async {
    saves++;
    await barrier?.future;
    if (fail) throw StateError('disk unavailable');
    value = next;
  }
}

AppData _fixture() => AppData(
  activeEventId: 'event',
  events: [
    SupportEvent(
      id: 'event',
      title: 'Moving house',
      createdAt: DateTime.utc(2026, 11, 6),
      actions: [
        PlanAction(
          id: 'earlier',
          stage: JourneyStage.orient,
          title: 'Check the move date',
        ),
        PlanAction(
          id: 'target',
          stage: JourneyStage.reflect,
          title: 'Write down one thing that helped',
        ),
      ],
    ),
    SupportEvent(
      id: 'other-event',
      title: 'Another event',
      createdAt: DateTime.utc(2026, 11, 6),
      actions: [
        PlanAction(
          id: 'other-action',
          stage: JourneyStage.plan,
          title: 'Keep this action unchanged',
        ),
      ],
    ),
  ],
);

Future<void> _settleWrite(WidgetTester tester) async {
  await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label).first;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await _settleWrite(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Glyph bounds must use the shipped font and theme, as the UI captures do.
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  late _Repository repository;
  late AppController controller;
  late NextActionTarget target;

  setUp(() {
    repository = _Repository(_fixture());
    controller = AppController(repository, repository.value);
    target = NextActionTarget(
      eventId: 'event',
      actionId: 'target',
      replacementRevision: controller.replacementRevision,
    );
  });
  tearDown(() => controller.dispose());

  PlanAction action() => controller.data.events
      .firstWhere((event) => event.id == 'event')
      .actions
      .firstWhere((action) => action.id == 'target');

  Future<void> open(
    WidgetTester tester, {
    VoidCallback? onOpenHelp,
    VoidCallback? onOpenPath,
    NextActionTarget? selected,
    bool largeText = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: steadyTheme(Brightness.light),
        builder: largeText
            ? (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(2),
                  disableAnimations: true,
                ),
                child: child!,
              )
            : null,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FocusedActionScreen(
                    controller: controller,
                    target: selected ?? target,
                    onOpenHelp: onOpenHelp,
                    onOpenPath: onOpenPath,
                  ),
                ),
              ),
              child: const Text('Home fixture'),
            ),
          ),
        ),
      ),
    );
    await _tap(tester, 'Home fixture');
  }

  testWidgets('focus opens the exact step without completing or advancing', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Your next step'), findsOneWidget);
    expect(find.text('Moving house'), findsOneWidget);
    expect(find.text('Write down one thing that helped'), findsOneWidget);
    expect(find.text('Check the move date'), findsNothing);
    expect(find.text('Mark step done'), findsOneWidget);
    expect(repository.saves, 0);
    expect(controller.data.learning.enabledSources, isEmpty);

    await _tap(tester, 'Mark step done');
    expect(action().done, isTrue);
    expect(repository.value.events.first.actions.last.done, isTrue);
    expect(controller.activeEvent!.actions.first.done, isFalse);
    expect(controller.data.events.last.actions.single.done, isFalse);
    expect(find.text('Write down one thing that helped'), findsOneWidget);
    expect(find.text('Check the move date'), findsNothing);
    expect(find.text('Undo completion'), findsOneWidget);
    expect(controller.activeEvent!.completedAt, isNull);

    await _tap(tester, 'Undo completion');
    expect(action().done, isFalse);
    expect(repository.saves, 2);
    expect(find.text('Mark step done'), findsOneWidget);
  });

  testWidgets('focus reads live event and action text', (tester) async {
    await open(tester);
    await tester.runAsync(
      () => controller.updateEvent('event', 'New event title', 'New details'),
    );
    await tester.runAsync(
      () => controller.renameAction('event', 'target', 'A revised small step'),
    );
    await tester.pumpAndSettle();
    expect(find.text('New event title'), findsOneWidget);
    expect(find.text('A revised small step'), findsOneWidget);
    expect(find.text('Write down one thing that helped'), findsNothing);
    await _tap(tester, 'Mark step done');
    expect(action().title, 'A revised small step');
    expect(action().done, isTrue);
  });

  testWidgets('primary save failure leaves step unchanged and permits retry', (
    tester,
  ) async {
    await open(tester);
    repository.fail = true;
    await _tap(tester, 'Mark step done');
    expect(action().done, isFalse);
    expect(find.text('Undo completion'), findsNothing);
    expect(find.textContaining('could not be updated'), findsOneWidget);
    repository.fail = false;
    await _tap(tester, 'Mark step done');
    expect(action().done, isTrue);
    expect(find.text('Undo completion'), findsOneWidget);
  });

  testWidgets('queued completion preserves an unrelated settings write', (
    tester,
  ) async {
    await open(tester);
    repository.barrier = Completer<void>();
    final earlier = controller.setTheme(ThemeChoice.dark);
    await _tap(tester, 'Mark step done');
    repository.barrier!.complete();
    await _settleWrite(tester);
    await earlier;
    expect(controller.data.theme, ThemeChoice.dark);
    expect(action().done, isTrue);
    expect(repository.value.theme, ThemeChoice.dark);
  });

  for (final change in [
    'missing action',
    'completed event',
    'other active event',
    'deleted event',
    'same-ID replacement',
  ]) {
    testWidgets('$change makes the target unavailable without a mutation', (
      tester,
    ) async {
      await open(tester);
      switch (change) {
        case 'missing action':
          await tester.runAsync(
            () => controller.removeAction('event', 'target'),
          );
        case 'completed event':
          await tester.runAsync(() => controller.completeEvent('event', true));
        case 'other active event':
          await tester.runAsync(() => controller.selectEvent('other-event'));
        case 'deleted event':
          await tester.runAsync(() => controller.deleteEvent('event'));
        case 'same-ID replacement':
          await tester.runAsync(
            () => controller.replaceData(AppData.fromJson(_fixture().toJson())),
          );
      }
      await tester.pumpAndSettle();
      final saves = repository.saves;
      expect(find.textContaining('no longer available'), findsOneWidget);
      expect(find.text('Mark step done'), findsNothing);
      expect(find.text('Undo completion'), findsNothing);
      expect(find.text('View full path'), findsOneWidget);
      await _tap(tester, 'Back to Home');
      expect(find.text('Home fixture'), findsOneWidget);
      expect(repository.saves, saves);
      expect(controller.data.events.last.actions.single.done, isFalse);
    });
  }

  testWidgets('an absent initial target still offers full path', (
    tester,
  ) async {
    var paths = 0;
    await open(
      tester,
      selected: NextActionTarget(
        eventId: 'missing',
        actionId: 'missing',
        replacementRevision: controller.replacementRevision,
      ),
      onOpenPath: () => paths++,
    );
    expect(find.textContaining('no longer available'), findsOneWidget);
    await _tap(tester, 'View full path');
    expect(paths, 1);
    expect(repository.saves, 0);
  });

  testWidgets('standalone full path fallback uses the current existing plan', (
    tester,
  ) async {
    await open(tester);
    await _tap(tester, 'View full path');
    expect(find.text('Get oriented'), findsOneWidget);
    expect(find.text('Check the move date'), findsOneWidget);
    expect(find.text('0 of 2 actions done'), findsOneWidget);
    expect(repository.saves, 0);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Your next step'), findsOneWidget);
    expect(action().done, isFalse);
  });

  testWidgets('queued same-ID replacement cannot complete imported action', (
    tester,
  ) async {
    await open(tester);
    repository.barrier = Completer<void>();
    final replacing = controller.replaceData(
      AppData.fromJson(_fixture().toJson()),
    );
    await _tap(tester, 'Mark step done');
    repository.barrier!.complete();
    await _settleWrite(tester);
    await replacing;
    expect(action().done, isFalse);
    expect(repository.saves, 1);
    expect(find.textContaining('no longer available'), findsOneWidget);
  });

  testWidgets('background invalidates a queued completion', (tester) async {
    await open(tester);
    repository.barrier = Completer<void>();
    final earlier = controller.setTheme(ThemeChoice.dark);
    await _tap(tester, 'Mark step done');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    repository.barrier!.complete();
    await _settleWrite(tester);
    await earlier;
    expect(action().done, isFalse);
    expect(repository.saves, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await _tap(tester, 'Mark step done');
    expect(action().done, isTrue);
  });

  for (final started in [false, true]) {
    testWidgets(
      'Back remains available during ${started ? 'atomic' : 'queued'} save',
      (tester) async {
        await open(tester);
        repository.barrier = Completer<void>();
        Future<void>? earlier;
        if (!started) earlier = controller.setTheme(ThemeChoice.dark);
        await _tap(tester, 'Mark step done');
        await _tap(tester, 'Back to Home');
        expect(find.text('Home fixture'), findsOneWidget);
        repository.barrier!.complete();
        await _settleWrite(tester);
        if (earlier != null) await earlier;
        expect(action().done, started);
        expect(repository.saves, 1);
        expect(find.text('Home fixture'), findsOneWidget);
        expect(find.text('Undo completion'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Help is immediate during ${started ? 'atomic' : 'queued'} save',
      (tester) async {
        await open(tester);
        repository.barrier = Completer<void>();
        Future<void>? earlier;
        if (!started) earlier = controller.setTheme(ThemeChoice.dark);
        await _tap(tester, 'Mark step done');
        await _tap(tester, 'Help now');
        expect(find.byType(HelpScreen), findsOneWidget);
        expect(
          tester.widget<HelpScreen>(find.byType(HelpScreen)).controller,
          same(controller),
        );
        expect(
          find.textContaining('immediate physical danger'),
          findsOneWidget,
        );
        repository.barrier!.complete();
        await _settleWrite(tester);
        if (earlier != null) await earlier;
        expect(action().done, started);
        expect(find.byType(HelpScreen), findsOneWidget);
        await _tap(tester, 'Back');
        expect(find.byType(FocusedActionScreen), findsOneWidget);
        expect(
          find.text(started ? 'Undo completion' : 'Mark step done'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('repeated completion taps while saving write only once', (
    tester,
  ) async {
    await open(tester);
    repository.barrier = Completer<void>();
    await _tap(tester, 'Mark step done');
    final buttons = find.byType(FilledButton);
    expect(buttons, findsOneWidget);
    expect(tester.widget<FilledButton>(buttons).onPressed, isNull);
    repository.barrier!.complete();
    await _settleWrite(tester);
    expect(repository.saves, 1);
    expect(action().done, isTrue);
  });

  testWidgets(
    'explicit Help and full path callbacks leave completion untouched',
    (tester) async {
      var helps = 0;
      var paths = 0;
      await open(tester, onOpenHelp: () => helps++, onOpenPath: () => paths++);
      await _tap(tester, 'Help now');
      await _tap(tester, 'View full path');
      expect(helps, 1);
      expect(paths, 1);
      expect(action().done, isFalse);
      expect(repository.saves, 0);
    },
  );

  testWidgets(
    '320px Simple 200% reduced-motion controls wrap and remain usable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(
        () => controller.setReadingStyle(ReadingStyle.simple),
      );
      await open(tester, largeText: true);
      for (final label in [
        'Your next step',
        'Moving house',
        'Write down one thing that helped',
        'Mark step done',
        'Back to Home',
        'Help now',
        'View full path',
      ]) {
        if (find.text(label).evaluate().isEmpty) {
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text(label),
            160,
            scrollable: find.byType(Scrollable).first,
          );
        }
        final text = find.text(label).first;
        await tester.ensureVisible(text);
        await tester.pumpAndSettle();
        final paragraph = tester.renderObject<RenderParagraph>(text);
        expect(paragraph.didExceedMaxLines, isFalse, reason: label);
        // Tight selection boxes use per-run font metrics; Manrope's glyph
        // extents can exceed a themed line's height without a paint clip.
        // RenderParagraph clips when line layout exceeds its allocated size.
        // Compare natural line height without a parent height constraint so a
        // short allocation still fails, retaining tight horizontal checks.
        final naturalSize = paragraph.getDryLayout(
          BoxConstraints(maxWidth: paragraph.size.width),
        );
        expect(
          naturalSize.height,
          lessThanOrEqualTo(paragraph.size.height + 1),
          reason: label,
        );
        // Wrapped line-ending spaces have caret selection boxes beyond the
        // visible line, although no glyph is painted there. Check each word's
        // tight boxes so all visible glyphs stay within the same width bound.
        final boxes = [
          for (final word in RegExp(r'\S+').allMatches(label))
            ...paragraph.getBoxesForSelection(
              TextSelection(baseOffset: word.start, extentOffset: word.end),
            ),
        ];
        expect(boxes, isNotEmpty, reason: label);
        for (final box in boxes) {
          expect(box.left, greaterThanOrEqualTo(-1), reason: label);
          expect(
            box.right,
            lessThanOrEqualTo(paragraph.size.width + 1),
            reason: label,
          );
        }
        if ([
          'Mark step done',
          'Back to Home',
          'Help now',
          'View full path',
        ].contains(label)) {
          final control = find
              .ancestor(
                of: text,
                matching: find.byWidgetPredicate(
                  (widget) => widget is ButtonStyleButton,
                ),
              )
              .first;
          expect(
            tester.getSize(control).height,
            greaterThanOrEqualTo(48),
            reason: label,
          );
        }
        expect(tester.takeException(), isNull, reason: label);
      }
      await _tap(tester, 'Mark step done');
      expect(action().done, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
