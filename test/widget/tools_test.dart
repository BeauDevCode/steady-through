import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/features/help/help_screen.dart';
import 'package:steady_through/features/tools/tools_screen.dart';
import 'package:steady_through/model/app_data.dart';

class _MemoryRepository implements AppRepository {
  AppData value = AppData.empty();

  @override
  Future<AppData> load() async => value;

  @override
  Future<void> save(AppData next) async => value = next;
}

void main() {
  late AppController controller;

  setUp(() {
    controller = AppController(_MemoryRepository(), AppData.empty());
  });
  tearDown(() => controller.dispose());

  Future<void> openTools(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ToolsScreen(controller: controller)),
      ),
    );
  }

  Future<void> openGame(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.text('Path game'), 250);
    await tester.ensureVisible(find.text('Path game'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Path game'));
    await tester.pumpAndSettle();
  }

  Future<void> tapCell(WidgetTester tester, int cell) async {
    final target = find.byKey(ValueKey('cell-$cell'));
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pump();
  }

  testWidgets('grounding Skip advances and Stop returns to Tools', (
    tester,
  ) async {
    await openTools(tester);
    await tester.tap(find.text('Grounding'));
    await tester.pumpAndSettle();

    expect(find.textContaining('look around'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.textContaining('feet'), findsOneWidget);

    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    expect(find.text('Grounding'), findsOneWidget);
  });

  testWidgets('breathing pace can be started and stopped', (tester) async {
    await openTools(tester);
    await tester.tap(find.text('Breathing pace'));
    await tester.pumpAndSettle();

    expect(find.text('Stop'), findsOneWidget);
    await tester.tap(find.text('Start pace'));
    await tester.pump();
    expect(find.textContaining('Breathe in gently'), findsOneWidget);
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    expect(find.text('Breathing pace'), findsOneWidget);
  });

  testWidgets('game records a completed round only after feeling is chosen', (
    tester,
  ) async {
    await openTools(tester);
    await openGame(tester);

    for (final cell in [1, 2, 3, 7, 11, 15]) {
      await tapCell(tester, cell);
    }
    await tester.scrollUntilVisible(
      find.text('How did this round feel?'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('How did this round feel?'), findsOneWidget);
    expect(controller.data.gameRounds, isEmpty);

    await tester.ensureVisible(find.text('Tense'));
    await tester.tap(find.text('Tense'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    expect(controller.data.gameRounds, hasLength(1));
    expect(controller.data.gameRounds.single.feeling, RoundFeeling.tense);
    expect(controller.data.gameRounds.single.moves, 6);
    await tester.scrollUntilVisible(
      find.textContaining('Since you said it felt tense'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('grounding'), findsWidgets);
  });

  testWidgets(
    'Undo after Finish reopens the path before any feeling is saved',
    (tester) async {
      await openTools(tester);
      await openGame(tester);

      for (final cell in [1, 2, 3, 7, 11, 15]) {
        await tapCell(tester, cell);
      }
      await tester.scrollUntilVisible(
        find.text('How did this round feel?'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('How did this round feel?'), findsOneWidget);

      await tester.ensureVisible(find.text('Undo'));
      await tester.tap(find.text('Undo'));
      await tester.pump();
      expect(find.text('How did this round feel?'), findsNothing);
      expect(controller.data.gameRounds, isEmpty);
    },
  );

  testWidgets(
    'repeated backtracking offers an optional break without diagnosis',
    (tester) async {
      await openTools(tester);
      await openGame(tester);

      for (var attempt = 0; attempt < 2; attempt++) {
        await tapCell(tester, 1);
        await tester.ensureVisible(find.text('Undo'));
        await tester.tap(find.text('Undo'));
        await tester.pump();
      }

      expect(find.textContaining('backtracked 2 times'), findsOneWidget);
      expect(find.text('Take a break'), findsOneWidget);
      expect(find.textContaining('stress score'), findsNothing);
      expect(controller.data.gameRounds, isEmpty);
    },
  );

  testWidgets(
    'Help now is reachable during the game at large text and narrow width',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      await openTools(tester);
      await openGame(tester);
      await tester.tap(find.text('Help now'));
      await tester.pumpAndSettle();

      expect(find.textContaining('immediate physical danger'), findsOneWidget);
      await tester.scrollUntilVisible(find.textContaining('U.S. only'), 250);
      expect(find.textContaining('U.S. only'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('game Help now uses the shell help route when supplied', (
    tester,
  ) async {
    var helpOpens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (shellContext) => Scaffold(
            body: ToolsScreen(
              controller: controller,
              onOpenHelp: () {
                helpOpens++;
                Navigator.of(shellContext).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: HelpScreen()),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await openGame(tester);
    await tester.tap(find.text('Help now'));
    await tester.pumpAndSettle();

    expect(helpOpens, 1);
    expect(find.textContaining('immediate physical danger'), findsOneWidget);
  });

  testWidgets('simple words setting shortens tool and help guidance', (
    tester,
  ) async {
    await tester.runAsync(
      () => controller.setReadingStyle(ReadingStyle.simple),
    );
    await openTools(tester);

    expect(find.text('Pick a tool. You can stop at any time.'), findsOneWidget);
    await tester.tap(find.text('Help now'));
    await tester.pumpAndSettle();
    expect(
      find.text('If you are in danger now, call local emergency services.'),
      findsOneWidget,
    );
    expect(find.textContaining('U.S. only'), findsOneWidget);
  });
}
