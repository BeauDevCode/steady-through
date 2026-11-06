import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/app/steady_through_app.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/features/help/help_screen.dart';
import 'package:steady_through/features/tools/tools_screen.dart';
import 'package:steady_through/features/tools/breathing_screen.dart';
import 'package:steady_through/features/tools/grounding_screen.dart';
import 'package:steady_through/features/tools/path_game_screen.dart';
import 'package:steady_through/learning/learning_session.dart';
import 'package:steady_through/model/tool_feedback.dart';
import 'package:steady_through/model/app_data.dart';

class _MemoryRepository implements AppRepository {
  AppData value = AppData.empty();
  Completer<void>? pending;
  int savesStarted = 0;

  @override
  Future<AppData> load() async => value;

  @override
  Future<void> save(AppData next) async {
    savesStarted++;
    await pending?.future;
    value = next;
  }
}

void main() {
  late AppController controller;
  late _MemoryRepository repository;

  setUp(() {
    repository = _MemoryRepository();
    controller = AppController(repository, AppData.empty());
  });
  tearDown(() => controller.dispose());

  testWidgets(
    'every standalone tool Help fallback receives the current trusted people',
    (tester) async {
      await tester.runAsync(
        () => controller.addPerson('Fictional fallback helper', ''),
      );
      final bodies = <Widget>[
        ToolsScreen(controller: controller),
        GroundingScreen(controller: controller),
        BreathingScreen(controller: controller),
        PathGameScreen(controller: controller),
      ];
      for (var index = 0; index < bodies.length; index++) {
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(index),
            home: Scaffold(body: bodies[index]),
          ),
        );
        await tester.pumpAndSettle();
        if (index == 2) {
          await tester.tap(find.text('Start pace'));
          await tester.pump();
        }
        await tester.tap(find.text('Help now'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<HelpScreen>(find.byType(HelpScreen)).controller,
          same(controller),
        );
        await tester.scrollUntilVisible(
          find.text('Fictional fallback helper'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Fictional fallback helper'), findsOneWidget);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();
        if (index == 2) expect(find.text('Start pace'), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

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

  Future<void> tapText(WidgetTester tester, String text) async {
    if (find.text(text).evaluate().isEmpty) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 10000));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(text),
        250,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(find.text(text).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).first);
    await tester.pumpAndSettle();
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

  testWidgets(
    'skipping grounding to its ending offers a collapsed optional rating',
    (tester) async {
      await openTools(tester);
      await tester.tap(find.text('Grounding'));
      await tester.pumpAndSettle();
      expect(find.text('Rate this tool (optional)'), findsNothing);
      for (var step = 0; step < 4; step++) {
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Finished'), findsOneWidget);
      await tester.ensureVisible(find.text('Rate this tool (optional)'));
      expect(find.text('Rate this tool (optional)'), findsOneWidget);
      expect(find.text('Helpful'), findsNothing);
      expect(controller.data.toolFeedback.ratings, isEmpty);
      await tester.ensureVisible(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Tools'), findsOneWidget);
    },
  );

  testWidgets(
    'breathing requires Start then explicit Done and starts a fresh attempt',
    (tester) async {
      await openTools(tester);
      await tester.tap(find.text('Breathing pace'));
      await tester.pumpAndSettle();
      expect(find.text('Done for now'), findsNothing);
      await tester.tap(find.text('Start pace'));
      await tester.pump();
      expect(find.text('Done for now'), findsOneWidget);
      await tapText(tester, 'Done for now');
      expect(find.text('Rate this tool (optional)'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
      expect(find.text('Your pace'), findsOneWidget);
      await tapText(tester, 'Start again');
      expect(find.text('Rate this tool (optional)'), findsNothing);
      expect(find.text('Breathe in gently'), findsOneWidget);
      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'backgrounding and Help pause breathing without finishing or resuming',
    (tester) async {
      await openTools(tester);
      await tester.tap(find.text('Breathing pace'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start pace'));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 8));
      expect(find.text('Your pace'), findsOneWidget);
      expect(find.text('Done for now'), findsOneWidget);
      expect(find.text('Rate this tool (optional)'), findsNothing);
      await tester.tap(find.text('Start pace'));
      await tester.pump();
      await tester.tap(find.text('Help now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Your pace'), findsOneWidget);
      expect(find.text('Rate this tool (optional)'), findsNothing);
      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'reduced motion uses a static breathing circle with live pace text',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(body: BreathingScreen(controller: controller)),
          ),
        ),
      );
      await tester.tap(find.text('Start pace'));
      await tester.pump();
      expect(find.byType(AnimatedContainer), findsNothing);
      expect(find.text('Breathe in gently'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Breathe out gently'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('game break grounding clearly returns to the game', (
    tester,
  ) async {
    await openTools(tester);
    await openGame(tester);
    for (var attempt = 0; attempt < 2; attempt++) {
      await tapCell(tester, 1);
      await tester.ensureVisible(find.text('Undo'));
      await tester.tap(find.text('Undo'));
      await tester.pump();
    }
    await tapText(tester, 'Take a break');
    expect(find.text('Back to game'), findsOneWidget);
    await tester.tap(find.text('Back to game'));
    await tester.pumpAndSettle();
    expect(find.byType(PathGameScreen), findsOneWidget);
  });

  testWidgets(
    'game usefulness is independent of feeling and resets for another board',
    (tester) async {
      await openTools(tester);
      await openGame(tester);
      for (final cell in [1, 2, 3, 7, 11, 15]) {
        await tapCell(tester, cell);
      }
      await tapText(tester, 'Rate this tool (optional)');
      await tapText(tester, 'Helpful');
      await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(
        controller.data.toolFeedback.ratings.single.tool,
        SupportTool.pathGame,
      );
      expect(
        controller.data.toolFeedback.ratings.single.rating,
        ToolRating.helpful,
      );
      expect(controller.data.gameRounds, isEmpty);
      expect(controller.data.learning.examples, isEmpty);
      await tapText(tester, 'Tense');
      await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(controller.data.gameRounds.single.feeling, RoundFeeling.tense);
      expect(controller.data.toolFeedback.ratings, hasLength(1));
      await tapText(tester, 'Another round');
      expect(find.text('Rating saved'), findsNothing);
      expect(find.text('Rate this tool (optional)'), findsNothing);
      for (final cell in [1, 2, 6, 10, 14, 15]) {
        await tapCell(tester, cell);
      }
      await tapText(tester, 'Rate this tool (optional)');
      expect(find.text('Rating saved'), findsNothing);
      expect(find.text('Skip'), findsOneWidget);
      expect(controller.data.toolFeedback.ratings, hasLength(1));
    },
  );

  testWidgets(
    'leaving a game board during a rating save cannot mark the new board saved',
    (tester) async {
      await openTools(tester);
      await openGame(tester);
      for (final cell in [1, 2, 3, 7, 11, 15]) {
        await tapCell(tester, cell);
      }
      await tapText(tester, 'Rate this tool (optional)');
      repository.pending = Completer<void>();
      await tapText(tester, 'Helpful');
      await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(repository.savesStarted, 1);
      expect(find.text('Saving rating…'), findsOneWidget);
      await tapText(tester, 'New board');
      repository.pending!.complete();
      await tester.pumpAndSettle();
      await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.text('Rating saved'), findsNothing);
      // The atomic save had already started and may finish for its original board.
      expect(controller.data.toolFeedback.ratings, hasLength(1));
      expect(controller.data.gameRounds, isEmpty);
      for (final cell in [1, 2, 6, 10, 14, 15]) {
        await tapCell(tester, cell);
      }
      expect(find.text('Rate this tool (optional)'), findsOneWidget);
      expect(find.text('Rating saved'), findsNothing);
    },
  );

  testWidgets(
    'shell tool entry points forward one optional safety session and correct return labels',
    (tester) async {
      final session = LearningSession(controller);
      addTearDown(session.close);
      await tester.pumpWidget(
        SteadyThroughApp(controller: controller, learningSession: session),
      );
      await tapText(tester, 'Grounding');
      expect(
        tester
            .widget<GroundingScreen>(find.byType(GroundingScreen))
            .safetySession,
        same(session),
      );
      expect(find.text('Back to Home'), findsOneWidget);
      await tapText(tester, 'Back to Home');
      await tapText(tester, 'Open Insights');
      await tapText(tester, 'Try grounding');
      expect(
        tester
            .widget<GroundingScreen>(find.byType(GroundingScreen))
            .safetySession,
        same(session),
      );
      await tapText(tester, 'Back to Insights');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapText(tester, 'Tools');
      expect(
        tester.widget<ToolsScreen>(find.byType(ToolsScreen)).safetySession,
        same(session),
      );
      await tapText(tester, 'Grounding');
      expect(
        tester
            .widget<GroundingScreen>(find.byType(GroundingScreen))
            .safetySession,
        same(session),
      );
      await tapText(tester, 'Back to Tools');
      await tapText(tester, 'Breathing pace');
      expect(
        tester
            .widget<BreathingScreen>(find.byType(BreathingScreen))
            .safetySession,
        same(session),
      );
      await tapText(tester, 'Back to Tools');
      await tapText(tester, 'Path game');
      expect(
        tester
            .widget<PathGameScreen>(find.byType(PathGameScreen))
            .safetySession,
        same(session),
      );
      for (var attempt = 0; attempt < 2; attempt++) {
        await tapCell(tester, 1);
        await tapText(tester, 'Undo');
      }
      await tapText(tester, 'Take a break');
      expect(
        tester
            .widget<GroundingScreen>(find.byType(GroundingScreen))
            .safetySession,
        same(session),
      );
      expect(find.text('Back to game'), findsOneWidget);
      expect(controller.data.toolFeedback.ratings, isEmpty);
      expect(controller.data.learning.enabledSources, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'source-off ratings stay usable at 320px with Simple words and 200 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      });
      await tester.runAsync(
        () => controller.setReadingStyle(ReadingStyle.simple),
      );
      await openTools(tester);
      await tapText(tester, 'What helps you');
      expect(controller.data.learning.enabledSources, isEmpty);
      await tapText(tester, 'Grounding');
      for (var step = 0; step < 4; step++) {
        await tapText(tester, 'Skip');
      }
      await tapText(tester, 'Rate this tool (optional)');
      await tapText(tester, 'Not this time');
      await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(
        controller.data.toolFeedback.ratings.single.rating,
        ToolRating.notThisTime,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
