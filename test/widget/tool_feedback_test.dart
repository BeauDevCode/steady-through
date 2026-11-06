import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/features/tools/feedback/tool_feedback_prompt.dart';
import 'package:steady_through/features/tools/feedback/what_helps_card.dart';
import 'package:steady_through/features/tools/feedback/tool_feedback_history.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/model/tool_feedback.dart';
import 'package:steady_through/learning/learning_session.dart';
import 'package:steady_through/learning/learning_data.dart';

class _SafetySession extends LearningSession {
  _SafetySession(super.controller);
  bool vehicle = false;
  @override
  SignalSnapshot get snapshot => SignalSnapshot(
    observedAt: DateTime.now().toUtc(),
    features: const {},
    possibleVehicle: vehicle,
  );
  void changeVehicle(bool value) {
    vehicle = value;
    notifyListeners();
  }
}

class _Repo implements AppRepository {
  AppData value = AppData.empty();
  bool fail = false;
  Completer<void>? barrier;
  @override
  Future<AppData> load() async => value;
  @override
  Future<void> save(AppData data) async {
    await barrier?.future;
    if (fail) throw StateError('disk');
    value = data;
  }
}

void main() {
  late _Repo repo;
  late AppController controller;
  setUp(() {
    repo = _Repo();
    controller = AppController(repo, repo.value);
  });
  tearDown(() => controller.dispose());
  Future<void> open(WidgetTester t, Widget body) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: body)),
      ),
    );
    await t.pumpAndSettle();
  }

  Widget prompt({Key? key}) => ToolFeedbackPrompt(
    key: key,
    controller: controller,
    tool: SupportTool.grounding,
  );
  Future<void> tap(WidgetTester t, String text) async {
    await t.ensureVisible(find.text(text).first);
    await t.pumpAndSettle();
    await t.tap(find.text(text).first);
    await t.pump();
    await t.runAsync(() async => Future<void>.delayed(Duration.zero));
    await t.pumpAndSettle();
  }

  testWidgets('prompt starts collapsed and skip saves nothing', (t) async {
    await open(t, prompt());
    expect(find.text('Helpful'), findsNothing);
    expect(controller.data.toolFeedback.ratings, isEmpty);
    await tap(t, 'Rate this tool (optional)');
    await tap(t, 'Skip');
    expect(controller.data.toolFeedback.ratings, isEmpty);
    expect(find.text('Helpful'), findsNothing);
  });
  testWidgets(
    'rating saves once, can change in place and undo its exact receipt',
    (t) async {
      await open(t, prompt());
      await tap(t, 'Rate this tool (optional)');
      await tap(t, 'Helpful');
      expect(controller.data.toolFeedback.ratings, hasLength(1));
      final first = controller.data.toolFeedback.ratings.single;
      expect(find.text('Rating saved'), findsOneWidget);
      await tap(t, 'Not this time');
      final changed = controller.data.toolFeedback.ratings.single;
      expect(changed.id, first.id);
      expect(changed.createdAt, first.createdAt);
      expect(changed.rating, ToolRating.notThisTime);
      await tap(t, 'Undo rating');
      expect(controller.data.toolFeedback.ratings, isEmpty);
      expect(controller.data.learning.examples, isEmpty);
      expect(controller.data.gameRounds, isEmpty);
    },
  );
  testWidgets('failed save can retry without pretending it was saved', (
    t,
  ) async {
    repo.fail = true;
    await open(t, prompt());
    await tap(t, 'Rate this tool (optional)');
    await tap(t, 'Helpful');
    expect(controller.data.toolFeedback.ratings, isEmpty);
    expect(find.text('Rating saved'), findsNothing);
    expect(find.textContaining('Could not save'), findsOneWidget);
    repo.fail = false;
    await tap(t, 'Helpful');
    expect(controller.data.toolFeedback.ratings, hasLength(1));
    expect(find.text('Rating saved'), findsOneWidget);
  });
  testWidgets(
    'delayed double tap and replaced prompt do not duplicate or show late success',
    (t) async {
      repo.barrier = Completer<void>();
      await open(t, prompt(key: const ValueKey(1)));
      await tap(t, 'Rate this tool (optional)');
      await t.tap(find.text('Helpful'));
      await t.pump();
      await t.runAsync(() async => Future<void>.delayed(Duration.zero));
      await t.tap(find.text('Not this time'));
      await t.pump();
      await open(t, prompt(key: const ValueKey(2)));
      repo.barrier!.complete();
      await t.pumpAndSettle();
      await t.runAsync(() async => Future<void>.delayed(Duration.zero));
      await t.pumpAndSettle();
      await t.pumpAndSettle();
      expect(controller.data.toolFeedback.ratings, hasLength(1));
      expect(find.text('Rating saved'), findsNothing);
      expect(find.text('Rate this tool (optional)'), findsOneWidget);
    },
  );
  testWidgets('queued prompt write is rejected after document replacement', (
    t,
  ) async {
    await open(t, prompt());
    await tap(t, 'Rate this tool (optional)');
    final replacing = controller.replaceData(AppData.empty());
    await t.tap(find.text('Helpful'));
    await t.pumpAndSettle();
    await t.runAsync(() async => Future<void>.delayed(Duration.zero));
    await t.pumpAndSettle();
    await t.pumpAndSettle();
    await replacing;
    expect(controller.data.toolFeedback.ratings, isEmpty);
    expect(find.text('Rating saved'), findsNothing);
  });
  testWidgets('background invalidates queued write and late success', (
    t,
  ) async {
    await open(t, prompt());
    await tap(t, 'Rate this tool (optional)');
    repo.barrier = Completer<void>();
    final earlier = controller.setTheme(ThemeChoice.dark);
    await t.tap(find.text('Helpful'));
    await t.pump();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await t.pump();
    repo.barrier!.complete();
    await t.pumpAndSettle();
    await t.runAsync(() async => Future<void>.delayed(Duration.zero));
    await t.pumpAndSettle();
    await earlier;
    await t.pumpAndSettle();
    expect(controller.data.toolFeedback.ratings, isEmpty);
    expect(find.text('Rating saved'), findsNothing);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
  });
  testWidgets('hidden prompts still allow manual source-off history ratings', (
    t,
  ) async {
    await t.runAsync(
      () => controller.updateToolFeedbackOptions(
        showPrompts: false,
        expectedRevision: 0,
      ),
    );
    await open(t, prompt());
    expect(find.text('Rate this tool (optional)'), findsNothing);
    await t.pumpWidget(
      MaterialApp(home: ToolFeedbackHistory(controller: controller)),
    );
    await t.pumpAndSettle();
    await tap(t, 'Add a rating');
    await tap(t, 'Save rating');
    expect(controller.data.toolFeedback.ratings, hasLength(1));
    expect(controller.data.learning.enabledSources, isEmpty);
  });
  testWidgets(
    'live vehicle suppresses a queued prompt and returning permits a fresh answer',
    (t) async {
      final session = _SafetySession(controller);
      addTearDown(session.close);
      await open(
        t,
        ToolFeedbackPrompt(
          controller: controller,
          tool: SupportTool.grounding,
          safetySession: session,
        ),
      );
      await tap(t, 'Rate this tool (optional)');
      repo.barrier = Completer<void>();
      final earlier = controller.setTheme(ThemeChoice.dark);
      await t.tap(find.text('Helpful'));
      await t.pump();
      session.changeVehicle(true);
      await t.pump();
      expect(find.text('Helpful'), findsNothing);
      repo.barrier!.complete();
      await t.pumpAndSettle();
      await t.runAsync(() async => Future<void>.delayed(Duration.zero));
      await t.pumpAndSettle();
      await earlier;
      expect(controller.data.toolFeedback.ratings, isEmpty);
      session.changeVehicle(false);
      await t.pumpAndSettle();
      await tap(t, 'Rate this tool (optional)');
      await tap(t, 'Helpful');
      expect(controller.data.toolFeedback.ratings, hasLength(1));
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'summary explains latest helpful choice and keeps negative counts',
    (t) async {
      await t.runAsync(
        () => controller.recordToolFeedback(
          SupportTool.grounding,
          ToolRating.helpful,
          expectedRevision: 0,
        ),
      );
      await t.runAsync(
        () => controller.recordToolFeedback(
          SupportTool.breathing,
          ToolRating.helpful,
          expectedRevision: 0,
        ),
      );
      await t.runAsync(
        () => controller.recordToolFeedback(
          SupportTool.grounding,
          ToolRating.notThisTime,
          expectedRevision: 0,
        ),
      );
      SupportTool? opened;
      await open(
        t,
        WhatHelpsCard(
          controller: controller,
          onOpenTool: (tool) => opened = tool,
        ),
      );
      expect(
        find.textContaining('You marked Breathing pace helpful'),
        findsOneWidget,
      );
      await tap(t, 'Revisit Breathing pace');
      expect(opened, SupportTool.breathing);
      expect(find.textContaining('Not this time 1'), findsOneWidget);
      await tap(t, 'Use my ratings for ideas');
      expect(controller.data.toolFeedback.useSuggestions, isFalse);
      expect(find.text('Revisit Breathing pace'), findsNothing);
    },
  );
  testWidgets('history delete and clear are confirmed and scoped to ratings', (
    t,
  ) async {
    await t.runAsync(() => controller.createEvent('Keep plan', ''));
    await t.runAsync(
      () => controller.recordToolFeedback(
        SupportTool.grounding,
        ToolRating.helpful,
        expectedRevision: 0,
      ),
    );
    await t.runAsync(
      () => controller.recordToolFeedback(
        SupportTool.breathing,
        ToolRating.notThisTime,
        expectedRevision: 0,
      ),
    );
    await t.pumpWidget(
      MaterialApp(home: ToolFeedbackHistory(controller: controller)),
    );
    await t.pumpAndSettle();
    await tap(t, 'Delete');
    await tap(t, 'Cancel');
    expect(controller.data.toolFeedback.ratings, hasLength(2));
    await tap(t, 'Delete');
    await tap(t, 'Delete rating');
    expect(controller.data.toolFeedback.ratings, hasLength(1));
    await tap(t, 'Clear ratings');
    await tap(t, 'Clear all ratings');
    expect(controller.data.toolFeedback.ratings, isEmpty);
    expect(controller.data.events.single.title, 'Keep plan');
  });
  testWidgets('history dialog cannot change imported same-id record', (
    t,
  ) async {
    await t.runAsync(
      () => controller.recordToolFeedback(
        SupportTool.grounding,
        ToolRating.helpful,
        expectedRevision: 0,
      ),
    );
    await t.pumpWidget(
      MaterialApp(home: ToolFeedbackHistory(controller: controller)),
    );
    await t.pumpAndSettle();
    await tap(t, 'Change');
    await t.runAsync(
      () => controller.replaceData(AppData.fromJson(controller.data.toJson())),
    );
    await t.pump();
    await tap(t, 'Save rating');
    expect(
      controller.data.toolFeedback.ratings.single.rating,
      ToolRating.helpful,
    );
    expect(find.textContaining('Could not save'), findsOneWidget);
  });
  testWidgets(
    'an Add rating dialog cannot write into a replacement opened before its first save',
    (t) async {
      await t.pumpWidget(
        MaterialApp(home: ToolFeedbackHistory(controller: controller)),
      );
      await t.pumpAndSettle();
      await tap(t, 'Add a rating');
      await t.runAsync(() => controller.replaceData(AppData.empty()));
      await t.pumpAndSettle();
      await tap(t, 'Save rating');
      expect(controller.data.toolFeedback.ratings, isEmpty);
      expect(find.byType(AlertDialog), findsOneWidget);
    },
  );
  testWidgets(
    'a Clear ratings dialog cannot clear a replacement opened before its first confirmation',
    (t) async {
      await t.runAsync(
        () => controller.recordToolFeedback(
          SupportTool.grounding,
          ToolRating.helpful,
          expectedRevision: 0,
        ),
      );
      await t.pumpWidget(
        MaterialApp(home: ToolFeedbackHistory(controller: controller)),
      );
      await t.pumpAndSettle();
      await tap(t, 'Clear ratings');
      await t.runAsync(
        () =>
            controller.replaceData(AppData.fromJson(controller.data.toJson())),
      );
      await t.pumpAndSettle();
      await tap(t, 'Clear all ratings');
      expect(controller.data.toolFeedback.ratings, hasLength(1));
      expect(find.byType(AlertDialog), findsOneWidget);
    },
  );
  testWidgets(
    'backgrounded dialog cannot submit a second copy after an atomic save finishes',
    (t) async {
      await t.pumpWidget(
        MaterialApp(home: ToolFeedbackHistory(controller: controller)),
      );
      await t.pumpAndSettle();
      await tap(t, 'Add a rating');
      repo.barrier = Completer<void>();
      await tap(t, 'Save rating');
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      repo.barrier!.complete();
      await t.pumpAndSettle();
      await t.runAsync(() async => Future<void>.delayed(Duration.zero));
      await t.pumpAndSettle();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(controller.data.toolFeedback.ratings, hasLength(1));
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save rating'),
            )
            .onPressed,
        isNull,
      );
      await tap(t, 'Cancel');
      expect(controller.data.toolFeedback.ratings, hasLength(1));
    },
  );
  testWidgets('narrow Simple large text feedback has no layout overflow', (
    t,
  ) async {
    await t.runAsync(() => controller.setReadingStyle(ReadingStyle.simple));
    t.view.physicalSize = const Size(320, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2), disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                prompt(),
                WhatHelpsCard(controller: controller),
              ],
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await tap(t, 'Rate this tool (optional)');
    expect(t.takeException(), isNull);
  });
  for (final started in [false, true]) {
    testWidgets(
      'Help stays immediate and a ${started ? 'started' : 'queued'} prompt save settles on its original attempt',
      (t) async {
        await open(t, prompt());
        await tap(t, 'Rate this tool (optional)');
        repo.barrier = Completer<void>();
        if (!started) controller.setTheme(ThemeChoice.dark);
        await t.tap(find.text('Helpful'));
        await t.pump();
        await t.runAsync(() async => Future<void>.delayed(Duration.zero));
        await t.pump();
        unawaited(
          Navigator.of(t.element(find.byType(ToolFeedbackPrompt))).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  Scaffold(appBar: AppBar(title: const Text('Help page'))),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('Help page'), findsOneWidget);
        repo.barrier!.complete();
        await t.pumpAndSettle();
        await t.runAsync(() async => Future<void>.delayed(Duration.zero));
        await t.pumpAndSettle();
        await t.pageBack();
        await t.pumpAndSettle();
        expect(find.text('Saving rating…'), findsNothing);
        if (started) {
          expect(controller.data.toolFeedback.ratings, hasLength(1));
          expect(find.text('Rating saved'), findsOneWidget);
          await tap(t, 'Not this time');
          expect(controller.data.toolFeedback.ratings, hasLength(1));
        } else {
          expect(controller.data.toolFeedback.ratings, isEmpty);
          await tap(t, 'Helpful');
          expect(controller.data.toolFeedback.ratings, hasLength(1));
        }
      },
    );
  }
  testWidgets(
    'large text dialog paints every selected label glyph inside its bounds',
    (t) async {
      t.view.physicalSize = const Size(320, 1100);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: ToolFeedbackHistory(controller: controller),
        ),
      );
      await t.pumpAndSettle();
      await tap(t, 'Add a rating');
      Future<void> checkLabels(List<String> labels) async {
        for (final label in labels) {
          final target = find
              .descendant(
                of: find.byType(AlertDialog),
                matching: find.text(label),
              )
              .first;
          await t.ensureVisible(target);
          await t.pumpAndSettle();
          final paragraph = t.renderObject<RenderParagraph>(target);
          final boxes = paragraph.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: label.length),
          );
          expect(boxes, isNotEmpty, reason: label);
          for (final box in boxes) {
            expect(
              box.right,
              lessThanOrEqualTo(paragraph.size.width + 1),
              reason: label,
            );
            expect(
              box.bottom,
              lessThanOrEqualTo(paragraph.size.height + 1),
              reason: label,
            );
          }
        }
      }

      await checkLabels([
        'Grounding',
        'Breathing pace',
        'Path game',
        'Helpful',
        'Not this time',
      ]);
      await tap(t, 'Path game');
      await tap(t, 'Not this time');
      await tap(t, 'Save rating');
      final receipt = controller.data.toolFeedback.ratings.single;
      expect(receipt.tool, SupportTool.pathGame);
      expect(receipt.rating, ToolRating.notThisTime);
      await t.scrollUntilVisible(
        find.text('Change'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tap(t, 'Change');
      await checkLabels(['Helpful', 'Not this time']);
      await tap(t, 'Helpful');
      await tap(t, 'Save rating');
      expect(controller.data.toolFeedback.ratings.single.id, receipt.id);
      expect(
        controller.data.toolFeedback.ratings.single.rating,
        ToolRating.helpful,
      );
      expect(t.takeException(), isNull);
    },
  );
}
